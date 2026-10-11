#!/usr/bin/env python3
"""Verify native identities through live isolated QA counters and report exports."""
import datetime as dt
import json
from pathlib import Path
import time
import urllib.request
import uuid
import boto3

ROOT = Path(__file__).resolve().parents[1]

def main():
    state = json.loads((ROOT / 'build/analytics/deployment.json').read_text())
    session = boto3.Session(profile_name='frazras', region_name='us-east-1')
    today = dt.datetime.now(dt.timezone.utc).date()
    week = str(today - dt.timedelta(days=today.weekday(), weeks=1))
    version = '0.3.' + str(int(uuid.uuid4().hex[:4], 16))
    books = ['sda-es-2009', 'sda-es-1962']
    last = None
    for index in range(20):
        body = dict(schema=2, batch_id=uuid.uuid4().hex, token=uuid.uuid4().hex,
                    week=week, platform='ios', version=version, design='modern',
                    rows=[dict(metric='hymn_open', variant='keypad', hymn=303,
                               edition='', book_id=book, weekday=6, time='morning',
                               count=1, total=0) for book in books])
        def submit():
            request = urllib.request.Request(state['Endpoint'] + '/v1/batches',
                data=json.dumps(body).encode(), headers={'Content-Type': 'application/json',
                'X-Analytics-Test': state['TestSecret']})
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read())
        reply = submit()
        assert reply['accepted'] == body['batch_id']
        if index == 19:
            assert submit()['duplicate'] is True
        time.sleep(0.25)
    table = session.resource('dynamodb').Table(state['Aggregates'])
    args = dict(KeyConditionExpression='pk = :p',
                ExpressionAttributeValues={':p': 'e2e#W#' + week}, ConsistentRead=True)
    rows = []
    while True:
        page = table.query(**args)
        rows.extend(i for i in page['Items'] if i['dimensions'].get('version') == version)
        if 'LastEvaluatedKey' not in page:
            break
        args['ExclusiveStartKey'] = page['LastEvaluatedKey']
    assert len(rows) == 2
    assert {r['dimensions']['book_id'] for r in rows} == set(books)
    assert all(int(r['count']) == 20 and int(r['contributors']) == 20 for r in rows)
    invocation = session.client('lambda').invoke(FunctionName=state['Exporter'],
        Payload=b'{"namespace":"e2e","preview":true}')
    result = json.loads(invocation['Payload'].read())
    assert 'FunctionError' not in invocation, result
    s3 = session.client('s3')
    def report(name):
        return json.loads(s3.get_object(Bucket=state['Reports'],
            Key='reports/e2e/preview/public/' + name)['Body'].read())
    native, legacy = report('trends-native.json'), report('trends.json')
    native_songs = native['periods']['1']['top_songs']
    for book in books:
        song = next(s for s in native_songs if s.get('book_id') == book and s['hymn'] == 303)
        assert song['book_label'] and song['title'] != 'Hymn 303'
    assert all(s['edition'] in ('old', 'new') and 'book_id' not in s
               for p in legacy['periods'].values() for s in p['top_songs'])
    print('PASS: native QA submissions, retry deduplication, stored book separation, multilingual titles, and legacy snapshots.')

if __name__ == '__main__':
    main()
