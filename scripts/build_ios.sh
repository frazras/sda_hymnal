#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "$script_dir/.." && pwd)"
cd "$repo_dir"

python3 tool/prepare_ios_soundfont.py \
  ios/Runner/Resources/GeneralUser-GS.sf2 \
  ios/Runner/Resources/ios-compatible/GeneralUser-GS.sf2 --check

configuration="${CONFIGURATION:-release}"
case "$configuration" in
  debug|profile|release) ;;
  *) echo "CONFIGURATION must be debug, profile, or release" >&2; exit 2 ;;
esac

flutter pub get
flutter build ios "--$configuration" "$@"
