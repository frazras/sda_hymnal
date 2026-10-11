"""Private exporter continuation state; never published or exposed to clients."""
import json
import re
import boto3


def job_key(namespace, job_id):
    if namespace not in ('prod', 'e2e') or not isinstance(job_id, str) or not re.fullmatch('[a-f0-9]{32}', job_id):
        raise ValueError('invalid_export_job')
    return f'reports/{namespace}/export-jobs/{job_id}.json'


def load_job(s3, bucket, namespace, job_id):
    return json.loads(s3.get_object(Bucket=bucket, Key=job_key(namespace, job_id))['Body'].read())


def save_job(s3, bucket, namespace, job_id, state):
    s3.put_object(Bucket=bucket, Key=job_key(namespace, job_id),
                  Body=json.dumps(state, separators=(',', ':')).encode(), ContentType='application/json')


def continue_job(context, namespace, job_id, revision, preview):
    payload = dict(namespace=namespace, job_id=job_id, revision=revision, preview=preview)
    result = boto3.client('lambda').invoke(FunctionName=context.invoked_function_arn,
        InvocationType='Event', Payload=json.dumps(payload).encode())
    if result['StatusCode'] != 202:
        raise RuntimeError('export_continuation_not_accepted')
