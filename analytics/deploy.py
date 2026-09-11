#!/usr/bin/env python3
"""Reproducible CloudFormation deployment; credentials stay in AWS profile.

python3 analytics/deploy.py --profile frazras
Secrets/state go only to ignored build/analytics/deployment.json (mode 0600).
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import time

import boto3
from botocore.exceptions import ClientError
from deployment import package_code

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "analytics/schema.json").read_text())


def ref(name):
    return {"Ref": name}


def attr(name, field):
    return {"Fn::GetAtt": [name, field]}


def sub(value):
    return {"Fn::Sub": value}


def template(code=None):
    source = (ROOT / "analytics/server/collector.py").read_text().replace("METRICS = {}  # SCHEMA", "METRICS = " + repr(SCHEMA["metrics"]))
    columns = [{"Name": n, "Type": "bigint" if n in ("hymn", "weekday", "count", "total", "contributors") else "string"}
        for n in ("metric", "variant", "hymn", "edition", "weekday", "time", "platform", "version", "design", "country", "count", "total", "contributors")]
    descriptor = {"Columns": columns, "InputFormat": "org.apache.hadoop.mapred.TextInputFormat",
        "OutputFormat": "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat",
        "SerdeInfo": {"SerializationLibrary": "org.openx.data.jsonserde.JsonSerDe"}}
    resources = {}
    for name, keys in (("Aggregates", ["pk", "sk"]), ("Ledger", ["pk"])):
        resources[name] = {"Type": "AWS::DynamoDB::Table", "DeletionPolicy": "RetainExceptOnCreate", "UpdateReplacePolicy": "Retain",
            "Properties": {"BillingMode": "PAY_PER_REQUEST", "AttributeDefinitions": [{"AttributeName": k, "AttributeType": "S"} for k in keys],
                "KeySchema": [{"AttributeName": k, "KeyType": "HASH" if k == "pk" else "RANGE"} for k in keys],
                "TimeToLiveSpecification": {"AttributeName": "expires", "Enabled": True},
                "SSESpecification": {"SSEEnabled": True},
                "OnDemandThroughput": {"MaxReadRequestUnits": 100, "MaxWriteRequestUnits": 200}}}
    resources["Reports"] = {"Type": "AWS::S3::Bucket", "DeletionPolicy": "RetainExceptOnCreate", "UpdateReplacePolicy": "Retain", "Properties": {
        "PublicAccessBlockConfiguration": {k: True for k in ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")},
        "BucketEncryption": {"ServerSideEncryptionConfiguration": [{"ServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]},
        "LifecycleConfiguration": {"Rules": [{"Id": "reports", "Prefix": "reports/", "Status": "Enabled", "ExpirationInDays": 400},
            {"Id": "queries", "Prefix": "queries/", "Status": "Enabled", "ExpirationInDays": 7}]}}}
    resources["ReportsPolicy"] = {"Type": "AWS::S3::BucketPolicy", "Properties": {"Bucket": ref("Reports"), "PolicyDocument": {
        "Version": "2012-10-17", "Statement": [{"Effect": "Deny", "Principal": "*", "Action": "s3:*",
            "Resource": [attr("Reports", "Arn"), sub("${Reports.Arn}/*")], "Condition": {"Bool": {"aws:SecureTransport": "false"}}}]}}}
    resources["Database"] = {"Type": "AWS::Glue::Database", "Properties": {"CatalogId": ref("AWS::AccountId"), "DatabaseInput": {"Name": "sdahymnal_analytics"}}}
    resources["MetricsTable"] = {"Type": "AWS::Glue::Table", "Properties": {"CatalogId": ref("AWS::AccountId"), "DatabaseName": ref("Database"), "TableInput": {
        "Name": "metrics", "TableType": "EXTERNAL_TABLE", "Parameters": {"classification": "json"},
        "PartitionKeys": [{"Name": "week", "Type": "string"}], "StorageDescriptor": {**descriptor, "Location": sub("s3://${Reports}/reports/prod/")}}}}
    resources["Workgroup"] = {"Type": "AWS::Athena::WorkGroup", "Properties": {"Name": "sdahymnal-analytics", "WorkGroupConfiguration": {
        "EnforceWorkGroupConfiguration": True, "BytesScannedCutoffPerQuery": 100000000,
        "ResultConfiguration": {"OutputLocation": sub("s3://${Reports}/queries/"), "EncryptionConfiguration": {"EncryptionOption": "SSE_S3"}}}}}
    for role, statements in (("CollectorRole", [
        {"Effect": "Allow", "Action": ["dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"], "Resource": [attr("Aggregates", "Arn"), attr("Ledger", "Arn")]},
        {"Effect": "Allow", "Action": ["s3:GetObject"], "Resource": sub("${Reports.Arn}/public/*")},
        {"Effect": "Allow", "Action": ["s3:ListBucket"], "Resource": attr("Reports", "Arn")}]),
        ("ExporterRole", [{"Effect": "Allow", "Action": ["dynamodb:Query"], "Resource": attr("Aggregates", "Arn")},
        {"Effect": "Allow", "Action": ["s3:PutObject", "s3:DeleteObject"], "Resource": [sub("${Reports.Arn}/reports/*"), sub("${Reports.Arn}/public/*"), sub("${Reports.Arn}/admin/*")]},
        {"Effect": "Allow", "Action": ["s3:ListBucket"], "Resource": attr("Reports", "Arn")},
        {"Effect": "Allow", "Action": ["glue:BatchCreatePartition"], "Resource": [sub("arn:${AWS::Partition}:glue:${AWS::Region}:${AWS::AccountId}:catalog"),
            sub("arn:${AWS::Partition}:glue:${AWS::Region}:${AWS::AccountId}:database/${Database}"), sub("arn:${AWS::Partition}:glue:${AWS::Region}:${AWS::AccountId}:table/${Database}/metrics")]}])):
        function = "Collector" if role == "CollectorRole" else "Exporter"
        statements.append({"Effect": "Allow", "Action": ["logs:CreateLogStream", "logs:PutLogEvents"],
            "Resource": sub("arn:${AWS::Partition}:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AWS::StackName}-" + function.lower() + ":*")})
        resources[role] = {"Type": "AWS::IAM::Role", "Properties": {"AssumeRolePolicyDocument": {"Version": "2012-10-17", "Statement": [
            {"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]},
            "Policies": [{"PolicyName": "analytics", "PolicyDocument": {"Version": "2012-10-17", "Statement": statements}}]}}
    env = {"AGGREGATES": ref("Aggregates"), "LEDGER": ref("Ledger"), "BUCKET": ref("Reports"),
        "ORIGIN_SECRET": ref("OriginSecret"), "TEST_SECRET": ref("TestSecret"), "GLUE_DATABASE": ref("Database"), "GLUE_DESCRIPTOR": json.dumps(descriptor)}
    for name, handler, timeout in (("Collector", "handler", 25), ("Exporter", "export_handler", 300)):
        resources[name + "Logs"] = {"Type": "AWS::Logs::LogGroup", "Properties": {"LogGroupName": sub("/aws/lambda/${AWS::StackName}-" + name.lower()), "RetentionInDays": 7}}
        resources[name] = {"Type": "AWS::Lambda::Function", "DependsOn": name + "Logs", "Properties": {"FunctionName": sub("${AWS::StackName}-" + name.lower()),
            "Runtime": "python3.13", "Handler": ("collector." if code else "index.") + handler, "Role": attr(name + "Role", "Arn"), "Code": code or {"ZipFile": source},
            "MemorySize": 512, "Timeout": timeout, "ReservedConcurrentExecutions": 3 if name == "Collector" else 1,
            "Environment": {"Variables": env}}}
    resources["Api"] = {"Type": "AWS::ApiGatewayV2::Api", "Properties": {"Name": "sdahymnal-analytics", "ProtocolType": "HTTP"}}
    resources["Integration"] = {"Type": "AWS::ApiGatewayV2::Integration", "Properties": {"ApiId": ref("Api"), "IntegrationType": "AWS_PROXY", "IntegrationUri": attr("Collector", "Arn"), "PayloadFormatVersion": "2.0"}}
    for name, route in (("Batches", "POST /v1/batches"), ("Trends", "GET /v1/trends"), ("Health", "GET /v1/health"), ("Privacy", "GET /privacy-policy")):
        resources[name + "Route"] = {"Type": "AWS::ApiGatewayV2::Route", "Properties": {"ApiId": ref("Api"), "RouteKey": route, "Target": sub("integrations/${Integration}")}}
    resources["Stage"] = {"Type": "AWS::ApiGatewayV2::Stage", "Properties": {"ApiId": ref("Api"), "StageName": "$default", "AutoDeploy": True,
        "DefaultRouteSettings": {"ThrottlingBurstLimit": 10, "ThrottlingRateLimit": 5}}}
    resources["InvokePermission"] = {"Type": "AWS::Lambda::Permission", "Properties": {"FunctionName": ref("Collector"), "Action": "lambda:InvokeFunction", "Principal": "apigateway.amazonaws.com", "SourceArn": sub("arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/*/*/v1/*")}}
    resources["PrivacyPermission"] = {"Type": "AWS::Lambda::Permission", "Properties": {"FunctionName": ref("Collector"), "Action": "lambda:InvokeFunction", "Principal": "apigateway.amazonaws.com", "SourceArn": sub("arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/*/GET/privacy-policy")}}
    resources["OriginPolicy"] = {"Type": "AWS::CloudFront::OriginRequestPolicy", "Properties": {"OriginRequestPolicyConfig": {
        "Name": sub("${AWS::StackName}-country"), "CookiesConfig": {"CookieBehavior": "none"}, "QueryStringsConfig": {"QueryStringBehavior": "none"},
        "HeadersConfig": {"HeaderBehavior": "whitelist", "Headers": ["CloudFront-Viewer-Country", "Content-Type", "X-Analytics-Test"]}}}}
    resources["NoCachePolicy"] = {"Type": "AWS::CloudFront::CachePolicy", "Properties": {"CachePolicyConfig": {"Name": sub("${AWS::StackName}-no-cache"), "DefaultTTL": 0, "MinTTL": 0, "MaxTTL": 0,
        "ParametersInCacheKeyAndForwardedToOrigin": {"EnableAcceptEncodingGzip": False, "CookiesConfig": {"CookieBehavior": "none"}, "HeadersConfig": {"HeaderBehavior": "none"}, "QueryStringsConfig": {"QueryStringBehavior": "none"}}}}}
    resources["TrendsCachePolicy"] = {"Type": "AWS::CloudFront::CachePolicy", "Properties": {"CachePolicyConfig": {"Name": sub("${AWS::StackName}-trends-cache"), "DefaultTTL": 86400, "MinTTL": 0, "MaxTTL": 86400,
        "ParametersInCacheKeyAndForwardedToOrigin": {"EnableAcceptEncodingGzip": True, "CookiesConfig": {"CookieBehavior": "none"}, "HeadersConfig": {"HeaderBehavior": "none"}, "QueryStringsConfig": {"QueryStringBehavior": "none"}}}}}
    resources["Distribution"] = {"Type": "AWS::CloudFront::Distribution", "Properties": {"DistributionConfig": {"Enabled": True, "PriceClass": "PriceClass_100",
        "Origins": [{"Id": "api", "DomainName": sub("${Api}.execute-api.${AWS::Region}.amazonaws.com"), "CustomOriginConfig": {"OriginProtocolPolicy": "https-only", "OriginSSLProtocols": ["TLSv1.2"]},
            "OriginCustomHeaders": [{"HeaderName": "X-Origin-Verify", "HeaderValue": ref("OriginSecret") }]}],
        "DefaultCacheBehavior": {"TargetOriginId": "api", "ViewerProtocolPolicy": "https-only", "AllowedMethods": ["GET", "HEAD", "OPTIONS", "PUT", "PATCH", "POST", "DELETE"],
            "CachedMethods": ["GET", "HEAD"], "CachePolicyId": ref("NoCachePolicy"), "OriginRequestPolicyId": ref("OriginPolicy"), "Compress": True},
        "CacheBehaviors": [{"PathPattern": "/v1/trends", "TargetOriginId": "api", "ViewerProtocolPolicy": "https-only", "AllowedMethods": ["GET", "HEAD", "OPTIONS"],
            "CachedMethods": ["GET", "HEAD"], "CachePolicyId": ref("TrendsCachePolicy"), "OriginRequestPolicyId": ref("OriginPolicy"), "Compress": True}],
        "ViewerCertificate": {"CloudFrontDefaultCertificate": True}}}}
    resources["Schedule"] = {"Type": "AWS::Events::Rule", "Properties": {"ScheduleExpression": "rate(1 day)", "State": "ENABLED", "Targets": [{"Id": "export", "Arn": attr("Exporter", "Arn")}]}}
    resources["SchedulePermission"] = {"Type": "AWS::Lambda::Permission", "Properties": {"FunctionName": ref("Exporter"), "Action": "lambda:InvokeFunction", "Principal": "events.amazonaws.com", "SourceArn": attr("Schedule", "Arn")}}
    for name, function, metric in (("CollectorErrors", "Collector", "Errors"), ("CollectorThrottles", "Collector", "Throttles"), ("ExporterErrors", "Exporter", "Errors")):
        resources[name] = {"Type": "AWS::CloudWatch::Alarm", "Properties": {"Namespace": "AWS/Lambda", "MetricName": metric, "Dimensions": [{"Name": "FunctionName", "Value": ref(function)}],
            "Statistic": "Sum", "Period": 300, "EvaluationPeriods": 1, "Threshold": 1, "ComparisonOperator": "GreaterThanOrEqualToThreshold", "TreatMissingData": "notBreaching"}}
    return {"AWSTemplateFormatVersion": "2010-09-09", "Description": "SDA Hymnal aggregate-only analytics",
        "Parameters": {k: {"Type": "String", "NoEcho": True, "MinLength": 32} for k in ("OriginSecret", "TestSecret")}, "Resources": resources,
        "Outputs": {"Endpoint": {"Value": sub("https://${Distribution.DomainName}")}, **{k: {"Value": ref(k)} for k in ("Aggregates", "Ledger", "Reports", "Collector", "Exporter", "Workgroup", "Database", "Api", "Distribution")}}}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--profile", default="frazras")
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--schema-only", action="store_true")
    args = p.parse_args()
    (ROOT / "lib/services/analytics_schema.dart").write_text("// Generated from analytics/schema.json by analytics/deploy.py --schema-only.\nconst analyticsVariants = <String, List<String>> " + json.dumps(SCHEMA["metrics"], indent=2) + ";\n")
    if args.schema_only:
        return
    directory = ROOT / "build/analytics"
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "deployment.json"
    state = json.loads(path.read_text()) if path.exists() else {"OriginSecret": secrets.token_hex(32), "TestSecret": secrets.token_hex(32)}
    # Write secrets without an intermediate world-readable file.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(state, f)
    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    cfn = session.client("cloudformation")
    stack = "sdahymnal-analytics"
    body = json.dumps(template(package_code(session)))
    (directory / "template.json").write_text(body)
    kwargs = {"StackName": stack, "TemplateBody": body, "Capabilities": ["CAPABILITY_IAM"],
        "Parameters": [{"ParameterKey": k, "ParameterValue": state[k]} for k in ("OriginSecret", "TestSecret")]}
    try:
        cfn.describe_stacks(StackName=stack)
        try:
            cfn.update_stack(**kwargs)
        except ClientError as e:
            if "No updates are to be performed" not in str(e):
                raise
    except ClientError as e:
        if "does not exist" not in str(e):
            raise
        cfn.create_stack(**kwargs, Tags=[{"Key": "Project", "Value": "sdahymnal"}, {"Key": "Purpose", "Value": "analytics"}])
    last = None
    while True:
        result = cfn.describe_stacks(StackName=stack)["Stacks"][0]
        status = result["StackStatus"]
        if status != last:
            print(status, flush=True)
            last = status
        if status in ("CREATE_COMPLETE", "UPDATE_COMPLETE"):
            break
        if "IN_PROGRESS" not in status:
            events = cfn.describe_stack_events(StackName=stack)["StackEvents"]
            for event in events:
                if "FAILED" in event["ResourceStatus"]:
                    print(event["LogicalResourceId"], event.get("ResourceStatusReason", ""), flush=True)
            raise RuntimeError(status)
        time.sleep(10)
    state.update({o["OutputKey"]: o["OutputValue"] for o in result["Outputs"]})
    path.write_text(json.dumps(state, indent=2))
    boto3.Session(profile_name=args.profile, region_name=args.region).client('s3').put_object(
        Bucket=state['Reports'], Key='public/privacy-policy.html',
        Body=(ROOT / 'docs/privacy-policy.html').read_bytes(), ContentType='text/html; charset=utf-8')
    (ROOT / "lib/services/analytics_endpoint.dart").write_text("// Public collector URL; no credentials belong in the app.\nconst analyticsEndpoint = '" + state["Endpoint"] + "';\n")
    print("Deployed " + state["Endpoint"], flush=True)


if __name__ == "__main__":
    main()
