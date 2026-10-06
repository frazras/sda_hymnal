#!/usr/bin/env python3
"""Build pinned, offline language packs without executing upstream programs.

Run normally to fetch verified source snapshots and generate packs. --check
rebuilds from local snapshots and compares every output byte, without networking.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'tool/data/hymnal_sources.json'
SNAPSHOTS = ROOT / 'tool/data/hymnal_sources'
DEST = ROOT / 'assets/hymnals'


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode('utf-8')


def verified(data, source):
    if len(data) != source['bytes'] or hashlib.sha256(data).hexdigest() != source['sha256']:
        raise ValueError(f'Source checksum mismatch: {source["path"]}')
    return json.loads(data.decode('utf-8'))


def source_data(manifest, source, check):
    path = SNAPSHOTS / Path(source['path']).name
    if path.exists():
        return verified(path.read_bytes(), source)
    if check:
        raise ValueError(f'Missing source snapshot: {path}')
    url = (f'https://raw.githubusercontent.com/{manifest["repository"]}/'
           f'{manifest["revision"]}/{source["path"]}')
    request = urllib.request.Request(url, headers={'User-Agent': 'SDAHymnal-content-import'})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            parsed = verified(data, source)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            return parsed
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def text(value, field):
    if not isinstance(value, str) or not value.strip() or '\ufffd' in value:
        raise ValueError(f'Empty or invalid {field}')
    return value


def lyric_blocks(content):
    """Keep source order; label only explicit headings, never infer repeats."""
    blocks = []
    for paragraph in re.split(r'\n\s*\n', content.replace('\r\n', '\n')):
        if not paragraph.strip():
            continue
        lines = paragraph.split('\n')
        heading = lines[0].strip()
        block = {'kind': 'verse', 'text': paragraph}
        if len(lines) > 1 and re.fullmatch(r'\d+[.)]?', heading):
            block.update(label=heading, text='\n'.join(lines[1:]))
        elif len(lines) > 1 and re.fullmatch(
                r'(coro|estribillo|refrão|coro final|припев)[:.]?', heading, re.IGNORECASE):
            block.update(kind='refrain', label=heading, text='\n'.join(lines[1:]))
        text(block['text'], 'lyric block')
        blocks.append(block)
    if not blocks:
        raise ValueError('No lyric blocks')
    return blocks


def build_pack(book, lyrics, topic_groups, provenance):
    if not isinstance(lyrics, list) or len(lyrics) != book['expectedCount']:
        raise ValueError(f'Unexpected count in {book["id"]}')
    seen = set()
    items = []
    for hymn in lyrics:
        number = hymn.get('number')
        if type(number) is not int or number < 1 or number in seen:
            raise ValueError(f'Duplicate/invalid number: {number}')
        seen.add(number)
        content = text(hymn.get('content'), 'lyrics')
        item = {'id': str(number), 'number': number,
                'title': text(hymn.get('title'), 'title'),
                'sourceText': content, 'blocks': lyric_blocks(content)}
        if hymn.get('author'):
            item['credits'] = text(hymn['author'], 'credits')
        items.append(item)
    if seen != set(range(1, book['expectedCount'] + 1)):
        raise ValueError(f'Unexpected numbering gaps in {book["id"]}')
    items.sort(key=lambda item: item['number'])
    topics = []
    for group_index, group in enumerate(topic_groups):
        group_name = text(group.get('thematic'), 'topic group')
        for topic_index, topic in enumerate(group['ambits']):
            start, end = topic['star'], topic['end']
            if type(start) is not int or type(end) is not int or start > end:
                raise ValueError('Invalid topic range')
            numbers = list(range(start, end + 1))
            if not numbers or not set(numbers) <= seen:
                raise ValueError(f'Topic refers to absent hymns: {group_name}')
            topics.append({'id': f'{group_index + 1}-{topic_index + 1}',
                           'group': group_name, 'title': text(topic['ambit'], 'topic'),
                           'itemIds': [str(number) for number in numbers]})
    metadata = {key: book[key] for key in ['id', 'languageTag', 'displayName', 'year']}
    return {'schemaVersion': 1, 'book': metadata, 'contentVersion': provenance['revision'],
            'source': provenance,
            'coverage': {'sourceRecords': len(items), 'structurallyComplete': True,
                         'note': 'Imported source edition; independent lyric review pending.'},
            'items': items, 'topics': topics}


def build(check=False):
    manifest = json.loads(MANIFEST.read_text())
    outputs = {}
    books = []
    for book in manifest['books']:
        sources = {kind: source_data(manifest, source, check)
                   for kind, source in book['sources'].items()}
        provenance = {'repository': manifest['repository'], 'revision': manifest['revision'],
                      'files': book['sources']}
        pack = build_pack(book, sources['lyrics'], sources['topics'], provenance)
        data = json_bytes(pack)
        asset = f'assets/hymnals/{book["id"]}.json'
        outputs[ROOT / asset] = data
        books.append({**pack['book'], 'asset': asset, 'hymnCount': len(pack['items']),
                      'topicCount': len(pack['topics']), 'bytes': len(data),
                      'sha256': hashlib.sha256(data).hexdigest()})
    # Import lazily to avoid a module cycle with the shared text helpers.
    from import_structured_hymnals import convert
    for name in ('french', 'swahili'):
        manifest_path = ROOT / 'tool/data/structured_sources' / f'{name}.manifest.json'
        structured = json.loads(manifest_path.read_text())
        snapshot = manifest_path.parent / structured['snapshot']
        source = verified(snapshot.read_bytes(), structured['source'])
        pack = convert(source, structured)
        data = json_bytes(pack)
        asset = f'assets/hymnals/{pack["book"]["id"]}.json'
        outputs[ROOT / asset] = data
        books.append({**pack['book'], 'asset': asset, 'hymnCount': len(pack['items']),
                      'topicCount': len(pack['topics']), 'bytes': len(data),
                      'sha256': hashlib.sha256(data).hexdigest()})
    outputs[DEST / 'catalog.json'] = json_bytes({'schemaVersion': 1, 'books': books})
    # All books validate before replacing any generated asset. The build step
    # does not activate a runtime download or touch user storage.
    for path, data in outputs.items():
        if check:
            if not path.exists() or path.read_bytes() != data:
                raise ValueError(f'Generated pack differs: {path}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            staged = path.with_suffix('.tmp')
            staged.write_bytes(data)
            staged.replace(path)
    print(f'{"Verified" if check else "Built"} {len(books)} books: '
          f'{sum(book["hymnCount"] for book in books)} hymns, '
          f'{sum(book["topicCount"] for book in books)} topics.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
