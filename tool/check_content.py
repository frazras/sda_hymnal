#!/usr/bin/env python3
"""Run offline content publication gates without changing bundled assets."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def optional_pack_checks(root=ROOT):
    """Regenerate every published optional pack from exactly one pinned manifest."""
    sources = json.loads((root / 'tool/data/language_download_sources.json').read_text())
    manifests = {}
    for path in sorted((root / 'tool/data/structured_sources').glob('*.manifest.json')):
        identity = json.loads(path.read_text())['book']['id']
        manifests.setdefault(identity, []).append(path.relative_to(root).as_posix())
    commands = []
    for asset in sources.get('optionalPacks', []):
        matches = manifests.get(Path(asset).stem, [])
        if len(matches) != 1:
            raise ValueError(f'Optional pack needs exactly one manifest: {asset}')
        commands.append(['tool/import_structured_hymnals.py', matches[0],
                         '--output', asset, '--check'])
    return commands


def check(output):
    commands = [
        ['-m', 'unittest', 'discover', '-s', 'test', '-p', 'test_hymnal*.py'],
        ['-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_*translation*.py'],
        ['tool/import_hymnals.py', '--check'],
        *optional_pack_checks(),
        ['tool/validate_translations.py'],
        ['tool/build_language_download_catalog.py', '--check'],
        ['tool/build_score_download_catalog.py', '--check'],
        ['tool/build_recording_catalog.py', '--check'],
        ['tool/validate_hymnal_content.py', '--output', str(output)],
    ]
    for command in commands:
        print('Checking: ' + ' '.join(command), flush=True)
        subprocess.run([sys.executable, *command], cwd=ROOT, check=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path,
                        help='Save the content coverage report at this path')
    args = parser.parse_args()
    try:
        if args.report:
            check(args.report.resolve())
        else:
            with tempfile.TemporaryDirectory(prefix='hymnal-content-') as directory:
                check(Path(directory) / 'report.json')
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode)
