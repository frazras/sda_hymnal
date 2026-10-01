"""User-submitted feedback, stored separately from aggregate statistics."""
import base64
import datetime as dt
import json
import os
import re

import boto3
from botocore.exceptions import ClientError


def response(status, body):
    return {'statusCode': status, 'headers': {'content-type': 'application/json',
        'cache-control': 'no-store', 'x-content-type-options': 'nosniff'},
        'body': json.dumps(body, default=int)}


def validate(body):
    fields = {'id', 'kind', 'title', 'description', 'edition', 'number', 'item_id', 'version'}
    if not isinstance(body, dict) or set(body) != fields:
        raise ValueError('invalid_fields')
    for field, maximum in [('id', 32), ('kind', 10), ('title', 200), ('description', 5000),
                           ('edition', 3), ('item_id', 150), ('version', 30)]:
        if not isinstance(body[field], str) or len(body[field]) > maximum:
            raise ValueError('invalid_' + field)
        body[field] = body[field].strip()
    if not re.fullmatch('[a-f0-9]{32}', body['id']):
        raise ValueError('invalid_id')
    if not body['title'] or not body['description'] or not body['version']:
        raise ValueError('missing_text')
    if type(body['number']) is not int or body['kind'] not in ('general', 'hymn', 'reading'):
        raise ValueError('invalid_subject')
    if body['kind'] == 'general':
        if body['edition'] or body['item_id'] or body['number'] != 0:
            raise ValueError('invalid_general_subject')
    elif body['edition'] not in ('old', 'new') or not 1 <= body['number'] <= 9999 or not body['item_id']:
        raise ValueError('invalid_content_subject')
    return body


def submit(event):
    try:
        raw = event.get('body') or ''
        if len(raw) > 50000:
            return response(413, {'error': 'report_too_large'})
        if event.get('isBase64Encoded'):
            raw = base64.b64decode(raw, validate=True).decode('utf-8')
        body = validate(json.loads(raw))
    except (ValueError, TypeError, UnicodeError):
        return response(400, {'error': 'invalid_report'})
    item = dict(body, pk='REPORTS', sk=body['id'],
        created_at=dt.datetime.now(dt.timezone.utc).isoformat(), status='open')
    try:
        boto3.resource('dynamodb').Table(os.environ['ERROR_REPORTS']).put_item(
            Item=item, ConditionExpression='attribute_not_exists(pk)')
    except ClientError as exc:
        if exc.response['Error']['Code'] != 'ConditionalCheckFailedException':
            return response(503, {'error': 'report_unavailable'})
        # The same submission may be retried after a lost network response.
    return response(201, {'id': body['id']})


def list_reports(event):
    query = event.get('queryStringParameters') or {}
    cursor = query.get('cursor')
    if cursor is not None and (not isinstance(cursor, str) or not re.fullmatch('[a-f0-9]{32}', cursor)):
        return response(400, {'error': 'invalid_cursor'})
    options = {'KeyConditionExpression': 'pk = :pk',
        'ExpressionAttributeValues': {':pk': 'REPORTS'}, 'Limit': 100,
        'ConsistentRead': True}
    if cursor:
        options['ExclusiveStartKey'] = {'pk': 'REPORTS', 'sk': cursor}
    try:
        result = boto3.resource('dynamodb').Table(os.environ['ERROR_REPORTS']).query(**options)
    except ClientError:
        return response(503, {'error': 'reports_unavailable'})
    return response(200, {'reports': [{k: v for k, v in item.items() if k not in ('pk', 'sk')}
        for item in result.get('Items', [])], 'cursor': result.get('LastEvaluatedKey', {}).get('sk')})
