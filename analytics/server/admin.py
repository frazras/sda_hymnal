"""Called only by a JWT-authorized API Gateway route; IAM-private report."""
import json
import os

import boto3
from botocore.exceptions import ClientError


def handler(event, context):
    claims = event.get('requestContext', {}).get('authorizer', {}).get('jwt', {}).get('claims', {})
    groups = claims.get('cognito:groups', [])
    if isinstance(groups, str):
        # HTTP API serializes Cognito arrays as either JSON or bracketed CSV.
        try:
            groups = json.loads(groups)
        except ValueError:
            groups = [g.strip() for g in groups.strip('[]').split(',')]
    allowed = isinstance(groups, list) and 'admins' in groups and claims.get('token_use') == 'access'
    headers = {'content-type': 'application/json', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff'}
    if not allowed:
        return {'statusCode': 403, 'headers': headers, 'body': '{"error":"forbidden"}'}
    if event.get('routeKey') == 'GET /v1/admin/error-reports':
        from error_reports import list_reports
        return list_reports(event)
    try:
        report = boto3.client('s3').get_object(Bucket=os.environ['BUCKET'], Key='admin/overview.json')['Body'].read()
        return {'statusCode': 200, 'headers': headers, 'body': report.decode()}
    except ClientError:
        return {'statusCode': 503, 'headers': headers, 'body': '{"error":"report_unavailable"}'}
