#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."
python3 -m unittest discover -s test -p 'test_ios_soundfont.py'
python3 -m unittest discover -s test -p 'test_app_icons.py'
python3 tool/prepare_ios_soundfont.py \
  ios/Runner/Resources/GeneralUser-GS.sf2 \
  ios/Runner/Resources/ios-compatible/GeneralUser-GS.sf2 --check
flutter analyze
flutter test --concurrency=1
