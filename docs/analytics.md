# App analytics

The first-party collector is deployed by `analytics/deploy.py` using AWS profile
`frazras`, region `us-east-1`, CloudFormation stack `sdahymnal-analytics`.
The public URL is generated into `lib/services/analytics_endpoint.dart`.
No credentials are compiled into the production app.

## Collection and user choice

`Settings > Privacy & Statistics > Share usage statistics` is on by default
when there is no saved choice. A saved opt-out is preserved on restart and
upgrade. First initialization (or re-enabling) schedules the first upload seven days later,
plus up to six hours of jitter. There is no new operating-system permission,
location permission, ATT prompt, account, advertising SDK, or personalization.
Turning it off clears local analytics and cancels a request where possible;
already committed aggregate contributions cannot be individually reversed.

The schema in `analytics/schema.json` is the allowlist for both the Dart and
Python implementations. Unknown fields and values are rejected by the server.
Search text, raw exceptions, IPs, device fingerprints, screenshots, and playback
recordings are not analytics fields. MIDI errors are normalized; these counters
do not replace a full native crash reporter and do not guarantee capture of
fatal crashes or OS kills.

## Data flow

1. UI and playback instrumentation record counters and duration totals through
   `AppAnalytics`. Failures in analytics must not prevent normal app use.
2. SQLite stores bounded counters, local history, per-week random contributor
   tokens, and an immutable outbox. Android `noBackupFilesDir` and iOS backup
   exclusion prevent database identifiers being copied by normal device backups.
3. When due and foregrounded, the app seals up to 40 distinct measurement cells
   per request. Large dumps use several requests. The weekly upload session
   sends at most 20 batches per opportunity; a larger backlog continues later.
4. CloudFront supplies `CloudFront-Viewer-Country`, authenticates the origin
   request with a private origin header, and forwards to API Gateway HTTP API
   and Lambda. Direct API access cannot bypass the origin check. IP geolocation
   describes the upload connection, not historical offline activity locations.
5. Lambda aggregates each accepted batch into DynamoDB. A manifest fixes its
   payload hash and upload country. Each chunk of at most 40 aggregate cells
   commits atomically with its receipt and distinct-contributor markers. An
   interrupted batch resumes from uncommitted chunks; acknowledgement follows
   all chunks. Identical retries do not increment counters; changed contents
   using the same ID return HTTP 409. Legacy atomic receipts remain valid.
6. The daily export Lambda publishes weekly aggregate JSONL snapshots to a
   private S3 bucket, registers Glue partitions for Athena, and creates a public
   Statistics document and a private administrator snapshot. It compacts each
   week's developer totals before moving to the next week, retaining complete
   hymn totals until final period ranking. It does not export tokens or receipts.

No raw incoming batches are retained remotely. Receipts contain payload hashes
and opaque per-cell deduplication hashes, not contributor tokens. Tokens rotate
each reporting week. Reinstallation/reset creates a new identity; this system
counts participating app installations rather than people or lifetime devices.

## Measurement semantics

- `count` counts actions/samples. `total` is the sum of the measurement: seconds
  for `_seconds` metrics and milliseconds for `_ms` metrics. Divide total by
  count for a mean; these sums alone do not provide percentiles.
- Foreground time estimates how long the app or reader is visible, not attention
  or proof of reading. Background time is excluded and delayed ticks are capped.
- `contributors` counts distinct weekly tokens **within that exact cell**. Do
  not sum contributors across countries, variants, time buckets, versions, or
  weeks and label the result unique people or unique monthly installations.
- A cell includes week, weekday, broad time, app version, platform, design,
  country, metric, variant, and optional hymn edition/number. Week and weekday
  are based on the device's local calendar. Incorrect device clocks can cause
  data to be rejected or attributed incorrectly.
- Favorites currently measure additions/removals after enabling statistics,
  not a census of users' complete saved favorite lists.
- `hymn_repeat` counts every additional open of the same `(edition, hymn)`
  on one installation during its local calendar week. A bounded local
  `hymns_seen` table survives restarts and is cleared on opt-out. SQLite v2
  seeds it from retained v1 history when upgrading. This measures returns to
  the reader, not repeat playback, unique people, or complete performances.
- Search results are debounced; abandonment is a search left without selecting
  a result, not evidence of dissatisfaction. Taps and manual scroll corrections
  are similarly signals to investigate rather than proof of a usability fault.
- Offline uploads and users opting out bias coverage. Users who never
  upload or uninstall before the first upload are missing from reports.
- Long-term per-installation retention analysis and individual event journeys
  are deliberately unavailable because contributor tokens rotate weekly.

## Storage, retention, and costs

This is serverless throughout: no EC2 instance, continuously running SQL
database, or NAT gateway. Billing follows requests, stored data, exports and
queries, plus the small CloudWatch alarm charge. It is inexpensive at modest
traffic, not a guaranteed free service. As a baseline, 1,000 participating
installations sending 200 new cells each week need approximately 3.5 million
transactional write units/month (aggregate plus deduplication receipt, assuming
items below 1 KB). At $0.625/million this is about $2.20 for **writes alone**;
reads, storage, other services, retries and tax are additional. **That baseline
counts fine cells only.** The Statistics expansion adds up to four coarse
cells per hymn-open cell and one per repeat/favorite cell, plus chunk/manifest
receipts. Coarse cells merge within a batch and reuse weekly distinct markers.
Budget according to the actual event mix; the earlier $2.20 write estimate is
not an estimate for the expanded system. Amplify static hosting, Cognito admin
sign-ins and the admin HTTP API add usage-based charges subject to AWS allowances.
There is still no continuously running server or relational database. This is a
workload estimate, not a bill or cap. Rates checked 6 September 2026 against
[AWS DynamoDB pricing](https://aws.amazon.com/dynamodb/pricing/).

- SQLite: at most 10,000 counter cells, 10,000 local-history cells, and 500
  pending batches. Oldest records are dropped at the limits. Old reporting
  weeks are pruned before upload; retained offline history is approximately
  three months. These are analytics limits, independent of favorites/recents.
- DynamoDB Standard on-demand: receipt TTL 120 days from acceptance; aggregate
  TTL 400 days from the reporting week's start. Receipts outlive the maximum
  accepted event age (90 days), preventing old retries from being counted again
  after receipts expire. TTL cleanup is asynchronous.
- S3: private, encrypted, report snapshots purged by reporting-week age after
  400 days. A 400-day object lifecycle is also a fallback. Query results expire
  after seven days; Lambda logs have seven-day retention. No API/CloudFront
  request access logging is enabled, and Lambda never logs request bodies.
- Athena workgroup `sdahymnal-analytics`: on-demand, with a 100 MB scan limit per
  query. Partition filters keep queries small; scan limits are not cost caps.
- API route throttling: 5 requests/second, burst 10. Collector reserved
  concurrency 3; exporter 1. DynamoDB maximum throughput 100 read/200 write
  request units per table. These bounds reduce workload spikes but do not set
  a hard account spending cap.
- Lambda error/throttle alarms are visible in CloudWatch. No email/SNS
  subscriber or billing notification recipient is configured by this deployment.
  Add a budget notification destination through the AWS account if desired.

## Public Trends API

`GET /v1/trends` returns a daily prepared snapshot, cached for up to one day.
Schema 2 has fixed `periods` keys `1`, `4`, and `8`, each with dates, top hymns,
repeat hymns, favorite additions, weekdays, time buckets, and country hymn lists.
Only completed reporting weeks from the last eight weeks are eligible.
Separate coarse counters deduplicate the weekly token across finer dimensions;
public weekly groups require at least 20 contributors. Small country/time/day
partitions also cause an additional eligible cell to be withheld to reduce
subtraction disclosure. Period counts sum only published weekly cells, so they
are partial activity totals. Rankings are bounded to 20 hymns globally and
10 per country (the app shows the leading 10). There is no arbitrary query/filter endpoint,
device lookup, private error data, or individualized response. A threshold of
20 is a suppression rule, not a mathematical anonymity guarantee.

`Settings > Privacy & Statistics > Community statistics` opens the dedicated
page. The same report is available whether sharing is enabled or disabled.
Reports are cached locally for 24 hours; failed refreshes use the saved report
with an offline notice. Missing groups are labeled as insufficient data, not
zero usage. Hymn rows open their matching edition in the reader. Time-of-day
charts use device-local six-hour buckets; country describes the upload network.
New coarse and repeat measurements are not reconstructed from older fine
aggregates because their distinct contributor counts cannot be recovered.

## Private Amplify dashboard

The dashboard is at [main.d2n9mm2g6ftyy5.amplifyapp.com](https://main.d2n9mm2g6ftyy5.amplifyapp.com).
Deploy it with `python3 analytics/admin_deploy.py --profile frazras`.
CloudFormation stack `sdahymnal-analytics-admin` owns Amplify hosting, a Cognito
pool/client/admins group, and a separate HTTP API + report Lambda. Static page
source/configuration is public; the report requires a valid Cognito **access**
token, API scope, and `admins` group membership. Signup is disabled. Only the
report Lambda can read `admin/overview.json`; S3 remains private.

Sign in as `frazras` using the initial details in the ignored, mode-0600 file
`build/analytics/admin-credentials.json`. Cognito requires choosing a new password
on first sign-in; the temporary password expires after seven days. No invitation
email was sent. Subsequent deployments preserve the existing account/password.
The account uses simple password authentication; Cognito pool MFA is currently
off. Recover an expired or lost admin password through an authorized AWS
administrator, since self-service account recovery is disabled.

The browser uses authorization code + PKCE and validates the callback state.
Access tokens remain in page memory; a reload requires sign-in through the
Cognito session again. Sign-out clears the page state and Cognito login session.
The report API has 2 requests/second throttling, burst 5, and reserved Lambda
concurrency 2. There are no public report query parameters to reach private data.

Reports include the incomplete current week and 1/4/8 completed weeks, filtered
by all platforms, Android, or iOS. Cards cover opens, sessions, reading time,
returns, favorites, screen usage, entry points, search outcomes, music reliability,
country/day/time, setting choices, and version-specific counts. Error/attempt
ratios are event ratios rather than per-user failure rates. Raw event journeys,
user profiles and native crash stack traces are deliberately unavailable.

Lambda code is packaged in the private retained bucket owned by
`sdahymnal-analytics-artifacts`, with content-addressed ZIP files for reproducible
deployments and rollback. Both application stacks use this artifact package.

## Deployment and operations

```sh
python3 -m unittest discover -s analytics/tests -v
python3 analytics/deploy.py --profile frazras
flutter test
python3 analytics/admin_deploy.py --profile frazras
```

Deployment requires Python `boto3` and AWS credentials in the selected profile.
Generated deployment state, including origin/test secrets, is stored with mode
0600 under ignored `build/analytics/deployment.json`. Protect that file; if it is
lost, retrieve existing secrets securely from the stack parameters/configuration
or explicitly rotate them on a subsequent deployment. Never commit it or copy
the test token into app production configuration. Database and report resources
are retained on deletion of a successfully deployed stack to avoid accidental
data loss. Failed initial deployments use `RetainExceptOnCreate`.

The collector is public to installations. Its origin secret prevents origin
bypass, **not fabricated submissions from a modified client**. Do not treat
these metrics as fraud-proof or use them for financial decisions. Throttling,
strict schemas, limited payloads, and isolated QA traffic reduce exposure.

## End-to-end verification

The host harness uses the exact SQLite queue and HTTP transport used by the app,
simulates offline use, closes/reopens the database, submits to AWS, retries the
batch, and exercises conflict/schema rejection. It authenticates a separate
`e2e` namespace so test data never enters production Trends or Athena data.

Use Flutter's bundled Dart SDK (the system `dart` may be a different version):

```sh
# Replace this path with the Dart SDK in your Flutter installation.
/opt/homebrew/Caskroom/flutter/3.44.8/flutter/bin/cache/dart-sdk/bin/dart run tool/analytics_e2e.dart
python3 analytics/verify_e2e.py
```

The verification report is written to `build/analytics/e2e-submission.json` and
contains no secrets or contributor token. `integration_test/analytics_submission_test.dart`
additionally exercises the native app Settings switch, hymn opening, native
no-backup directory, SQLite plugin, and live submission on an iOS/Android device.
Supply `ANALYTICS_TEST_TOKEN` and an isolated test app version via an ignored
`--dart-define-from-file` file in a debug test build. Test overrides are rejected
by the facade in release builds. The native test also checks that a fresh
installation starts with sharing enabled and that disabling clears counters,
queued batches and reporting identifiers. After a successful iOS run saved to
`build/analytics/ios-integration.log`, run `python3 analytics/verify_native.py`
to check its DynamoDB contribution. Flutter may uninstall the test app during
teardown, so local database cleanup assertions run inside the native test.
The native test also opens the real Statistics page while sharing is off.

`python3 analytics/verify_community.py` sends 20 isolated QA contributors and
reconciles open/repeat/favorite totals with coarse DynamoDB counters and a
Lambda-generated public preview under `reports/e2e/preview/`. Production
snapshots remain unchanged. `python3 analytics/verify_admin.py` checks real
Cognito/API authorization and creates a suppressed QA administrator for
`analytics/browser_verify.mjs`. Run that browser check with Playwright (and
`CHROME_CHANNEL=chrome` when using installed Chrome), then remove the QA Cognito
account named in ignored `admin-browser-qa.json`. Never share QA credentials.

## Developer queries

Use Athena database `sdahymnal_analytics`, table `metrics`, workgroup
`sdahymnal-analytics`. Exports update daily and contain only production aggregates.
`analytics/queries.sql` contains ready-to-run queries for feature popularity,
hymns by country/day/time, favorite additions, search friction, and reliability.

```sql
SELECT metric, platform, version, sum(count) AS actions,
       sum(total) AS total_measurement
FROM metrics
WHERE week = '2026-08-31'
GROUP BY metric, platform, version;
```

Quote reserved column names when needed (for example `"time"`). Select relevant
partitions. A hymn is identified by `(edition, hymn)`, not number alone.

## Why custom analytics here

This implementation prioritizes local aggregation, weekly uploads, control of
retention and a server dataset with no installation activity histories. It
provides developer SQL reports, the Statistics page and a private visual
dashboard. It does not provide individual event journeys or a full native
crash reporter.

[Google Analytics for Firebase](https://firebase.google.com/docs/analytics)
would be the simpler option if ready-made analytics dashboards and audience
analysis became the priority: its analytics reporting is available at no cost
and it has an official Flutter SDK. Its SDK uses an app-instance identifier;
see [Google's collection description](https://support.google.com/firebase/answer/6318039?hl=en).
Using Firebase solely for analytics can be configured without personalization,
but it would require a fresh review of identifiers, SDK collection settings,
retention and disclosures. We have not added it alongside this collector, since
that would duplicate collection and introduce a second data processor.

## Release requirements

The updated policy is published at
https://dx289srf77tpf.cloudfront.net/privacy-policy and linked inside the app.
The deployment uploads `docs/privacy-policy.html`; the older GitHub Pages copy
will update when this repository change is published there. Set the live policy
URL and update Google Play Data Safety / Apple App Privacy answers before
distributing an analytics-enabled app release. Disclose usage
interactions, diagnostics, approximate IP-derived location, and random reporting
identifiers as appropriate. The existing YouTube embed must also be reflected
in store disclosures independently of optional first-party analytics. This task
does not upload a store release or change store-console answers.

Reference: [Apple's tracking definition](https://developer.apple.com/app-store/user-privacy-and-data-use/)
distinguishes first-party analytics from tracking across other companies' apps
for advertising. [Google Play's Data Safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
explicitly includes IP-inferred location. No OS permission prompt does not mean
the collection is exempt from privacy disclosures.
