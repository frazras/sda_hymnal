"""Shared deployment helpers. Artifacts contain code/configuration, not secrets."""
import hashlib
import io
import json
import time
import zipfile
from pathlib import Path

from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[1]


def deploy_stack(session, name, template, parameters=()):
    client = session.client('cloudformation')
    args = dict(StackName=name, TemplateBody=json.dumps(template),
        Capabilities=['CAPABILITY_IAM'], Parameters=list(parameters))
    try:
        client.describe_stacks(StackName=name)
        try:
            client.update_stack(**args)
        except ClientError as exc:
            if 'No updates are to be performed' not in str(exc):
                raise
    except ClientError as exc:
        if 'does not exist' not in str(exc):
            raise
        client.create_stack(**args, Tags=[{'Key': 'Project', 'Value': 'sdahymnal'}])
    previous = None
    while True:
        stack = client.describe_stacks(StackName=name)['Stacks'][0]
        status = stack['StackStatus']
        if status != previous:
            print(name, status, flush=True)
            previous = status
        if status in ('CREATE_COMPLETE', 'UPDATE_COMPLETE'):
            return {o['OutputKey']: o['OutputValue'] for o in stack.get('Outputs', [])}
        if 'IN_PROGRESS' not in status:
            for event in client.describe_stack_events(StackName=name)['StackEvents']:
                if 'FAILED' in event['ResourceStatus']:
                    print(event['LogicalResourceId'], event.get('ResourceStatusReason', ''))
            raise RuntimeError(status)
        time.sleep(10)


def package_code(session):
    outputs = deploy_stack(session, 'sdahymnal-analytics-artifacts', {
        'Resources': {'Artifacts': {'Type': 'AWS::S3::Bucket', 'DeletionPolicy': 'Retain',
            'UpdateReplacePolicy': 'Retain', 'Properties': {
                'PublicAccessBlockConfiguration': {k: True for k in ('BlockPublicAcls', 'IgnorePublicAcls', 'BlockPublicPolicy', 'RestrictPublicBuckets')},
                'BucketEncryption': {'ServerSideEncryptionConfiguration': [{'ServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}}]}}},
            'Policy': {'Type': 'AWS::S3::BucketPolicy', 'Properties': {'Bucket': {'Ref': 'Artifacts'},
                'PolicyDocument': {'Version': '2012-10-17', 'Statement': [{'Effect': 'Deny', 'Principal': '*', 'Action': 's3:*',
                    'Resource': [{'Fn::GetAtt': ['Artifacts', 'Arn']}, {'Fn::Sub': '${Artifacts.Arn}/*'}],
                    'Condition': {'Bool': {'aws:SecureTransport': 'false'}}}]}}}},
        'Outputs': {'Bucket': {'Value': {'Ref': 'Artifacts'}}}})
    buffer = io.BytesIO()
    metrics = json.loads((ROOT / 'analytics/schema.json').read_text())['metrics']
    with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as archive:
        # Fixed timestamps keep identical deployments content-addressable.
        for path in sorted((ROOT / 'analytics/server').glob('*.py')):
            source = path.read_text().replace('METRICS = {}  # SCHEMA', 'METRICS = ' + repr(metrics))
            archive.writestr(zipfile.ZipInfo(path.name, (2026, 1, 1, 0, 0, 0)), source)
        hymns = json.loads((ROOT / 'assets/hymns.json').read_text())['hymns']
        catalog = {f"{h['version']}:{h['number']}": h['title'] for h in hymns}
        archive.writestr(zipfile.ZipInfo('catalog.json', (2026, 1, 1, 0, 0, 0)), json.dumps(catalog))
    payload = buffer.getvalue()
    key = 'lambda/' + hashlib.sha256(payload).hexdigest() + '.zip'
    session.client('s3').put_object(Bucket=outputs['Bucket'], Key=key, Body=payload)
    return {'S3Bucket': outputs['Bucket'], 'S3Key': key}
