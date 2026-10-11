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
