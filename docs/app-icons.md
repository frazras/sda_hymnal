# Home-screen icons follow the app design

Settings → App design controls both the interface and home-screen icon.

- **Modern is the default** for a fresh install or missing/invalid preference.
  It uses the existing primary icon and current interface.
- **Classic is opt-in** and uses the original green/black Old New SDA Hymnal
  artwork recovered from Git revision `6a860f7`.
- Returning to Modern restores the primary icon. Light/dark appearance and
  instrument selection are independent and do not change the icon.
- A saved Classic preference from before this feature is reconciled after
  launch. Resume retries a pending/mismatched icon. An already-matching icon
  is a native no-op, so ordinary launches do not show an icon-change alert.

The design is persisted before requesting the native icon change. Requests
are serialized and finish with the latest chosen design. Settings disables
the buttons during a change; if the OS refuses, the layout remains usable
and an explanatory message offers **Retry icon change**. This retries only
the icon and does not reset favorites, font size or other preferences.

## iPhone and iPad

`AppIcon` remains Xcode's primary icon. `ClassicIcon` is an alternate asset
set in Debug, Profile and Release. Xcode generates `CFBundleIcons` and iPad
metadata from those settings; do not manually replace the generated keys.

The native bridge uses UIKit's public `setAlternateIconName` API in the
foreground: `ClassicIcon` selects the old icon and `nil` restores Modern.
**iOS displays its standard icon-change notification.** It is not suppressed
using private APIs. See [Apple's configuration guide](https://developer.apple.com/documentation/xcode/configuring-your-app-to-use-alternate-app-icons).

Original icon sizes are recovered without redrawing or resizing. iOS PNGs
are composited onto their intended white background and encoded as RGB to
avoid transparent app icons; Android PNGs remain byte-identical to Git.
`node tool/restore_classic_icons.mjs --check` validates this derivation
(requires that revision in local Git history).

## Android

Two launcher aliases target an always-enabled `HymnalActivity`. The Modern
alias retains the existing `.MainActivity` component name to support upgrades
and existing shortcuts; `.ClassicIcon` is disabled by default. Do not rename
or remove either alias in a later release while devices may have it selected.

Android 13+ switches the two aliases atomically; earlier releases enable the
destination before disabling the old alias. Both use `DONT_KILL_APP`, and
the target activity is never disabled. Launchers may refresh with a delay
or move/recreate the shortcut; home-screen placement is launcher-controlled.
See [activity aliases](https://developer.android.com/guide/topics/manifest/activity-alias-element)
and [PackageManager's component-state API](https://developer.android.com/reference/android/content/pm/PackageManager#setComponentEnabledSettings(java.util.List)).

## Verification without a simulator

`test/app_icon_test.dart` checks default Modern, persistence before native
calls, migration of saved Classic, failures/retries, serialized requests and
unsupported host platforms. `test/app_design_test.dart` checks the Settings
retry affordance and startup/resume reconciliation in addition to existing
design, lyrics and playback checks. `test/test_app_icons.py` checks artwork,
opaque correctly-sized iOS assets, all Xcode configurations and Android's
single default launcher.

The simulator/emulator is intentionally not used for this feature, per the
owner's memory-usage preference. A physical-device check of Classic → Home →
Modern → Home is still recommended, including an app relaunch in each mode
and an Android update from the previous release. Release compilation and
packaged icon metadata are checked separately from runtime appearance.

Validation on 2026-08-28:

- Static analysis: no issues.
- Headless tests: 252 Flutter tests, 10 soundbank tests and 4 icon-packaging
  tests passed (266 total); Flutter tests ran with one worker.
- Original-artwork derivation check: all 28 files matched.
- Signed iOS release build passed; generated iPhone and iPad metadata
  contains `ClassicIcon` and retains `AppIcon` as the primary icon. Code-sign
  verification passed.
- Android release app bundle passed with a temporary 2 GB Gradle heap limit
  and two Gradle workers. The merged manifest retains Modern as the only
  enabled launcher alias; the bundle includes all five Classic icon densities
  and the native activity survives release optimization.
- Native icon appearance has not been tested on a device for this change.

This feature does not change the Play Store/App Store listing artwork.
