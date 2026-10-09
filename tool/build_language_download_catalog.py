#!/usr/bin/env python3
"""Build/check reviewed text download metadata; verify pinned hosting on demand."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/hymnals/downloads.json'


def build(root=ROOT):
    source = json.loads((root / 'tool/data/language_download_sources.json').read_text())
    repository, revision = source['repository'], source['revision']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Download sources must pin a repository and full commit')
    catalog = json.loads((root / 'assets/hymnals/catalog.json').read_text())
    books, seen = [], set()
    for entry in catalog['books']:
        book = entry['id']
        if not re.fullmatch(r'sda-[a-z0-9-]+', book) or book in seen:
            raise ValueError('Invalid or duplicate download book')
        seen.add(book)
        asset = f'assets/hymnals/{book}.json'
        if entry['asset'] != asset:
            raise ValueError('Download asset identity mismatch')
        data = (root / asset).read_bytes()
        pack = json.loads(data)
        if (len(data) != entry['bytes'] or not 0 < len(data) <= 16 * 1024 * 1024
                or hashlib.sha256(data).hexdigest() != entry['sha256']
                or pack['book']['id'] != book or len(pack['items']) != entry['hymnCount']
                or len(pack['topics']) != entry['topicCount']):
            raise ValueError('Download catalog does not match reviewed pack')
        books.append(dict(bookId=book, displayName=entry['displayName'],
                          languageTag=entry['languageTag'], year=entry['year'],
                          bytes=entry['bytes'], sha256=entry['sha256'],
                          hymnCount=entry['hymnCount'], topicCount=entry['topicCount'],
                          coverage=pack['coverage'],
                          url=f'https://raw.githubusercontent.com/{repository}/{revision}/{asset}'))
    for asset in source.get('optionalPacks', []):
        if not isinstance(asset, str) or not re.fullmatch(r'resources/hymnals/sda-[a-z0-9-]+\.json', asset):
            raise ValueError('Invalid optional pack path')
        data = (root / asset).read_bytes()
        pack = json.loads(data)
        book = pack['book']
        identity = book['id']
        if identity in seen or asset != f'resources/hymnals/{identity}.json':
            raise ValueError('Optional pack identity mismatch')
        from validate_hymnal_content import inspect_pack
        if inspect_pack(pack)['errors'] or not 0 < len(data) <= 16 * 1024 * 1024:
            raise ValueError('Invalid optional pack content')
        seen.add(identity)
        books.append(dict(bookId=identity, displayName=book['displayName'],
                          languageTag=book['languageTag'], year=book.get('year'),
                          path=asset, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                          hymnCount=len(pack['items']), topicCount=len(pack['topics']),
                          coverage=pack['coverage'],
                          url=f'https://raw.githubusercontent.com/{repository}/{revision}/{asset}'))
    return dict(schemaVersion=1, source=source, books=books)


def verify_remote(catalog):
    for book in catalog['books']:
        with urllib.request.urlopen(book['url'], timeout=30) as response:
            if response.status != 200 or response.url != book['url']:
                raise ValueError('Download destination changed')
            data = response.read(book['bytes'] + 1)
        if len(data) != book['bytes'] or hashlib.sha256(data).hexdigest() != book['sha256']:
            raise ValueError(f'Published text checksum mismatch: {book["bookId"]}')
        print(f'Published text verified: {book["bookId"]} ({len(data)} bytes)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--verify-remote', action='store_true')
    args = parser.parse_args()
    catalog = build()
    if args.verify_remote:
        verify_remote(catalog)
    encoded = json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'
    if args.check:
        if not DEST.exists() or DEST.read_text() != encoded:
            raise ValueError('Generated download catalog differs')
    else:
        DEST.write_text(encoded)
    print(f'Checked {len(catalog["books"])} text downloads')
