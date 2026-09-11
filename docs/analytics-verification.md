# Analytics verification — 7 September 2026

The AWS backend is deployed using profile `frazras`, region `us-east-1`, stack
`sdahymnal-analytics`. CloudFormation reports `UPDATE_COMPLETE`; both DynamoDB
tables are active with `PAY_PER_REQUEST` billing.

- Collector: https://dx289srf77tpf.cloudfront.net/v1/batches
- Health: https://dx289srf77tpf.cloudfront.net/v1/health
- Public Trends: https://dx289srf77tpf.cloudfront.net/v1/trends
- Published policy: https://dx289srf77tpf.cloudfront.net/privacy-policy

## Final behavior

Statistics starts enabled when an installation has no saved choice. A saved
opt-out survives restarts and upgrades. The first upload waits seven days plus
up to six hours of jitter; subsequent weekly upload sessions run when the app
is foregrounded. Failed submissions remain queued with backoff. Native storage
uses Android's no-backup directory and iOS backup exclusion.

There are 47 allowlisted measurements covering feature use, reading, search,
music, auto-scroll, settings and categorized errors. Country is inferred from
the upload connection. Reporting identifiers rotate weekly; batch receipts
prevent duplicate submissions. No raw incoming batches or installation
activity histories are retained remotely.

## Executed checks

| Check | Result |
| --- | --- |
| Full Flutter suite after default-on change | 307 passed |
| Backend tests, including public suppression | 6 passed |
| Flutter analyzer | No issues |
| Android debug build | Passed; APK integrity checked |
| APK endpoint and secret check | Live endpoint present; origin/QA secrets absent |
| Native iOS integration, iPhone 16 Pro simulator / iOS 18.2 | Passed |
| Fresh native default and Settings switch | Default on confirmed; enable/disable exercised |
| Native UI to AWS submission | Hymn 1 opened through keypad, stored once with one contributor |
| Native opt-out cleanup | Counters, history, outbox and weekly identifiers empty; saved choice off |
| Real SQLite offline/restart recovery | Exact pending batch survived close/reopen and uploaded successfully |
| Duplicate, conflicting and invalid submissions | Duplicate acknowledged without increment; conflict 409; invalid fields 400 |
| DynamoDB and S3 reconciliation | Three host test rows matched expected counts/totals |
| Athena SQL reconciliation | Matched the actual exported test rows; query scanned 708 bytes |
| Developer report queries | All five executed successfully in Athena |
| Public isolation and origin protection | QA excluded from public Trends; direct API origin returned 403 |
| Published privacy policy | Served HTML exactly matched the updated repository policy |

The host upload resolved to country `JM`. QA submissions use a protected `e2e`
namespace and isolated numeric app versions. Production reports and public
Trends exclude that namespace. The native test permits up to three submissions
of its durable queue to accommodate transient network failures; database
verification still requires exactly one hymn opening.

Machine-readable results are in ignored `build/analytics/e2e-submission.json`
and `build/analytics/native-submission.json`. Test/build logs are also under
`build/analytics`. These reports contain no contributor token or credentials.
Deployment and QA secrets are in separate ignored files; do not distribute them.

## Statistics and admin dashboard verification — 8 September 2026

The Statistics page and private Amplify dashboard are implemented and deployed.
The app page presents the same report to every user, including users who opted
out, and caches the public snapshot for offline use. All tests use an isolated
analytics namespace or local browser fixtures; no synthetic production counts
were introduced.

| Check | Result |
| --- | --- |
| Flutter regression suite | 313 tests passed |
| Static analysis | No issues found |
| Backend tests | 11 passed, including interrupted multi-transaction batches, original-country retries, distinct coarse contributors, suppression, and period/platform totals |
| Native iPhone integration | Passed: live Statistics page while sharing is off, period selection, enable sharing, open hymn, submit, then clear all analytics tables including repeat tracking |
| Native database reconciliation | Exactly one hymn open, one contributor, and no framework/platform diagnostic errors |
| Android | Normal debug APK built successfully; archive integrity and absence of deployment/admin/QA credentials checked |
| App queue and live collector | Offline/restart recovery, duplicate acknowledgement, conflict 409, invalid schema 400 |
| DynamoDB, S3 and Athena | App-generated count and duration totals matched after retries |
| Community reporting | 20 isolated contributors reconciled open/repeat/favorite totals and the Lambda-generated public preview; production snapshot remained unaffected |
| Real Cognito/API authorization | Anonymous and invalid JWT requests rejected; non-admin account rejected; ID token rejected; admin access token accepted |
| Real browser flow | Hosted sign-in, PKCE callback, protected report, period/platform selection, mobile layout, and logout passed |
| Populated dashboard | Local synthetic report rendered all chart/table sections and verified the playback mean; no script/CSP errors or mobile overflow |
| Administrator credentials | Initial `frazras` credentials stored in ignored mode-0600 file; no invitation email; temporary QA administrator removed |
| Privacy policy | Live HTML matches the repository's 8 September policy |

The live administrator site is
[main.d2n9mm2g6ftyy5.amplifyapp.com](https://main.d2n9mm2g6ftyy5.amplifyapp.com).
Machine-readable checks and screenshots are under ignored `build/analytics/`:
`community-verification.json`, `admin-verification.json`,
`admin-browser-verification.json`, `admin-dashboard.png`, and
`admin-fixture-desktop.png` / `admin-fixture-mobile.png`. Fixture screenshots
are visibly labeled synthetic QA data. Production currently has no submitted
activity; public groups require 20 contributing installations within a week.

## Remaining release work

App source is implemented and native builds verified. No app-store release was
uploaded. Before distribution, update the Google Play Data Safety and Apple App
Privacy declarations and their privacy-policy URL. The older repository-hosted
privacy-policy copy still needs publication through the repository's normal
release workflow. No store release or store-console changes were made.

See [the operating guide](analytics.md) for deployment/reproduction instructions,
retention, cost assumptions and the Firebase comparison, and
[developer queries](../analytics/queries.sql) for reports.
