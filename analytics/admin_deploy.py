#!/usr/bin/env python3
"""Amplify static hosting + Cognito code/PKCE login + JWT-protected report API.

No signup or invitation emails. Initial credentials stay in ignored local state.
"""
import argparse
import io
import json
import os
import secrets
import time
import urllib.request
import zipfile

import boto3
from botocore.exceptions import ClientError

from deployment import ROOT, deploy_stack, package_code
from deploy import ref, attr, sub


def template(bucket, code):
    origin = sub('https://main.${App.DefaultDomain}')
    issuer = sub('https://cognito-idp.${AWS::Region}.amazonaws.com/${Pool}')
    r = {
        'App': {'Type': 'AWS::Amplify::App', 'Properties': {'Name': 'SDA Hymnal Analytics', 'Platform': 'WEB',
            'CustomHeaders': sub("customHeaders:\n  - pattern: '**/*'\n    headers:\n      - key: X-Content-Type-Options\n        value: nosniff\n      - key: Referrer-Policy\n        value: no-referrer\n      - key: X-Frame-Options\n        value: DENY\n      - key: Cache-Control\n        value: no-store\n      - key: Content-Security-Policy\n        value: \"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' https://*.execute-api.${AWS::Region}.amazonaws.com https://*.auth.${AWS::Region}.amazoncognito.com; frame-ancestors 'none'; base-uri 'none'; form-action 'self' https://*.auth.${AWS::Region}.amazoncognito.com; object-src 'none'\"\n")}},
        'Branch': {'Type': 'AWS::Amplify::Branch', 'Properties': {'AppId': attr('App', 'AppId'), 'BranchName': 'main',
            'Stage': 'PRODUCTION', 'EnableAutoBuild': False}},
        'Pool': {'Type': 'AWS::Cognito::UserPool', 'DeletionPolicy': 'Retain', 'UpdateReplacePolicy': 'Retain', 'Properties': {
            'UserPoolName': 'sdahymnal-analytics-admin', 'AdminCreateUserConfig': {'AllowAdminCreateUserOnly': True},
            'UsernameConfiguration': {'CaseSensitive': False}, 'MfaConfiguration': 'OFF',
            'AccountRecoverySetting': {'RecoveryMechanisms': [{'Name': 'admin_only', 'Priority': 1}]},
            'Policies': {'PasswordPolicy': {'MinimumLength': 14, 'RequireLowercase': True, 'RequireUppercase': True,
                'RequireNumbers': True, 'RequireSymbols': True, 'TemporaryPasswordValidityDays': 7}}}},
        'Domain': {'Type': 'AWS::Cognito::UserPoolDomain', 'Properties': {'UserPoolId': ref('Pool'),
            'Domain': sub('sdahymnal-admin-${AWS::AccountId}')}},
        'Client': {'Type': 'AWS::Cognito::UserPoolClient', 'Properties': {'UserPoolId': ref('Pool'), 'ClientName': 'analytics-dashboard',
            'GenerateSecret': False, 'PreventUserExistenceErrors': 'ENABLED', 'EnableTokenRevocation': True,
            'AllowedOAuthFlowsUserPoolClient': True, 'AllowedOAuthFlows': ['code'],
            'AllowedOAuthScopes': ['openid', 'aws.cognito.signin.user.admin'], 'SupportedIdentityProviders': ['COGNITO'],
            'CallbackURLs': [sub('https://main.${App.DefaultDomain}/')], 'LogoutURLs': [sub('https://main.${App.DefaultDomain}/')],
            'AccessTokenValidity': 60, 'IdTokenValidity': 60, 'RefreshTokenValidity': 1,
            'TokenValidityUnits': {'AccessToken': 'minutes', 'IdToken': 'minutes', 'RefreshToken': 'days'},
            'ExplicitAuthFlows': ['ALLOW_USER_PASSWORD_AUTH', 'ALLOW_REFRESH_TOKEN_AUTH']}},
        'Admins': {'Type': 'AWS::Cognito::UserPoolGroup', 'Properties': {'UserPoolId': ref('Pool'), 'GroupName': 'admins'}},
        'Api': {'Type': 'AWS::ApiGatewayV2::Api', 'Properties': {'Name': 'sdahymnal-analytics-admin', 'ProtocolType': 'HTTP',
            'CorsConfiguration': {'AllowOrigins': [origin], 'AllowMethods': ['GET'], 'AllowHeaders': ['authorization'], 'MaxAge': 300}}},
        'Authorizer': {'Type': 'AWS::ApiGatewayV2::Authorizer', 'Properties': {'ApiId': ref('Api'), 'AuthorizerType': 'JWT',
            'Name': 'admin-cognito', 'IdentitySource': ['$request.header.Authorization'],
            'JwtConfiguration': {'Audience': [ref('Client')], 'Issuer': issuer}}},
        'Logs': {'Type': 'AWS::Logs::LogGroup', 'Properties': {'LogGroupName': sub('/aws/lambda/${AWS::StackName}-report'), 'RetentionInDays': 7}},
        'Role': {'Type': 'AWS::IAM::Role', 'Properties': {'AssumeRolePolicyDocument': {'Version': '2012-10-17', 'Statement': [
            {'Effect': 'Allow', 'Principal': {'Service': 'lambda.amazonaws.com'}, 'Action': 'sts:AssumeRole'}]},
            'Policies': [{'PolicyName': 'read-report', 'PolicyDocument': {'Version': '2012-10-17', 'Statement': [
                {'Effect': 'Allow', 'Action': 's3:GetObject', 'Resource': f'arn:aws:s3:::{bucket}/admin/overview.json'},
                {'Effect': 'Allow', 'Action': ['logs:CreateLogStream', 'logs:PutLogEvents'], 'Resource': sub('${Logs.Arn}:*')}]}}]}},
        'Report': {'Type': 'AWS::Lambda::Function', 'DependsOn': 'Logs', 'Properties': {'FunctionName': sub('${AWS::StackName}-report'),
            'Runtime': 'python3.13', 'Handler': 'admin.handler', 'Code': code, 'Role': attr('Role', 'Arn'),
            'MemorySize': 256, 'Timeout': 10, 'ReservedConcurrentExecutions': 2, 'Environment': {'Variables': {'BUCKET': bucket}}}},
        'Integration': {'Type': 'AWS::ApiGatewayV2::Integration', 'Properties': {'ApiId': ref('Api'), 'IntegrationType': 'AWS_PROXY',
            'IntegrationUri': attr('Report', 'Arn'), 'PayloadFormatVersion': '2.0'}},
        'Route': {'Type': 'AWS::ApiGatewayV2::Route', 'Properties': {'ApiId': ref('Api'), 'RouteKey': 'GET /v1/admin/overview',
            'Target': sub('integrations/${Integration}'), 'AuthorizationType': 'JWT', 'AuthorizerId': ref('Authorizer'),
            'AuthorizationScopes': ['aws.cognito.signin.user.admin']}},
        'Stage': {'Type': 'AWS::ApiGatewayV2::Stage', 'Properties': {'ApiId': ref('Api'), 'StageName': '$default', 'AutoDeploy': True,
            'DefaultRouteSettings': {'ThrottlingBurstLimit': 5, 'ThrottlingRateLimit': 2}}},
        'Permission': {'Type': 'AWS::Lambda::Permission', 'Properties': {'FunctionName': ref('Report'), 'Action': 'lambda:InvokeFunction',
            'Principal': 'apigateway.amazonaws.com', 'SourceArn': sub('arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/*/GET/v1/admin/overview')}},
        'Errors': {'Type': 'AWS::CloudWatch::Alarm', 'Properties': {'Namespace': 'AWS/Lambda', 'MetricName': 'Errors',
            'Dimensions': [{'Name': 'FunctionName', 'Value': ref('Report')}], 'Statistic': 'Sum', 'Period': 300,
            'EvaluationPeriods': 1, 'Threshold': 1, 'ComparisonOperator': 'GreaterThanOrEqualToThreshold', 'TreatMissingData': 'notBreaching'}},
    }
    return {'Description': 'Private SDA Hymnal analytics dashboard', 'Resources': r, 'Outputs': {
        'Site': {'Value': origin}, 'AppId': {'Value': attr('App', 'AppId')}, 'PoolId': {'Value': ref('Pool')},
        'ClientId': {'Value': ref('Client')}, 'AuthDomain': {'Value': sub('https://${Domain}.auth.${AWS::Region}.amazoncognito.com')},
        'ApiEndpoint': {'Value': attr('Api', 'ApiEndpoint')}, 'Report': {'Value': ref('Report')}}}


def private_json(path, value):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, 'w') as file:
        json.dump(value, file, indent=2)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--profile', default='frazras')
    parser.add_argument('--region', default='us-east-1')
    args = parser.parse_args()
    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    directory = ROOT / 'build/analytics'
    state = json.loads((directory / 'deployment.json').read_text())
    outputs = deploy_stack(session, 'sdahymnal-analytics-admin', template(state['Reports'], package_code(session)))
    private_json(directory / 'admin-deployment.json', outputs)
    cognito = session.client('cognito-idp')
    try:
        cognito.admin_get_user(UserPoolId=outputs['PoolId'], Username='frazras')
    except cognito.exceptions.UserNotFoundException:
        password = secrets.token_urlsafe(24) + 'aA7!'
        # Persist before provisioning so a later failure never loses the credential.
        private_json(directory / 'admin-credentials.json', {'site': outputs['Site'], 'username': 'frazras',
            'temporary_password': password, 'instructions': 'Sign in and choose a new password within seven days.'})
        cognito.admin_create_user(UserPoolId=outputs['PoolId'], Username='frazras', TemporaryPassword=password, MessageAction='SUPPRESS')
    cognito.admin_add_user_to_group(UserPoolId=outputs['PoolId'], Username='frazras', GroupName='admins')
    config = {'clientId': outputs['ClientId'], 'authDomain': outputs['AuthDomain'],
        'api': outputs['ApiEndpoint'], 'redirect': outputs['Site'] + '/'}
    archive = io.BytesIO()
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted((ROOT / 'analytics/admin-web').iterdir()):
            if path.is_file():
                bundle.write(path, path.name)
        bundle.writestr('config.json', json.dumps(config))
    amplify = session.client('amplify')
    job = amplify.create_deployment(appId=outputs['AppId'], branchName='main')
    request = urllib.request.Request(job['zipUploadUrl'], data=archive.getvalue(), method='PUT', headers={'Content-Type': 'application/zip'})
    with urllib.request.urlopen(request, timeout=60) as response:
        assert response.status == 200
    amplify.start_deployment(appId=outputs['AppId'], branchName='main', jobId=job['jobId'])
    previous = None
    while True:
        status = amplify.get_job(appId=outputs['AppId'], branchName='main', jobId=job['jobId'])['job']['summary']['status']
        if status != previous:
            print('Amplify', status, flush=True); previous = status
        if status == 'SUCCEED':
            break
        if status in ('FAILED', 'CANCELLED'):
            raise RuntimeError('Amplify deployment ' + status)
        time.sleep(10)
    print('Admin dashboard: ' + outputs['Site'], flush=True)
    print('Initial sign-in details: build/analytics/admin-credentials.json (private local file)', flush=True)


if __name__ == '__main__':
    main()
