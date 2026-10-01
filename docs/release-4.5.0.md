# Deployment handoff: 4.5.0

Prepared September 25, 2026. The user confirmed that 4.4.0 is the last
published release; these notes cover only the changes since 4.4.0.
No store upload or production rollout has been performed.

## Release identity

- Version: 4.5.0
- Android version code / iOS build number: 40500
- Application ID: com.ionicframework.sdanewandoldhymnal816673
- Android upload bundle: /Users/frazras/Dev/sdahymnal/build/app/outputs/bundle/release/app-release.aab
- Store notes: /Users/frazras/Dev/sdahymnal/android/fastlane/metadata/android/en-US/changelogs/40500.txt

## Images

Existing, visually checked feature graphic (1024 × 500):
/Users/frazras/Dev/sdahymnal/assets/play_store/feature-graphic-1024x500.png

Existing app icon:
/Users/frazras/Dev/sdahymnal/assets/icon.png

These are existing branding images, not new screenshots of the musical-style controls.

## Play Store notes

Enjoy Jamaican Gospel with a 15% faster, synchronized rhythm.
Change musical style and toggle Choir Practice from the hymn menu.
Scroll through all styles, with Caribbean choices grouped together.
Adjust drum-kit volume and solo controls for all four backing styles.
Preview musical-style instruments with Amazing Grace in reorganized Settings.
Find hymns faster with improved title and lyric search.
Refreshed favorite feedback and end-of-hymn reminders.

## Verification

- Full Flutter suite: 380 passed.
- Flutter analysis: no issues.
- Python soundfont and icon tests: 14 passed; compatible soundfont check passed.
- Android release build succeeded; embedded manifest confirms 4.5.0 / 40500 and the expected application ID.
- Bundle ZIP integrity passed; JAR signature verified with the release signer Rohan Smith / Exterbox (not Android Debug).
- Signing certificate SHA-256: 77:7F:AD:B1:FE:41:BB:F1:14:C6:D2:BD:EB:9D:2B:E5:FB:13:87:96:FB:7F:B3:54:5E:1E:FC:E6:DB:77:40:79.
- Jarsigner reports the existing self-signed certificate chain and missing timestamp; the signature verifies. Certificate expiry: June 8, 2043.
- Bundle size: 63,372,220 bytes.
- Bundle SHA-256: 9b0e3d3bd355a6b4a4e7b44d202729fd9961e1e296232451f942e77f1882e40c.
- Minimum Android SDK: 24; target SDK: 36.
- This Android bundle has not been tested on a physical Android device.
- iOS release build 4.5.0 / 40500 passed bundle identity, soundbank and code-signing checks; installed in place and launched on the connected iPhone 11 Pro.
- Xcode 27 required a temporary local build override of IPHONEOS_DEPLOYMENT_TARGET=15.0; project deployment settings were not changed.
- No App Store archive / IPA was prepared.

The Jamaican Gospel arrangement retains the original synchronized groove at a
15% faster default tempo. The rejected 150% organ-density experiment is absent.
Source changes remain uncommitted. This preparation does not publish the app.
