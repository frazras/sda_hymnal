import base64
import importlib
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

from botocore.exceptions import ClientError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'server'))
import error_reports
import admin
import collector


def fixture(**changes):
    return dict(id='a' * 32, kind='hymn', title='Praise, with "joy"',
                description='Wrong word\non verse two', edition='new', number=1,
                item_id='new:1', version='4.5.0', **changes)


class ErrorReportsTest(unittest.TestCase):
    def test_subject_validation(self):
        for kind in ('hymn', 'reading', 'general'):
            report = fixture()
            report['kind'] = kind
            if kind == 'general':
                report.update(edition='', number=0, item_id='')
            self.assertEqual(error_reports.validate(report)['kind'], kind)
        for changes in ({'title': '  '}, {'description': ' '}, {'number': True},
                        {'kind': 'other'}, {'description': 'x' * 5001},
                        {'id': '../unsafe'}, {'edition': 'bad'}, {'kind': 'general'}):
            with self.assertRaises(ValueError):
                error_reports.validate(fixture() | changes)

    @patch.dict(os.environ, {'ERROR_REPORTS': 'feedback'})
    @patch.object(error_reports.boto3, 'resource')
    def test_submit_retry_and_storage_failure(self, resource):
        table = resource.return_value.Table.return_value
        event = {'body': json.dumps(fixture())}
        self.assertEqual(error_reports.submit(event)['statusCode'], 201)
        stored = table.put_item.call_args.kwargs['Item']
        self.assertEqual(stored['status'], 'open')
        self.assertNotIn('expires', stored)
        table.put_item.side_effect = ClientError({'Error': {'Code': 'ConditionalCheckFailedException'}}, 'PutItem')
        self.assertEqual(error_reports.submit(event)['statusCode'], 201)
        table.put_item.side_effect = ClientError({'Error': {'Code': 'ServiceUnavailable'}}, 'PutItem')
        self.assertEqual(error_reports.submit(event)['statusCode'], 503)

    @patch.object(error_reports.boto3, 'resource')
    def test_reject_bad_payloads_before_storage(self, resource):
        for body in ('{', 'null', '[]', json.dumps(fixture() | {'description': ''})):
            self.assertEqual(error_reports.submit({'body': body})['statusCode'], 400)
        self.assertEqual(error_reports.submit({'body': 'x' * 50001})['statusCode'], 413)
        self.assertEqual(error_reports.submit({'body': '%%%', 'isBase64Encoded': True})['statusCode'], 400)
        resource.assert_not_called()

    @patch.dict(os.environ, {'ERROR_REPORTS': 'feedback'})
    @patch.object(error_reports.boto3, 'resource')
    def test_pagination_and_private_fields(self, resource):
        table = resource.return_value.Table.return_value
        table.query.return_value = {'Items': [fixture() | {'pk': 'REPORTS', 'sk': 'a' * 32}],
                                    'LastEvaluatedKey': {'pk': 'REPORTS', 'sk': 'b' * 32}}
        result = error_reports.list_reports({'queryStringParameters': {'cursor': 'c' * 32}})
        body = json.loads(result['body'])
        self.assertEqual(body['cursor'], 'b' * 32)
        self.assertNotIn('pk', body['reports'][0])
        self.assertEqual(table.query.call_args.kwargs['ExclusiveStartKey'], {'pk': 'REPORTS', 'sk': 'c' * 32})
        self.assertEqual(error_reports.list_reports({'queryStringParameters': {'cursor': 'bad'}})['statusCode'], 400)

    @patch.object(error_reports, 'list_reports', return_value={'statusCode': 200})
    def test_admin_auth_before_listing(self, listing):
        event = {'routeKey': 'GET /v1/admin/error-reports'}
        self.assertEqual(admin.handler(event, None)['statusCode'], 403)
        listing.assert_not_called()
        for groups in (['admins'], '[admins]', '["admins"]'):
            event['requestContext'] = {'authorizer': {'jwt': {'claims': {
                'cognito:groups': groups, 'token_use': 'access'}}}}
            self.assertEqual(admin.handler(event, None)['statusCode'], 200)
        event['requestContext']['authorizer']['jwt']['claims']['token_use'] = 'id'
        self.assertEqual(admin.handler(event, None)['statusCode'], 403)

    @patch.dict(os.environ, {'ORIGIN_SECRET': 'secret'})
    @patch.object(error_reports, 'submit', return_value={'statusCode': 201})
    def test_collector_requires_verified_origin(self, submit):
        event = {'routeKey': 'POST /v1/error-reports'}
        self.assertEqual(collector.handler(event, None)['statusCode'], 403)
        submit.assert_not_called()
        event['headers'] = {'x-origin-verify': 'secret'}
        self.assertEqual(collector.handler(event, None)['statusCode'], 201)


if __name__ == '__main__':
    unittest.main()
