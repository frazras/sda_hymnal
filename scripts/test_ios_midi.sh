#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
cd "$repo_dir"
simulator_name="${1:-${IOS_SIMULATOR_NAME:-iPhone 16 Pro}}"

# Simulator-only lifecycle tests use a deterministic audio adapter and the
# real Flutter method channel. No physical-phone install or Dart VM discovery.
CONFIGURATION=debug ./scripts/build_ios.sh --simulator --config-only
result_dir="$(mktemp -d "${TMPDIR:-/tmp}/hymnal-midi-tests.XXXXXX")"
printf 'Native MIDI test results: %s/playback-controls.xcresult\n' "$result_dir"
xcodebuild test -quiet \
  -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$simulator_name" \
  -only-testing:RunnerTests/RunnerTests -parallel-testing-enabled NO \
  -derivedDataPath "$repo_dir/build/native_midi_tests" \
  -resultBundlePath "$result_dir/playback-controls.xcresult" \
  CODE_SIGNING_ALLOWED=NO FLUTTER_BUILD_MODE=debug
