#!/usr/bin/env python3
"""Run offline content publication gates without changing bundled assets."""
import argparse
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check(output):
    commands = [
        ['-m', 'unittest', 'discover', '-s', 'test', '-p', 'test_hymnal*.py'],
        ['-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_validate_translations.py'],
        ['tool/import_hymnals.py', '--check'],
        ['tool/import_structured_hymnals.py',
         'tool/data/structured_sources/chichewa.manifest.json',
         '--output', 'resources/hymnals/sda-ny-khristu-mu-nyimbo.json', '--check'],
        ['tool/validate_translations.py'],
        ['tool/build_language_download_catalog.py', '--check'],
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
