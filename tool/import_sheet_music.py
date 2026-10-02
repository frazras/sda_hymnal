#!/usr/bin/env python3
"""Import pinned English 1985 scores; --check verifies the bundled catalog offline."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import struct
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPO = 'GoGoShift/Hymnal-Flutter'
REVISION = '42e1263684ddd756841f11581611b9c9c6cc574f'
BOOK = 'sda-en-1985'
DEST = ROOT / 'assets/sheet_music/en_1985'
CATALOG = ROOT / 'assets/sheet_music/catalog.json'
PATTERN = re.compile(r'assets/musicSheets/piano_sheet_en_(\d{3})(?:_(\d+))?\.png$')


def read_url(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'SDAHymnal-content-import'})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def png_size(data):
    if len(data) < 24 or data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise ValueError('Expected a PNG image with an IHDR header')
    width, height = struct.unpack('>II', data[16:24])
    if not (0 < width <= 20000 and 0 < height <= 20000):
        raise ValueError('Invalid score dimensions')
    return width, height


def verify_blob(data, sha):
    digest = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if digest != sha:
        raise ValueError('Source blob checksum mismatch')


def import_scores():
    tree = json.loads(read_url(f'https://api.github.com/repos/{REPO}/git/trees/{REVISION}?recursive=1'))
    if tree.get('truncated'):
        raise ValueError('Incomplete source tree')
    selected = []
    for entry in tree['tree']:
        match = PATTERN.fullmatch(entry['path'])
        if entry['type'] == 'blob' and match:
            selected.append((int(match[1]), int(match[2] or 0), entry))
    selected.sort(key=lambda item: item[:2])
    if len(selected) != 723 or {n for n, _, _ in selected} != set(range(1, 696)):
        raise ValueError('Pinned source coverage changed unexpectedly')
    DEST.mkdir(parents=True, exist_ok=True)

    def download(item):
        number, page, entry = item
        destination = DEST / Path(entry['path']).name
        data = destination.read_bytes() if destination.exists() else None
        if data is not None:
            try:
                verify_blob(data, entry['sha'])
            except ValueError:
                data = None
        if data is None:
            data = read_url(f'https://raw.githubusercontent.com/{REPO}/{REVISION}/{entry["path"]}')
        verify_blob(data, entry['sha'])
        width, height = png_size(data)
        staged = destination.with_suffix('.tmp')
        staged.write_bytes(data)
        staged.replace(destination)
        return number, page, {
            'asset': destination.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(data).hexdigest(),
            'width': width, 'height': height, 'bytes': len(data),
        }

    with ThreadPoolExecutor(max_workers=8) as pool:
        pages = list(pool.map(download, selected))
    hymns = {}
    for number, page, record in pages:
        group = hymns.setdefault(str(number), [])
        if page != len(group):
            raise ValueError(f'Nonconsecutive score pages for hymn {number}')
        group.append(record)
    catalog = {
        'schemaVersion': 1,
        'source': {'repository': REPO, 'revision': REVISION,
                   'url': f'https://github.com/{REPO}/tree/{REVISION}/assets/musicSheets'},
        'books': {BOOK: {'title': 'Seventh-day Adventist Hymnal (1985)', 'hymns': hymns}},
    }
    staged = CATALOG.with_suffix('.tmp')
    staged.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    staged.replace(CATALOG)


def check():
    catalog = json.loads(CATALOG.read_text())
    assert catalog['schemaVersion'] == 1
    assert catalog['source']['revision'] == REVISION
    hymns = catalog['books'][BOOK]['hymns']
    assert set(hymns) == {str(n) for n in range(1, 696)}
    paths = set()
    for number, pages in hymns.items():
        assert pages, number
        for index, page in enumerate(pages):
            expected = f'piano_sheet_en_{int(number):03}' + (f'_{index}' if index else '') + '.png'
            assert page['asset'] == f'assets/sheet_music/en_1985/{expected}'
            path = ROOT / page['asset']
            assert path not in paths
            paths.add(path)
            data = path.read_bytes()
            assert len(data) == page['bytes']
            assert hashlib.sha256(data).hexdigest() == page['sha256']
            assert png_size(data) == (page['width'], page['height'])
    assert len(paths) == 723
    assert paths == set(DEST.glob('*.png'))
    print(f'Verified {len(hymns)} hymns / {len(paths)} offline score pages.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check:
        import_scores()
    check()
