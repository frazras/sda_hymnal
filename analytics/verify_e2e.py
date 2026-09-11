#!/usr/bin/env python3
"""Verify committed app submissions and reporting, using AWS read permissions."""
import json
from pathlib import Path
import re
import time
import uuid
import urllib.error
import urllib.request
import boto3

ROOT = Path(__file__).resolve().parents[1]
state = json.loads((ROOT / 'build/analytics/deployment.json').read_text())
report_path = ROOT / 'build/analytics/e2e-submission.json'
report = json.loads(report_path.read_text())
session = boto3.Session(profile_name='frazras', region_name='us-east-1')
table = session.resource('dynamodb').Table(state['Aggregates'])
args = {'KeyConditionExpression': 'pk = :p', 'ExpressionAttributeValues': {':p': 'e2e#W#' + report['week']}, 'ConsistentRead': True}
items = []
while True:
    page = table.query(**args)
    items.extend(i for i in page['Items'] if i['dimensions'].get('version') == report['version'])
    if 'LastEvaluatedKey' not in page: break
    args['ExclusiveStartKey'] = page['LastEvaluatedKey']
assert len(items) == len(report['expected']), ('Missing rows', len(items))
for expected in report['expected']:
    actual = next(i for i in items if i['dimensions']['metric'] == expected['metric'])
    assert int(actual['count']) == expected['count'], 'Retry double-counted'
    assert int(actual['total']) == expected['total']
    assert int(actual['contributors']) == 1
    assert not {'token', 'ip', 'installation_id'} & set(actual['dimensions'])

export = session.client('lambda').invoke(FunctionName=state['Exporter'], Payload=b'{"namespace":"e2e"}')
result = json.loads(export['Payload'].read())
assert 'FunctionError' not in export, result
s3 = session.client('s3')
content = s3.get_object(Bucket=state['Reports'], Key='reports/e2e/week=' + report['week'] + '/metrics.jsonl')['Body'].read().decode()
exported = [json.loads(line) for line in content.splitlines() if json.loads(line)['version'] == report['version']]
assert len(exported) == len(items), 'Export missing rows'

# Exercise the real SQL workgroup/JSON schema without adding QA partitions to
# the production table. The temporary table only references isolated QA data.
glue = session.client('glue')
athena = session.client('athena')
test_table = 'e2e_metrics_' + uuid.uuid4().hex[:12]
descriptor = glue.get_table(DatabaseName=state['Database'], Name='metrics')['Table']['StorageDescriptor']
descriptor['Location'] = 's3://' + state['Reports'] + '/reports/e2e/week=' + report['week'] + '/'
assert re.fullmatch(r'\d+\.\d+\.\d+', report['version'])
try:
    glue.create_table(DatabaseName=state['Database'], TableInput={
        'Name': test_table, 'TableType': 'EXTERNAL_TABLE', 'StorageDescriptor': descriptor})
    query_id = athena.start_query_execution(
        QueryString='SELECT metric, sum("count") AS actions, sum(total) AS measurement FROM ' + test_table +
                    " WHERE version = '" + report['version'] + "' GROUP BY metric",
        QueryExecutionContext={'Database': state['Database']}, WorkGroup=state['Workgroup'])['QueryExecutionId']
    for _ in range(30):
        query = athena.get_query_execution(QueryExecutionId=query_id)['QueryExecution']
        if query['Status']['State'] in ('SUCCEEDED', 'FAILED', 'CANCELLED'):
            break
        time.sleep(1)
    assert query['Status']['State'] == 'SUCCEEDED', query['Status']
    sql_rows = athena.get_query_results(QueryExecutionId=query_id)['ResultSet']['Rows'][1:]
    actual_sql = {row['Data'][0]['VarCharValue']: (int(row['Data'][1]['VarCharValue']), int(row['Data'][2]['VarCharValue'])) for row in sql_rows}
    assert actual_sql == {row['metric']: (row['count'], row['total']) for row in report['expected']}
    report['athena_scanned_bytes'] = query['Statistics']['DataScannedInBytes']
finally:
    glue.delete_table(DatabaseName=state['Database'], Name=test_table)

prod_export = session.client('lambda').invoke(FunctionName=state['Exporter'], Payload=b'{}')
prod_result = json.loads(prod_export['Payload'].read())
assert 'FunctionError' not in prod_export, prod_result
public = json.loads(urllib.request.urlopen(state['Endpoint'] + '/v1/trends', timeout=30).read())
assert report['version'] not in json.dumps(public), 'Test data leaked to public Trends'
assert all(row['contributors'] >= 20 for row in public['weeks'])

# Bypassing CloudFront cannot spoof its country header or reach the collector.
try:
    urllib.request.urlopen('https://' + state['Api'] + '.execute-api.us-east-1.amazonaws.com/v1/health', timeout=30)
    raise AssertionError('Origin bypass was accepted')
except urllib.error.HTTPError as error:
    assert error.code == 403

policy = urllib.request.urlopen(state['Endpoint'] + '/privacy-policy', timeout=30)
assert policy.headers['Content-Type'].startswith('text/html')
assert policy.read() == (ROOT / 'docs/privacy-policy.html').read_bytes()
report['checks'] = list(dict.fromkeys(report['checks'] + ['DynamoDB counts and distinct contributor', 'S3 reporting export', 'Athena SQL totals', 'public Trends isolation', 'origin bypass blocked', 'published privacy policy']))
report['country'] = items[0]['dimensions']['country']
report['stored_rows'] = len(items)
report['exported_rows'] = len(exported)
report_path.write_text(json.dumps(report, indent=2))
print('PASS: aggregate counts unchanged after retry; one contributor per cell; S3 export and Athena SQL verified; public isolation, origin protection and privacy policy verified.')
print('Upload country:', report['country'])
