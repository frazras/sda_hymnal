#!/usr/bin/env python3
"""Exercise live coarse counters and Lambda-built reports in isolated QA data."""
import datetime as dt
import json
import time
import urllib.error
import urllib.request
import uuid

import boto3

from deployment import ROOT


def main():
    state = json.loads((ROOT / 'build/analytics/deployment.json').read_text())
    session = boto3.Session(profile_name='frazras', region_name='us-east-1')
    today = dt.datetime.now(dt.timezone.utc).date()
    week = str(today - dt.timedelta(days=today.weekday(), weeks=1))
    table = session.resource('dynamodb').Table(state['Aggregates'])

    def cells():
        rows = []
        args = {'KeyConditionExpression': 'pk = :p', 'ExpressionAttributeValues': {':p': 'e2e#W#' + week}, 'ConsistentRead': True}
        while True:
            page = table.query(**args)
            rows.extend(page['Items'])
            if 'LastEvaluatedKey' not in page:
                return rows
            args['ExclusiveStartKey'] = page['LastEvaluatedKey']

    def song(rows, metric):
        return next((r for r in rows if r['dimensions'].get('view') == 'song' and r['dimensions']['metric'] == metric
            and r['dimensions']['hymn'] == 695 and r['dimensions']['edition'] == 'new'), {'count': 0, 'contributors': 0})

    before = cells()
    expected_counts = {'hymn_open': 60, 'hymn_repeat': 40, 'favorite_add': 20}
    for index in range(20):
        token = uuid.uuid4().hex
        rows = [{'metric': metric, 'variant': 'keypad' if metric == 'hymn_open' else '', 'hymn': 695, 'edition': 'new',
            'weekday': 6, 'time': 'morning', 'count': count // 20, 'total': 0} for metric, count in expected_counts.items()]
        body = {'schema': 1, 'batch_id': uuid.uuid4().hex, 'token': token, 'week': week,
            'platform': 'ios', 'version': '0.2.1', 'design': 'modern', 'rows': rows}
        request = urllib.request.Request(state['Endpoint'] + '/v1/batches', data=json.dumps(body).encode(),
            headers={'Content-Type': 'application/json', 'X-Analytics-Test': state['TestSecret']})
        for retry in range(5):
            try:
                with urllib.request.urlopen(request, timeout=30) as reply:
                    assert json.loads(reply.read())['accepted'] == body['batch_id']
                break
            except urllib.error.HTTPError as exc:
                if exc.code not in (429, 503) or retry == 4:
                    raise
                time.sleep(2 ** retry)
        time.sleep(0.3)
    after = cells()
    for metric, count in expected_counts.items():
        initial, final = song(before, metric), song(after, metric)
        assert final['count'] - initial['count'] == count
        assert final['contributors'] - initial['contributors'] == 20
    s3 = session.client('s3')
    baseline = json.loads(s3.get_object(Bucket=state['Reports'], Key='public/trends.json')['Body'].read())
    invoke = session.client('lambda').invoke(FunctionName=state['Exporter'], Payload=b'{"namespace":"e2e","preview":true}')
    result = json.loads(invoke['Payload'].read())
    assert 'FunctionError' not in invoke, result
    preview = json.loads(s3.get_object(Bucket=state['Reports'], Key='reports/e2e/preview/public/trends.json')['Body'].read())
    for field, metric in [('top_songs', 'hymn_open'), ('repeat_songs', 'hymn_repeat'), ('favorites', 'favorite_add')]:
        row = next(r for r in preview['periods']['1'][field] if r['hymn'] == 695 and r['edition'] == 'new')
        assert row['count'] == song(after, metric)['count']
    public = json.loads(urllib.request.urlopen(state['Endpoint'] + '/v1/trends', timeout=30).read())
    assert public['schema'] == 2
    # Compare directly with the production artifact; QA export cannot replace it.
    production = json.loads(s3.get_object(Bucket=state['Reports'], Key='public/trends.json')['Body'].read())
    assert baseline['periods'] == production['periods']
    result = {'week': week, 'checks': ['20 contributors accepted', 'opens/repeats/favorites reconciled',
        'coarse distinct counts reconciled', 'Lambda public preview verified', 'production isolation verified']}
    (ROOT / 'build/analytics/community-verification.json').write_text(json.dumps(result, indent=2))
    print('PASS: 20 isolated contributors -> live aggregates -> public report preview; production unaffected.')


if __name__ == '__main__':
    main()
