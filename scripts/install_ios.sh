#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
cd "$repo_dir"

device_id="${1:-${DEVICE_ID:-00008030-00016D1C3AA0802E}}"
if [[ $# -gt 0 ]]; then shift; fi
CONFIGURATION=release ./scripts/build_ios.sh

# The generic iphoneos path can retain a debug/test host after a successful
# release build. Install only the verified configuration-specific product.
release_app="$repo_dir/build/ios/Release-iphoneos/Runner.app"
expected_name="$(sed -n 's/^FLUTTER_BUILD_NAME=//p' ios/Flutter/Generated.xcconfig)"
expected_build="$(sed -n 's/^FLUTTER_BUILD_NUMBER=//p' ios/Flutter/Generated.xcconfig)"
actual_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$release_app/Info.plist")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$release_app/Info.plist")"
actual_bundle="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$release_app/Info.plist")"
if [[ -z "$expected_name" || -z "$expected_build" ||
      "$actual_name" != "$expected_name" || "$actual_build" != "$expected_build" ||
      "$actual_bundle" != "com.ionicframework.sdanewandoldhymnal816673" ||
      ! -f "$release_app/Frameworks/App.framework/App" ||
      -f "$release_app/Frameworks/App.framework/flutter_assets/kernel_blob.bin" ||
      -f "$release_app/Runner.debug.dylib" ]]; then
  echo "Refusing to install a stale, debug, or incorrect app." >&2
  exit 1
fi
cmp "$release_app/GeneralUser-GS.sf2" \
  ios/Runner/Resources/ios-compatible/GeneralUser-GS.sf2
codesign --verify --deep --strict "$release_app"

# Update in place. Never uninstall or reset the user's favorites/settings.
xcrun devicectl device install app --device "$device_id" "$release_app" "$@"
