#!/usr/bin/env python3
"""Report bundled language-pack content and exact-edition score coverage offline.

Structural errors fail the command; missing media is reported as a coverage gap.
This does not certify musical equivalence or editorial accuracy.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def inspect_pack(pack, expected_numbers=None):
    errors = []
    def error(code, location):
        errors.append({'code': code, 'location': location})

    def valid_text(value):
        return isinstance(value, str) and bool(value.strip()) and '\ufffd' not in value

    if not isinstance(pack, dict):
        return {'errors': [{'code': 'invalid_pack', 'location': 'root'}]}
    book = pack.get('book', {})
    if not isinstance(book, dict):
        book = {}
    for field in ('id', 'languageTag', 'displayName'):
        if not valid_text(book.get(field)):
            error('invalid_book_metadata', field)
    if pack.get('schemaVersion') != 1:
        error('unsupported_schema', 'schemaVersion')
    source = pack.get('source', {})
    if not isinstance(source, dict) or not all(
            valid_text(source.get(k)) for k in ('repository', 'revision')):
        error('missing_provenance', 'source')
    items = pack.get('items')
    if not isinstance(items, list):
        error('invalid_items', 'items')
        items = []
    if not items:
        error('empty_book', 'items')
    ids, numbers = [], []
    for index, item in enumerate(items):
        at = f'items[{index}]'
        if not isinstance(item, dict):
            error('invalid_item', at)
            continue
        identity, number = item.get('id'), item.get('number')
        if not valid_text(identity):
            error('invalid_id', at)
        else:
            ids.append(identity)
        if type(number) is not int or number < 1:
            error('invalid_number', at)
        else:
            numbers.append(number)
        for field in ('title', 'sourceText'):
            if not valid_text(item.get(field)):
                error('empty_or_invalid_text', f'{at}.{field}')
        blocks = item.get('blocks')
        if not isinstance(blocks, list) or not blocks:
            error('missing_lyric_blocks', at)
        else:
            for b, block in enumerate(blocks):
                if not isinstance(block, dict) or not valid_text(block.get('text')):
                    error('empty_or_invalid_block', f'{at}.blocks[{b}]')
                elif block.get('kind') not in ('verse', 'refrain'):
                    error('invalid_block_kind', f'{at}.blocks[{b}]')
    for values, code in ((ids, 'duplicate_id'), (numbers, 'duplicate_number')):
        for value, count in sorted(Counter(values).items()):
            if count > 1:
                error(code, str(value))
    missing = sorted(set(expected_numbers or []) - set(numbers))
    unexpected = sorted(set(numbers) - set(expected_numbers)) if expected_numbers is not None else []
    for number in missing:
        error('missing_number', str(number))
    for number in unexpected:
        error('unexpected_number', str(number))
    topics = pack.get('topics', [])
    if not isinstance(topics, list):
        error('invalid_topics', 'topics')
        topics = []
    topic_ids = []
    for index, topic in enumerate(topics):
        at = f'topics[{index}]'
        if not isinstance(topic, dict):
            error('invalid_topic', at)
            continue
        for field in ('id', 'title', 'group'):
            if not valid_text(topic.get(field)):
                error('invalid_topic_metadata', f'{at}.{field}')
        if valid_text(topic.get('id')):
            topic_ids.append(topic['id'])
        refs = topic.get('itemIds')
        if not isinstance(refs, list) or not refs:
            error('invalid_topic_references', at)
        else:
            for ref in refs:
                if not isinstance(ref, str) or ref not in ids:
                    error('absent_topic_reference', f'{at}:{ref}')
    for identity, count in sorted(Counter(topic_ids).items()):
        if count > 1:
            error('duplicate_topic_id', identity)
    return {'bookId': book.get('id'), 'items': len(items), 'topics': len(topics),
            'source': source, 'missingNumbers': missing,
            'unexpectedNumbers': unexpected, 'errors': errors}


def local_asset(root, name):
    if not isinstance(name, str) or Path(name).is_absolute():
        raise ValueError('Invalid asset path')
    path = (root / name).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('Asset path escapes repository')
    return path


def report(root=ROOT):
    catalog = json.loads((root / 'assets/hymnals/catalog.json').read_text())
    manifest = json.loads((root / 'tool/data/hymnal_sources.json').read_text())
    scores = json.loads((root / 'assets/sheet_music/catalog.json').read_text())['books']
    expected = {b['id']: range(1, b['expectedCount'] + 1) for b in manifest['books']}
    books = []
    for entry in catalog['books']:
        try:
            data = local_asset(root, entry['asset']).read_bytes()
            pack = json.loads(data)
            result = inspect_pack(pack, expected.get(entry['id']))
            for field, actual in (
                    ('bytes', len(data)), ('sha256', hashlib.sha256(data).hexdigest()),
                    ('id', result.get('bookId')), ('hymnCount', result.get('items')),
                    ('topicCount', result.get('topics'))):
                if entry[field] != actual:
                    result['errors'].append({'code': 'catalog_mismatch', 'location': field})
            item_ids = {i['id'] for i in pack.get('items', [])
                        if isinstance(i, dict) and isinstance(i.get('id'), str)}
            mappings = scores.get(entry['id'], {}).get('hymns', {})
            available = set()
            for identity, pages in mappings.items():
                if identity not in item_ids:
                    result['errors'].append({'code': 'absent_score_reference', 'location': identity})
                valid = isinstance(pages, list) and bool(pages)
                for page in pages if isinstance(pages, list) else []:
                    try:
                        contents = local_asset(root, page['asset']).read_bytes()
                        if len(contents) != page['bytes'] or hashlib.sha256(contents).hexdigest() != page['sha256']:
                            raise ValueError('Score checksum mismatch')
                    except (OSError, ValueError, KeyError, TypeError):
                        valid = False
                if valid:
                    available.add(identity)
                else:
                    result['errors'].append({'code': 'invalid_score_asset', 'location': identity})
            result['media'] = {
                'scoreHymns': len(available & item_ids),
                'missingScoreItemIds': sorted(item_ids - available, key=lambda x: (len(x), x)),
                'audio': 'No verified instrumental or vocal mappings in these language packs.'}
        except (OSError, ValueError, KeyError, TypeError) as exc:
            result = {'bookId': entry.get('id'), 'errors': [
                {'code': 'unreadable_pack', 'location': str(exc)}]}
        books.append(result)
    return {'schemaVersion': 1, 'scope': 'Bundled imported language packs',
            'errorCount': sum(len(b['errors']) for b in books), 'books': books}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = report()
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(encoded)
    else:
        print(encoded, end='')
    raise SystemExit(1 if result['errorCount'] else 0)
