# Roadmap regression verification — 11 October 2026

The complete Flutter suite passes: **743 tests**, with full `flutter analyze`
reporting no issues. This includes the multilingual readers, search, interface
translations, playlists, playback, arrangements, and optional-pack foundations.
It is regression evidence, not completion of unchecked roadmap items.

The initial full run exposed six startup/design test failures: root app tests
used the filesystem-backed installed-book loader inside Flutter's fake async
clock. The root `Hymnal` now accepts the same pack-loader dependency already
supported by `Tabs`. Those tests inject the bundled loader; production retains
`loadInstalledLanguagePacks` as its default. Existing real-filesystem integration
tests continue to validate downloaded-book activation, removal, and fallback.
The focused startup/design run passes all 44 tests, followed by the complete run.

Commands:

```sh
flutter test test/widget_test.dart test/app_design_test.dart
flutter test
flutter analyze
```

Device installation and physical background-audio, share/browser, and browsing
validation remain pending while the connected iPhone requires its passcode.
Native book identities also remain unsupported by the deployed analytics schema;
foreign per-hymn measurements stay suppressed until the backend is extended.

## Native error reports

The collector and admin dashboard deployments completed on 11 October. The
published Lambda archive was downloaded and its error-report validator compared
byte-for-byte with the committed source. Legacy and native subject validation
pass locally (19 backend tests, four dashboard tests). App checks pass (81 tests)
and analysis reports no issues. Reports now carry canonical book identities;
analytics still uses the legacy schema and remains a separate pending item.
The release build succeeds; installation remains pending the phone unlock.

## Multilingual statistics verification

The complete Flutter regression run now passes 747 tests. Live isolated QA
checks cover native Spanish Old/New book separation, 20 contributor publication,
translated report titles, legacy English snapshots, and retry deduplication.
`flutter test tool/analytics_multilingual_e2e_test.dart` also verifies the real
app SQLite store and HTTPS transport, offline restart, mixed schema-2 batches,
and unknown-book rejection. The collector, exporter, API routes and dashboard
are deployed; foreign app counters remain gated until production export works.

Production export remains incomplete: the aggregate table contains 648,233
items, and scheduled exports repeatedly reach their 300-second limit. Recent
DynamoDB read-throttle metrics report zero; reducing query page size is verified
for completeness but is not yet proven to resolve the timeout. Export needs
bounded, resumable work rather than claiming deployment alone proves delivery.
The multilingual public snapshot is not yet present in production. This keeps
the native-analytics roadmap item unchecked.

### Resumable exporter follow-up

The exporter now checkpoints its week, page cursor, accumulated private rows,
compiled weekly reports, and revision in private S3 storage. It queues the next
execution before the deadline, rejects stale revisions/completed retries, and
refuses continuations that make no progress. Query pages are bounded at 500
records. Thirty-one backend tests pass, including mid-week pause/resume and
rollout fallback to the existing legacy public report.

The deployed production job returned a pending result after exporting 381,311
rows and successfully queuing revision 1. This proves continuation was accepted;
final snapshot publication remains under observation. Installed-book statistics
routing and native Russian song opening pass their widget tests. App analysis
reports no issues. Foreign app counters remain gated until production finishes.

### Production publication verified

The resumed production export completed with 569,213 fine rows. Both public
snapshots were written at 21:42:43 UTC on 11 October. The native API route now
has an exact GET /v2/trends invocation permission; a deployment regression test
covers that route and permission together. The delivered native snapshot matches
the stored completed snapshot, and the public legacy route retains English
aliases. All 32 backend tests pass. Native app counters are now enabled; ordinary
opt-out, weekly batching, and minimum 20-contributor publication remain intact.
Earlier notes about the pending snapshot/gate above describe the investigation
and have been superseded by this verified publication.

The full app regression suite passes 750 tests with native counters enabled.
The subsequent offline-upgrade fallback passes all nine focused statistics
tests. Canonical English repeat history and installed-book routing are covered.
