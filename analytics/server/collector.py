"""Aggregate-only collector. Never log requests, IPs, tokens, or exceptions."""
import base64
import datetime as dt
import hashlib
import hmac
import json
import os
import re
import time
from decimal import Decimal

import boto3
from boto3.dynamodb.types import TypeSerializer
from botocore.exceptions import ClientError

# Injected from the shared schema into the deployed module.
METRICS = {}  # SCHEMA
MAX_ROWS = 40
serializer = TypeSerializer()


def encode(item):
    return {k: serializer.serialize(v) for k, v in item.items()}


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def response(status, value):
    return {"statusCode": status, "headers": {"content-type": "application/json",
            "cache-control": "no-store"}, "body": json.dumps(value, default=int)}


def validate(body, today):
    if not isinstance(body, dict) or set(body) != {"schema", "batch_id", "week", "token", "platform", "version", "design", "rows"}:
        raise ValueError("invalid_fields")
    if type(body["schema"]) is not int or body["schema"] != 1:
        raise ValueError("unsupported_schema")
    for key in ("batch_id", "token"):
        if not isinstance(body[key], str) or not re.fullmatch(r"[a-f0-9]{32}", body[key]):
            raise ValueError("invalid_id")
    if not isinstance(body['week'], str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', body['week']):
        raise ValueError('invalid_week')
    week = dt.date.fromisoformat(body["week"])
    if week.weekday() != 0 or week > today + dt.timedelta(days=1) or (today - week).days > 90:
        raise ValueError("expired_week")
    if body["platform"] not in ("android", "ios") or body["design"] not in ("modern", "classic"):
        raise ValueError("invalid_platform")
    if not isinstance(body["version"], str) or not re.fullmatch(r"\d{1,3}\.\d{1,3}\.\d{1,5}", body["version"]):
        raise ValueError("invalid_version")
    rows = body["rows"]
    if not isinstance(rows, list) or not 1 <= len(rows) <= MAX_ROWS:
        raise ValueError("invalid_rows")
    seen = set()
    for row in rows:
        if not isinstance(row, dict) or set(row) != {"metric", "variant", "hymn", "edition", "weekday", "time", "count", "total"}:
            raise ValueError("invalid_row_fields")
        if not isinstance(row["metric"], str) or row["metric"] not in METRICS or row["variant"] not in METRICS[row["metric"]]:
            raise ValueError("invalid_metric")
        for field in ("hymn", "weekday", "count", "total"):
            if type(row[field]) is not int:
                raise ValueError("invalid_number")
        if row["edition"] not in ("", "old", "new"):
            raise ValueError("invalid_edition")
        max_hymn = {"": 0, "old": 703, "new": 695}[row["edition"]]
        if not 0 <= row["hymn"] <= max_hymn or (row["hymn"] == 0) != (row["edition"] == ""):
            raise ValueError("invalid_hymn")
        if not 1 <= row["weekday"] <= 7 or row["time"] not in ("night", "morning", "afternoon", "evening"):
            raise ValueError("invalid_time")
        if not 1 <= row["count"] <= 100000 or not 0 <= row["total"] <= row["count"] * 3600000:
            raise ValueError("invalid_count")
        key = json.dumps({k: v for k, v in row.items() if k not in ("count", "total")}, sort_keys=True)
        if key in seen:
            raise ValueError("duplicate_row")
        seen.add(key)
    return body


def cells_for(body, country, namespace):
    """Independent coarse counters preserve distinctness across fine dimensions."""
    cells = {}
    for row in body['rows']:
        detail = {k: v for k, v in row.items() if k not in ('count', 'total')}
        detail.update({k: body[k] for k in ('platform', 'version', 'design')})
        detail['country'] = country
        dimensions = [detail]
        if row['hymn'] and row['metric'] in ('hymn_open', 'hymn_repeat', 'favorite_add'):
            song = {k: row[k] for k in ('metric', 'hymn', 'edition')}
            dimensions.append(dict(song, view='song'))
            if row['metric'] == 'hymn_open':
                dimensions.extend([dict(song, view='country_song', country=country),
                    {'metric': 'hymn_open', 'view': 'time', 'time': row['time']},
                    {'metric': 'hymn_open', 'view': 'weekday', 'weekday': row['weekday']}])
        for dim in dimensions:
            sk = ('@public' if 'view' in dim else row['metric']) + '#' + digest(json.dumps(dim, sort_keys=True))
            cell = cells.setdefault(sk, {'dimensions': dim, 'count': 0, 'total': 0,
                'pk': namespace + '#W#' + body['week'], 'sk': sk})
            cell['count'] += row['count']
            cell['total'] += row['total']
    return [cells[k] for k in sorted(cells)]


def distinct_keys(client, ledger, keys):
    found = set()
    pending = {ledger.name: {'Keys': [encode(k) for k in keys], 'ConsistentRead': True}}
    for attempt in range(4):
        result = client.batch_get_item(RequestItems=pending)
        found.update(item['pk']['S'] for item in result.get('Responses', {}).get(ledger.name, []))
        pending = result.get('UnprocessedKeys', {})
        if not pending:
            return found
        time.sleep(0.05 * 2 ** attempt)
    raise ClientError({'Error': {'Code': 'ProvisionedThroughputExceededException'}}, 'BatchGetItem')


def collect(body, country, namespace, table, ledger, client, now=None):
    now = int(time.time()) if now is None else now
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"))
    fingerprint = digest(canonical)
    receipt_key = {"pk": namespace + "#B#" + body["batch_id"]}
    expires = now + 120 * 86400
    # A manifest fixes the payload and country across resumable transactions.
    # It contains no raw payload or weekly token. Old atomic receipts are final.
    for attempt in range(4):
        receipt = ledger.get_item(Key=receipt_key, ConsistentRead=True).get("Item")
        if receipt:
            if receipt["fingerprint"] != fingerprint:
                return response(409, {"error": "batch_conflict"})
            if receipt.get('status', 'complete') == 'complete':
                return response(200, {"accepted": body["batch_id"], "duplicate": True})
            country = receipt['country']
            break
        try:
            ledger.put_item(Item={**receipt_key, 'fingerprint': fingerprint,
                'status': 'processing', 'country': country, 'expires': expires},
                ConditionExpression='attribute_not_exists(pk)')
            break
        except ClientError as exc:
            if exc.response['Error']['Code'] != 'ConditionalCheckFailedException':
                raise
    else:
        return response(503, {'error': 'retry_later'})
    cells = cells_for(body, country, namespace)
    aggregate_expires = int(dt.datetime.combine(dt.date.fromisoformat(body['week']),
        dt.time(), tzinfo=dt.timezone.utc).timestamp()) + 400 * 86400
    for start in range(0, len(cells), 40):
        chunk = cells[start:start + 40]
        chunk_key = {'pk': namespace + '#C#' + body['batch_id'] + '#' + str(start // 40)}
        for attempt in range(4):
            if ledger.get_item(Key=chunk_key, ConsistentRead=True).get('Item'):
                break
            keys = [{'pk': namespace + '#D#' + digest(body['token'] + c['pk'] + c['sk'])} for c in chunk]
            existing = distinct_keys(client, ledger, keys)
            tx = [{'Put': {'TableName': ledger.name, 'Item': encode({**chunk_key, 'expires': expires}),
                'ConditionExpression': 'attribute_not_exists(pk)'}}]
            for cell, key in zip(chunk, keys):
                distinct = key['pk'] in existing
                if not distinct:
                    tx.append({'Put': {'TableName': ledger.name, 'Item': encode({**key, 'expires': expires}),
                        'ConditionExpression': 'attribute_not_exists(pk)'}})
                tx.append({'Update': {'TableName': table.name, 'Key': encode({k: cell[k] for k in ('pk', 'sk')}),
                    'UpdateExpression': 'SET #d = :d, #e = :e ADD #c :c, #t :t, #u :u',
                    'ExpressionAttributeNames': {'#d': 'dimensions', '#e': 'expires', '#c': 'count', '#t': 'total', '#u': 'contributors'},
                    'ExpressionAttributeValues': encode({':d': cell['dimensions'], ':e': aggregate_expires,
                        ':c': cell['count'], ':t': cell['total'], ':u': 0 if distinct else 1})}})
            try:
                client.transact_write_items(TransactItems=tx)
                break
            except ClientError as exc:
                if exc.response['Error']['Code'] != 'TransactionCanceledException':
                    raise
        else:
            return response(503, {'error': 'retry_later'})
    ledger.update_item(Key=receipt_key, UpdateExpression='SET #s = :s',
        ExpressionAttributeNames={'#s': 'status'}, ExpressionAttributeValues={':s': 'complete'})
    return response(200, {'accepted': body['batch_id'], 'duplicate': False})


def handler(event, context):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    if not hmac.compare_digest(headers.get("x-origin-verify", ""), os.environ["ORIGIN_SECRET"]):
        return response(403, {"error": "forbidden"})
    route = event.get("routeKey")
    if route == "POST /v1/error-reports":
        from error_reports import submit
        return submit(event)
    if route == "GET /v1/health":
        return response(200, {"schema": 1, "status": "ok"})
    if route == "GET /privacy-policy":
        try:
            html = boto3.client('s3').get_object(Bucket=os.environ['BUCKET'], Key='public/privacy-policy.html')['Body'].read().decode()
            return {'statusCode': 200, 'headers': {'content-type': 'text/html; charset=utf-8',
                'cache-control': 'public, max-age=3600', 'x-content-type-options': 'nosniff'}, 'body': html}
        except ClientError:
            return response(503, {'error': 'policy_unavailable'})
    if route == "GET /v1/trends":
        # Serve a precomputed, suppressed public summary. Never expose the
        # database or permit arbitrary filtering of small cells.
        try:
            data = boto3.client("s3").get_object(Bucket=os.environ["BUCKET"], Key="public/trends.json")["Body"].read()
            result = response(200, json.loads(data))
        except ClientError as exc:
            if exc.response["Error"]["Code"] != "NoSuchKey":
                raise
            result = response(200, {"schema": 1, "weeks": [], "minimum_contributors": 20})
        result["headers"]["cache-control"] = "public, max-age=86400"
        return result
    if route != "POST /v1/batches":
        return response(404, {"error": "not_found"})
    namespace = "prod"
    if "x-analytics-test" in headers:
        if not hmac.compare_digest(headers["x-analytics-test"], os.environ["TEST_SECRET"]):
            return response(403, {"error": "forbidden"})
        namespace = "e2e"
    try:
        raw = event.get("body") or ""
        if len(raw) > 180000:
            return response(413, {"error": "too_large"})
        raw = base64.b64decode(raw, validate=True) if event.get("isBase64Encoded") else raw.encode()
        if len(raw) > 128000:
            return response(413, {"error": "too_large"})
        body = validate(json.loads(raw), dt.datetime.now(dt.timezone.utc).date())
    except (ValueError, TypeError, KeyError, UnicodeError):
        return response(400, {"error": "invalid_batch"})
    country = headers.get("cloudfront-viewer-country", "ZZ")
    if not re.fullmatch(r"[A-Z]{2}", country):
        country = "ZZ"
    db = boto3.resource("dynamodb")
    try:
        return collect(body, country, namespace, db.Table(os.environ["AGGREGATES"]),
                       db.Table(os.environ["LEDGER"]), boto3.client("dynamodb"))
    except ClientError as exc:
        # Operational metric is safe; exception details can contain payloads.
        print('analytics_storage_failure', exc.response['Error']['Code'])
        return response(503, {"error": "retry_later"})


def export_handler(event, context):
    """IAM/schedule-only: weekly JSONL snapshots for Athena; public safe cells."""
    namespace = "e2e" if event.get("namespace") == "e2e" else "prod"
    table = boto3.resource("dynamodb").Table(os.environ["AGGREGATES"])
    s3 = boto3.client("s3")
    glue = boto3.client("glue")
    today = dt.datetime.now(dt.timezone.utc).date()
    monday = today - dt.timedelta(days=today.weekday())
    from reporting import public_report, admin_report, compile_admin_week, safe_public_rows
    reporting_weeks = {}
    admin_weeks = {}
    exported = 0
    # Expire report snapshots by reporting week, not last daily rewrite time.
    for page in s3.get_paginator('list_objects_v2').paginate(Bucket=os.environ['BUCKET'], Prefix='reports/' + namespace + '/'):
        expired = []
        for obj in page.get('Contents', []):
            match = re.search(r'/week=(\d{4}-\d{2}-\d{2})/', obj['Key'])
            if match and (today - dt.date.fromisoformat(match[1])).days >= 400:
                expired.append({'Key': obj['Key']})
        if expired:
            s3.delete_objects(Bucket=os.environ['BUCKET'], Delete={'Objects': expired})
    for offset in range(58):
        week = str(monday - dt.timedelta(weeks=offset))
        args = {"KeyConditionExpression": "pk = :p", "ExpressionAttributeValues": {":p": namespace + "#W#" + week}, "ConsistentRead": True}
        rows = []
        while True:
            page = table.query(**args)
            for item in page["Items"]:
                if int(item["expires"]) <= int(time.time()):
                    continue
                row = {**{k: int(v) if isinstance(v, Decimal) else v for k, v in item["dimensions"].items()},
                       **{k: int(item[k]) for k in ("count", "total", "contributors")}}
                if offset <= 8 and row.get('view'):
                    reporting_weeks.setdefault(week, []).append(row)
                if not row.get('view'):
                    rows.append(row)
            if "LastEvaluatedKey" not in page:
                break
            args["ExclusiveStartKey"] = page["LastEvaluatedKey"]
        if offset <= 8:
            admin_weeks[week] = compile_admin_week(rows)
            reporting_weeks[week] = safe_public_rows(reporting_weeks.get(week, []))
        if not rows:
            continue
        key = "reports/" + namespace + "/week=" + week + "/metrics.jsonl"
        s3.put_object(Bucket=os.environ["BUCKET"], Key=key,
            Body="\n".join(json.dumps(row) for row in rows).encode(), ContentType="application/x-ndjson")
        exported += len(rows)
        if namespace == "prod":
            descriptor = json.loads(os.environ["GLUE_DESCRIPTOR"])
            descriptor["Location"] = "s3://" + os.environ["BUCKET"] + "/reports/prod/week=" + week + "/"
            partitions = glue.batch_create_partition(DatabaseName=os.environ["GLUE_DATABASE"], TableName="metrics", PartitionInputList=[{
                "Values": [week], "StorageDescriptor": descriptor}])
            for error in partitions.get('Errors', []):
                if error.get('ErrorDetail', {}).get('ErrorCode') != 'AlreadyExistsException':
                    raise RuntimeError('analytics_partition_registration_failed')
    if namespace == "prod" or event.get('preview') is True:
        generated = dt.datetime.now(dt.timezone.utc).isoformat()
        prefix = '' if namespace == 'prod' else 'reports/e2e/preview/'
        for key, report in [(prefix + 'public/trends.json', public_report(reporting_weeks, monday, generated)),
                            (prefix + 'admin/overview.json', admin_report(admin_weeks, monday, generated, compiled=True))]:
            s3.put_object(Bucket=os.environ['BUCKET'], Key=key, ContentType='application/json',
                Body=json.dumps(report, separators=(',', ':')).encode())
    return {"namespace": namespace, "exported_rows": exported}
