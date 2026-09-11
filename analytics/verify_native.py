#!/usr/bin/env python3
"""Verify the native integration test's live aggregate after its UI checks."""
import datetime as dt
import json
from pathlib import Path

import boto3

ROOT = Path(__file__).resolve().parents[1]
log = (ROOT / 'build/analytics/ios-integration.log').read_text()
assert 'All tests passed!' in log, 'Run the native integration test successfully first'
state = json.loads((ROOT / 'build/analytics/deployment.json').read_text())
version = json.loads((ROOT / 'build/analytics/e2e-defines.json').read_text())['ANALYTICS_TEST_VERSION']
table = boto3.Session(profile_name='frazras', region_name='us-east-1').resource('dynamodb').Table(state['Aggregates'])
today = dt.date.today()
monday = today - dt.timedelta(days=today.weekday())
items = []
for offset in (0, 1):
    query = {'KeyConditionExpression': 'pk = :p', 'ExpressionAttributeValues': {':p': 'e2e#W#' + str(monday - dt.timedelta(weeks=offset))}, 'ConsistentRead': True}
    while True:
        page = table.query(**query)
        items.extend(item for item in page['Items'] if item['dimensions'].get('version') == version)
        if 'LastEvaluatedKey' not in page:
            break
        query['ExclusiveStartKey'] = page['LastEvaluatedKey']
assert items, 'Native app submission missing'
assert all(i['dimensions']['platform'] == 'ios' for i in items)
hymns = [i for i in items if i['dimensions']['metric'] == 'hymn_open']
assert len(hymns) == 1 and int(hymns[0]['count']) == 1
assert hymns[0]['dimensions']['variant'] == 'keypad'
assert int(hymns[0]['dimensions']['hymn']) == 1 and hymns[0]['dimensions']['edition'] == 'new'
assert int(hymns[0]['contributors']) == 1
assert not any(i['dimensions']['metric'] == 'diagnostic' and i['dimensions']['variant'] in ('flutter_error', 'platform_error') for i in items)

report = {'platform': 'ios', 'app_version': version, 'stored_rows': len(items),
          'country': hymns[0]['dimensions']['country'], 'hymn_open_count': 1,
          'checks': ['native storage channel', 'SQLite plugin', 'default-on fresh installation', 'Settings enable switch',
                     'Statistics page while opted out', 'community reporting period control',
                     'real keypad hymn opening', 'live HTTPS submission',
                     'DynamoDB aggregate count', 'no framework diagnostics', 'opt-out clears native analytics']}
(ROOT / 'build/analytics/native-submission.json').write_text(json.dumps(report, indent=2))
print('PASS: iOS UI submission stored exactly once; native analytics tables and identifiers cleared after disabling.')
