#!/usr/bin/env python3
"""Publish compact, pinned score download metadata from verified page assets."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/sheet_music/downloads.json'


def build(root=ROOT):
    source = json.loads((root / 'tool/data/score_download_sources.json').read_text())
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', source['repository']) or not re.fullmatch(r'[0-9a-f]{40}', source['revision']):
        raise ValueError('Score downloads require a pinned repository revision')
    content = (root / 'assets/sheet_music/catalog.json').read_bytes()
    catalog = json.loads(content)
    if catalog['schemaVersion'] != 1:
        raise ValueError('Unsupported score catalog')
    books, seen = [], set()
    for identity, book in catalog['books'].items():
        if not re.fullmatch(r'sda-[a-z]{2,3}-[a-z0-9-]+', identity) or not book['hymns']:
            raise ValueError('Invalid score book')
        total, pages = 0, 0
        directory = identity[4:].replace('-', '_')
        for number, images in book['hymns'].items():
            if not re.fullmatch(r'[1-9][0-9]*', number) or not images:
                raise ValueError('Invalid score hymn')
            for image in images:
                path = image['asset']
                if not re.fullmatch(r'assets/sheet_music/[a-z0-9_]+/[a-z0-9_]+\.png', path) or not path.startswith(f'assets/sheet_music/{directory}/') or path in seen:
                    raise ValueError('Ambiguous score page')
                seen.add(path)
                data = (root / path).read_bytes()
                if len(data) != image['bytes'] or not 33 <= len(data) <= 16 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != image['sha256']:
                    raise ValueError('Score integrity mismatch')
                if data[:8] != b'\x89PNG\r\n\x1a\n' or data[8:16] != b'\x00\x00\x00\rIHDR' or int.from_bytes(data[16:20], 'big') != image['width'] or int.from_bytes(data[20:24], 'big') != image['height']:
                    raise ValueError('Score dimensions mismatch')
                if not 0 < image['width'] <= 16384 or not 0 < image['height'] <= 16384:
                    raise ValueError('Unbounded score dimensions')
                total += len(data)
                pages += 1
        if pages > 5000 or total > 256 * 1024 * 1024:
            raise ValueError('Unbounded score collection')
        books.append(dict(bookId=identity, displayName=book['title'], hymnCount=len(book['hymns']), pageCount=pages, bytes=total, bundled=True))
    if not books:
        raise ValueError('Empty score download catalog')
    return dict(schemaVersion=1, source=source, catalogSha256=hashlib.sha256(content).hexdigest(), books=books)


def verify_remote(catalog):
    source = catalog['source']
    url = f'https://raw.githubusercontent.com/{source["repository"]}/{source["revision"]}/assets/sheet_music/catalog.json'
    with urllib.request.urlopen(url, timeout=30) as response:
        if response.status != 200 or response.geturl() != url:
            raise ValueError('Score catalog hosting mismatch')
        data = response.read(2 * 1024 * 1024 + 1)
    if hashlib.sha256(data).hexdigest() != catalog['catalogSha256']:
        raise ValueError('Published score catalog differs from reviewed bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--verify-remote', action='store_true')
    args = parser.parse_args()
    catalog = build()
    encoded = (json.dumps(catalog, ensure_ascii=False, indent=2) + '\n').encode()
    if args.check:
        if not DEST.exists() or DEST.read_bytes() != encoded:
            raise SystemExit('Score download catalog needs regeneration')
    else:
        DEST.write_bytes(encoded)
    if args.verify_remote:
        verify_remote(catalog)
    print(f'Verified {len(catalog["books"])} score download collections.')
