import copy
import datetime as dt
import importlib.util
import json
from pathlib import Path
import unittest
import sys
from unittest.mock import Mock, patch
from decimal import Decimal

from boto3.dynamodb.types import TypeDeserializer
from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'analytics/server'))
from reporting import public_report, admin_report
spec = importlib.util.spec_from_file_location('collector', ROOT / 'analytics/server/collector.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
collector.METRICS = json.loads((ROOT / 'analytics/schema.json').read_text())['metrics']


def fixture():
    return {'schema': 1, 'batch_id': '1' * 32, 'token': '2' * 32, 'week': '2026-08-31',
        'platform': 'android', 'version': '4.2.0', 'design': 'modern', 'rows': [
            {'metric': 'hymn_open', 'variant': 'keypad', 'hymn': 1, 'edition': 'new',
             'weekday': 7, 'time': 'morning', 'count': 3, 'total': 0}]}


class NativeCollectorTest(unittest.TestCase):
    def test_native_validation_and_book_specific_cells(self):
        body = fixture()
        body['schema'] = 2
        body['rows'][0].update(book_id='sda-es-2009', edition='', hymn=303)
        with patch.dict(collector.BOOK_HYMNS, {'sda-es-2009': [303]}):
            collector.validate(body, dt.date(2026, 9, 1))
            cells = collector.cells_for(body, 'JM', 'prod')
            songs = [c for c in cells if c['dimensions'].get('view') == 'song']
            self.assertEqual(songs[0]['dimensions']['book_id'], 'sda-es-2009')
            for changes in ({'hymn': 999}, {'book_id': 'sda-es-1962'},
                            {'edition': 'new'}, {'book_id': None}):
                invalid = copy.deepcopy(body)
                invalid['rows'][0].update(changes)
                with self.assertRaises(ValueError):
                    collector.validate(invalid, dt.date(2026, 9, 1))

    def test_native_english_preserves_legacy_cells(self):
        legacy = fixture()
        native = copy.deepcopy(legacy)
        native['schema'] = 2
        native['rows'][0]['book_id'] = 'sda-en-1985'
        with patch.dict(collector.BOOK_HYMNS, {'sda-en-1985': [1]}):
            collector.validate(native, dt.date(2026, 9, 1))
        self.assertEqual(collector.cells_for(native, 'JM', 'prod'),
                         collector.cells_for(legacy, 'JM', 'prod'))


class Table:
    def __init__(self, name):
        self.name, self.items = name, {}

    def get_item(self, Key, **kwargs):
        return {'Item': self.items[Key['pk']]} if Key['pk'] in self.items else {}

    def put_item(self, Item, **kwargs):
        if Item['pk'] in self.items:
            raise ClientError({'Error': {'Code': 'ConditionalCheckFailedException'}}, 'PutItem')
        self.items[Item['pk']] = copy.deepcopy(Item)

    def update_item(self, Key, **kwargs):
        self.items[Key['pk']]['status'] = kwargs['ExpressionAttributeValues'][':s']


class Client:
    def __init__(self, ledger, aggregates):
        self.ledger, self.aggregates = ledger, aggregates
        self.fail = False
        self.calls = 0
        self.fail_call = 0

    def batch_get_item(self, RequestItems):
        return {'Responses': {self.ledger.name: [collector.encode(self.ledger.items[key['pk']['S']])
            for key in RequestItems[self.ledger.name]['Keys'] if key['pk']['S'] in self.ledger.items]}}

    def transact_write_items(self, TransactItems):
        self.calls += 1
        if self.calls == self.fail_call:
            raise ClientError({'Error': {'Code': 'ProvisionedThroughputExceededException'}}, 'TransactWriteItems')
        assert len(TransactItems) <= 100
        deserialize = lambda data: {k: TypeDeserializer().deserialize(v) for k, v in data.items()}
        if self.fail:
            self.fail = False
            raise ClientError({'Error': {'Code': 'TransactionCanceledException'}}, 'TransactWriteItems')
        ledger, aggregates = copy.deepcopy(self.ledger.items), copy.deepcopy(self.aggregates.items)
        for action in TransactItems:
            if 'Put' in action:
                item = deserialize(action['Put']['Item'])
                if item['pk'] in ledger:
                    raise ClientError({'Error': {'Code': 'TransactionCanceledException'}}, 'TransactWriteItems')
                ledger[item['pk']] = item
            else:
                update = action['Update']
                key = deserialize(update['Key'])
                values = deserialize(update['ExpressionAttributeValues'])
                item = aggregates.setdefault((key['pk'], key['sk']), {'count': 0, 'total': 0, 'contributors': 0})
                for field, param in [('count', ':c'), ('total', ':t'), ('contributors', ':u')]:
                    item[field] += values[param]
                item['dimensions'] = values[':d']
                item['expires'] = values[':e']
        self.ledger.items, self.aggregates.items = ledger, aggregates


class Tests(unittest.TestCase):
    def setUp(self):
        self.ledger, self.table = Table('ledger'), Table('aggregates')
        self.client = Client(self.ledger, self.table)

    def submit(self, body, country='JM'):
        return collector.collect(body, country, 'e2e', self.table, self.ledger, self.client, now=1788652800)

    def test_strict_schema(self):
        collector.validate(fixture(), dt.date(2026, 9, 6))
        for mutation in [lambda b: b.update(ip='127.0.0.1'),
                         lambda b: b['rows'][0].update(query='private'),
                         lambda b: b['rows'][0].update(count=True),
                         lambda b: b['rows'][0].update(total=-1),
                         lambda b: b['rows'][0].update(hymn=999),
                         lambda b: b.update(week='2026-01-05'),
                         lambda b: b['rows'].append(copy.deepcopy(b['rows'][0]))]:
            body = fixture(); mutation(body)
            with self.assertRaises((ValueError, TypeError)):
                collector.validate(body, dt.date(2026, 9, 6))

    def test_retry_and_changed_payload(self):
        body = fixture()
        self.assertEqual(self.submit(body)['statusCode'], 200)
        # Even a moved upload country must not duplicate a committed batch.
        self.assertTrue(json.loads(self.submit(body, 'US')['body'])['duplicate'])
        self.assertEqual(next(iter(self.table.items.values()))['count'], 3)
        body['rows'][0]['count'] = 4
        self.assertEqual(self.submit(body)['statusCode'], 409)

    def test_distinct_installation_with_multiple_batches(self):
        body = fixture()
        self.submit(body)
        body['batch_id'] = '3' * 32
        self.submit(body)
        item = next(iter(self.table.items.values()))
        self.assertEqual((item['count'], item['contributors']), (6, 1))
        body.update(batch_id='4' * 32, token='5' * 32)
        self.submit(body)
        item = next(iter(self.table.items.values()))
        self.assertEqual((item['count'], item['contributors']), (9, 2))
        self.assertNotIn('token', json.dumps(self.ledger.items, default=int))
        self.assertNotIn('token', str(self.table.items))

    def test_atomic_failure_retries_without_double_counting(self):
        self.client.fail = True
        self.submit(fixture())
        self.assertEqual(next(iter(self.table.items.values()))['count'], 3)

    def test_export_serializes_dynamodb_numbers_and_excludes_test_public_data(self):
        table = Mock()
        table.query.return_value = {'Items': [{'dimensions': {'metric': 'hymn_open', 'hymn': Decimal(1), 'weekday': Decimal(7), 'edition': 'new'},
            'count': Decimal(3), 'total': Decimal(0), 'contributors': Decimal(1), 'expires': Decimal('9999999999')}]}
        resource = Mock(); resource.Table.return_value = table
        s3 = Mock(); s3.get_paginator.return_value.paginate.return_value = []
        with patch.dict(collector.os.environ, {'AGGREGATES': 'test', 'BUCKET': 'test'}), \
             patch.object(collector.boto3, 'resource', return_value=resource), \
             patch.object(collector.boto3, 'client', return_value=s3):
            result = collector.export_handler({'namespace': 'e2e'}, None)
        self.assertEqual(result['exported_rows'], 58)
        self.assertTrue(all(call.kwargs['Limit'] == 500 for call in table.query.call_args_list))
        for call in s3.put_object.call_args_list:
            self.assertTrue(call.kwargs['Key'].startswith('reports/e2e/'))
            row = json.loads(call.kwargs['Body'])
            self.assertEqual(row['hymn'], 1)

    def test_export_follows_bounded_pages_without_dropping_rows(self):
        table = Mock()
        item = {'dimensions': {'metric': 'app_session'}, 'count': 1,
                'total': 0, 'contributors': 1, 'expires': 9999999999}
        table.query.side_effect = [
            {'Items': [item], 'LastEvaluatedKey': {'pk': 'continuation'}},
            {'Items': [item]}, *[{'Items': []} for _ in range(57)]]
        resource = Mock(); resource.Table.return_value = table
        s3 = Mock(); s3.get_paginator.return_value.paginate.return_value = []
        with patch.dict(collector.os.environ, {'AGGREGATES': 'test', 'BUCKET': 'test'}), \
             patch.object(collector.boto3, 'resource', return_value=resource), \
             patch.object(collector.boto3, 'client', return_value=s3):
            result = collector.export_handler({'namespace': 'e2e'}, None)
        self.assertEqual(result['exported_rows'], 2)
        self.assertEqual(table.query.call_count, 59)
        self.assertEqual(table.query.call_args_list[1].kwargs['ExclusiveStartKey'], {'pk': 'continuation'})
        self.assertEqual(len(s3.put_object.call_args.kwargs['Body'].splitlines()), 2)

    def test_export_checkpoints_and_resumes_inside_a_week(self):
        table = Mock()
        item = {'dimensions': {'metric': 'app_session'}, 'count': 1,
                'total': 0, 'contributors': 1, 'expires': 9999999999}
        table.query.return_value = {'Items': [item], 'LastEvaluatedKey': {'pk': 'next'}}
        resource = Mock(); resource.Table.return_value = table
        s3 = Mock(); s3.get_paginator.return_value.paginate.return_value = []
        context = Mock()
        context.get_remaining_time_in_millis.side_effect = [300000, 50000]
        with patch.dict(collector.os.environ, {'AGGREGATES': 'test', 'BUCKET': 'test'}), \
             patch.object(collector.boto3, 'resource', return_value=resource), \
             patch.object(collector.boto3, 'client', return_value=s3), \
             patch('export_checkpoint.save_job') as save, \
             patch('export_checkpoint.continue_job') as continuation:
            pending = collector.export_handler({'namespace': 'e2e'}, context)
            state = copy.deepcopy(save.call_args.args[-1])
            self.assertTrue(pending['pending'])
            self.assertEqual(state['cursor'], {'pk': 'next'})
            self.assertEqual(len(state['rows']), 1)
            continuation.assert_called_once()
            table.reset_mock()
            table.query.side_effect = [{'Items': [item]}, *[{'Items': []} for _ in range(57)]]
            context.get_remaining_time_in_millis.side_effect = None
            context.get_remaining_time_in_millis.return_value = 300000
            with patch('export_checkpoint.load_job', return_value=state):
                result = collector.export_handler(dict(namespace='e2e', job_id=pending['job_id'], revision=1), context)
            self.assertEqual(result['exported_rows'], 2)
            self.assertEqual(table.query.call_args_list[0].kwargs['ExclusiveStartKey'], {'pk': 'next'})
            self.assertTrue(save.call_args.args[-1]['complete'])
            raw = next(c.kwargs['Body'] for c in s3.put_object.call_args_list if c.kwargs['Key'].endswith('metrics.jsonl'))
            self.assertEqual(len(raw.splitlines()), 2)
            table.reset_mock()
            with patch('export_checkpoint.load_job', return_value={'complete': True, 'revision': 1, 'exported': 2}):
                duplicate = collector.export_handler(dict(namespace='e2e', job_id=pending['job_id'], revision=1), context)
            self.assertTrue(duplicate['stale'])
            table.query.assert_not_called()

    def test_export_does_not_queue_a_continuation_without_progress(self):
        resource = Mock()
        s3 = Mock(); s3.get_paginator.return_value.paginate.return_value = []
        context = Mock(); context.get_remaining_time_in_millis.return_value = 50000
        with patch.dict(collector.os.environ, {'AGGREGATES': 'test', 'BUCKET': 'test'}), \
             patch.object(collector.boto3, 'resource', return_value=resource), \
             patch.object(collector.boto3, 'client', return_value=s3), \
             patch('export_checkpoint.continue_job') as continuation:
            with self.assertRaisesRegex(RuntimeError, 'export_no_time_for_progress'):
                collector.export_handler({'namespace': 'e2e'}, context)
            continuation.assert_not_called()

    def test_public_trends_suppresses_small_current_and_private_cells(self):
        def item(metric, contributors):
            dimensions = {k: v for k, v in fixture()['rows'][0].items() if k not in ('count', 'total')}
            dimensions = {k: dimensions[k] for k in ('metric', 'hymn', 'edition')}
            dimensions.update(metric=metric, view='song')
            return {'dimensions': dimensions, 'count': 100, 'total': 0,
                    'contributors': contributors, 'expires': 9999999999}
        table = Mock()
        table.query.side_effect = [
            {'Items': [item('hymn_open', 50)]},  # current week is never public
            {'Items': [item('hymn_open', 19), item('favorite_add', 20), item('diagnostic', 50)]},
            *[{'Items': []} for _ in range(56)]]
        resource = Mock(); resource.Table.return_value = table
        s3 = Mock(); s3.get_paginator.return_value.paginate.return_value = []
        glue = Mock(); glue.batch_create_partition.return_value = {'Errors': [{'ErrorDetail': {'ErrorCode': 'AlreadyExistsException'}}]}
        with patch.dict(collector.os.environ, {'AGGREGATES': 'test', 'BUCKET': 'test', 'GLUE_DATABASE': 'test', 'GLUE_DESCRIPTOR': '{}'}), \
             patch.object(collector.boto3, 'resource', return_value=resource), \
             patch.object(collector.boto3, 'client', side_effect=lambda name: s3 if name == 's3' else glue):
            collector.export_handler({}, None)
        public = next(json.loads(call.kwargs['Body']) for call in s3.put_object.call_args_list if call.kwargs['Key'] == 'public/trends.json')
        self.assertEqual(public['periods']['1']['top_songs'], [])
        self.assertEqual(public['periods']['1']['favorites'][0]['count'], 100)
        self.assertNotIn('contributors', json.dumps(public['periods']))
        self.assertNotIn('diagnostic', json.dumps(public))

    def test_partial_batch_resumes_with_original_country_and_no_duplicates(self):
        body = fixture()
        body['rows'] = [dict(body['rows'][0], hymn=i) for i in range(1, 41)]
        self.client.fail_call = 2
        with self.assertRaises(ClientError):
            self.submit(body)
        self.assertGreater(len(self.table.items), 0)
        self.assertEqual(self.submit(body, 'US')['statusCode'], 200)
        expected = collector.cells_for(body, 'JM', 'e2e')
        self.assertEqual(len(self.table.items), len(expected))
        for cell in expected:
            item = self.table.items[(cell['pk'], cell['sk'])]
            self.assertEqual(item['count'], cell['count'])
            self.assertEqual(item['contributors'], 1)
        self.assertNotIn('US', str(self.table.items))
        before = copy.deepcopy(self.table.items)
        self.submit(body)
        self.assertEqual(self.table.items, before)

    def test_coarse_contributors_deduplicated_across_sources_times_and_versions(self):
        body = fixture()
        self.submit(body)
        body.update(batch_id='a' * 32, version='4.2.1')
        body['rows'][0].update(variant='search', time='evening', weekday=1)
        self.submit(body)
        song = next(i for i in self.table.items.values() if i['dimensions'].get('view') == 'song')
        self.assertEqual((song['count'], song['contributors']), (6, 1))
        self.assertEqual(len([i for i in self.table.items.values() if 'view' not in i['dimensions']]), 2)

    def test_legacy_receipt_stays_complete(self):
        body = fixture()
        key = 'e2e#B#' + body['batch_id']
        self.ledger.items[key] = {'pk': key, 'fingerprint': collector.digest(json.dumps(body, sort_keys=True, separators=(',', ':')))}
        self.assertTrue(json.loads(self.submit(body)['body'])['duplicate'])
        self.assertEqual(self.table.items, {})

    def test_complementary_suppression_and_period_counts(self):
        song = {'metric': 'hymn_open', 'view': 'song', 'hymn': 1, 'edition': 'new', 'count': 100, 'total': 0, 'contributors': 30}
        rows = [song, dict(song, view='country_song', country='JM', count=90),
                dict(song, view='country_song', country='US', count=10, contributors=2),
                {'metric': 'hymn_open', 'view': 'time', 'time': 'morning', 'count': 90, 'contributors': 30},
                {'metric': 'hymn_open', 'view': 'time', 'time': 'night', 'count': 10, 'contributors': 2}]
        report = public_report({'2026-08-31': rows, '2026-08-24': [song]}, dt.date(2026, 9, 7), '2026-09-07T00:00:00Z')
        self.assertEqual(report['periods']['1']['countries'], [])
        self.assertEqual(report['periods']['1']['times'], [])
        self.assertEqual(report['periods']['1']['top_songs'][0]['count'], 100)
        self.assertEqual(report['periods']['4']['top_songs'][0]['count'], 200)

    def test_admin_excludes_rollup_double_counts_and_filters_platform(self):
        fine = dict(fixture()['rows'][0], platform='android', version='4.2.0', country='JM', contributors=1)
        rollup = dict(fine, view='song')
        ios = dict(fine, platform='ios', count=7)
        report = admin_report({'2026-08-31': [fine, rollup, ios]}, dt.date(2026, 9, 7), 'today')
        self.assertEqual(report['periods']['1']['platforms']['all']['totals']['hymn_open'], 10)
        self.assertEqual(report['periods']['1']['platforms']['android']['totals']['hymn_open'], 3)


if __name__ == '__main__':
    unittest.main()
