#!/usr/bin/env python3
"""Real Cognito/API authorization tests. Creates only suppressed QA accounts."""
import json
import secrets
import urllib.error
import urllib.request

import boto3

from admin_deploy import private_json
from deployment import ROOT


def get(url, token=None):
    request = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token} if token else {})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, None


def main():
    directory = ROOT / 'build/analytics'
    state = json.loads((directory / 'admin-deployment.json').read_text())
    session = boto3.Session(profile_name='frazras', region_name='us-east-1')
    cognito = session.client('cognito-idp')
    url = state['ApiEndpoint'] + '/v1/admin/overview'
    assert get(url)[0] == 401, 'Missing authentication must fail'
    assert get(url, 'invalid')[0] == 401, 'Invalid JWT must fail'
    created = []
    try:
        for admin in (False, True):
            username = 'qa-' + secrets.token_hex(8)
            password = secrets.token_urlsafe(24) + 'aA7!'
            created.append(username)
            cognito.admin_create_user(UserPoolId=state['PoolId'], Username=username, TemporaryPassword=password, MessageAction='SUPPRESS')
            cognito.admin_set_user_password(UserPoolId=state['PoolId'], Username=username, Password=password, Permanent=True)
            if admin:
                cognito.admin_add_user_to_group(UserPoolId=state['PoolId'], Username=username, GroupName='admins')
            auth = cognito.initiate_auth(ClientId=state['ClientId'], AuthFlow='USER_PASSWORD_AUTH',
                AuthParameters={'USERNAME': username, 'PASSWORD': password})['AuthenticationResult']
            status, report = get(url, auth['AccessToken'])
            assert status == (200 if admin else 403), ('Role enforcement', admin, status)
            assert get(url, auth['IdToken'])[0] in (401, 403), 'ID tokens must not authorize the API'
            if admin:
                assert report['schema'] == 1 and set(report['periods']) == {'current', '1', '4', '8'}
                # Keep this QA account for the subsequent browser test; no token saved.
                private_json(directory / 'admin-browser-qa.json', {**state, 'username': username, 'password': password})
                (directory / 'admin-live-report.json').write_text(json.dumps(report))
                created.remove(username)
        (directory / 'admin-verification.json').write_text(json.dumps({'checks': [
            'anonymous rejected', 'invalid JWT rejected', 'non-admin rejected', 'ID token rejected', 'admin report accepted'], 'site': state['Site']}, indent=2))
        print('PASS: anonymous, invalid JWT, non-admin, ID token rejected; administrator accepted.')
    finally:
        for username in created:
            cognito.admin_delete_user(UserPoolId=state['PoolId'], Username=username)


if __name__ == '__main__':
    main()
