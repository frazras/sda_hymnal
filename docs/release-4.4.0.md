# Deployment handoff: 4.4.0

Prepared September 18, 2026. Android upload artifact is ready; no store upload or
production rollout has been performed. No iOS store archive was prepared.

## Release identity

- Release name: 4.4.0 (40400)
- Version name: 4.4.0
- Android version code: 40400
- Application ID: com.ionicframework.sdanewandoldhymnal816673
- Minimum Android SDK: 24 (Android 7.0)
- Target/compile Android SDK: 36
- Artifact: build/app/outputs/bundle/release/app-release.aab
- Exact size: 63,163,529 bytes (63.2 MB)
- SHA-256: 678bcd6a35e1ef14c35ea6a40aa08f34faf86f91261177fa85777b29fac1144e

## Play Store text

Enable Choir Practice in Settings to rename, mute, or solo available vocal parts.
Choose instruments and adjust volume for individual choir tracks.
Customize ensemble instruments with volume, solo, and preview controls.
Browse 111 instruments by category, including Steelpan with rolls on sustained notes.
Choir Practice overrides the selected ensemble style. Optional music controls stay hidden until enabled.

This is 411 characters including line breaks and the trailing newline. The source
is android/fastlane/metadata/android/en-US/changelogs/40400.txt. In-app update
history and the project changelog were updated to match.

Notes describe changes since repository release 4.3.0. Live Play Console release
state was not verified; the repository still labels 4.3.0 unreleased. If 4.3.0
was never published, its readings, topics, stories, and statistics changes also
need to be included in the store release description.

## Verification

- Release app bundle build exited successfully.
- Embedded bundle manifest confirms package, version 4.4.0, and code 40400.
- ZIP integrity check passed.
- JAR signature verified. Signer: Rohan Smith / Exterbox, not Android Debug.
- Signing certificate SHA-256:
  77:7F:AD:B1:FE:41:BB:F1:14:C6:D2:BD:EB:9D:2B:E5:FB:13:87:96:FB:7F:B3:54:5E:1E:FC:E6:DB:77:40:79
- Signer certificate expires June 8, 2043. Jarsigner reports a self-signed
  certificate/untrusted chain and no timestamp; the artifact signature verifies.
- Flutter analysis: no issues.
- Python soundfont tests: 10 passed; icon tests: 4 passed; soundfont check passed.
- Full Flutter suite: 347 passed and one stale cache-version assertion failed.
  Updated that assertion for render version 27; all four cache tests then passed.
  No remaining known test failures.
- Git diff whitespace validation passed.

The first build overlapped Flutter tests and failed on a generated integration
test plugin reference. After tests completed, a standalone release rebuild
succeeded. The delivered artifact is from that successful rebuild.

## Playback changes and remaining limitation

Release preparation fixed zero ensemble volume leaving faint notes and Android
original-style playback bypassing volume-only adjustments. Render cache version
27 ensures updated audio is generated.

Steelpan rolls remain fixed at six strikes per second at normal playback speed.
They are not beat-synchronized. The reported uneven feel on Old Hymnal 12 is
therefore still present; the proposed tempo-aware change has not been included.
The latest Android bundle has not been exercised on a physical Android device.

Source changes remain uncommitted. Favorites/settings are not reset by this
release preparation.
