#!/usr/bin/env python3
"""Convert pinned VideoPsalm or structured verse JSON to a reviewable pack.

Outputs are staging files, never automatically registered in the app catalog.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from import_hymnals import json_bytes, text
from validate_hymnal_content import inspect_pack, local_asset

OMISSIONS = ('empty', 'invalidText', 'duplicateNumber', 'duplicateLyrics')


def sequence(value, field):
    if not isinstance(value, list) or not value:
        raise ValueError(f'Missing or invalid {field}')
    if not all(isinstance(item, dict) for item in value):
        raise ValueError(f'Invalid record in {field}')
    return value


def positive_number(value):
    if type(value) is not int or value < 1:
        raise ValueError(f'Invalid source number: {value}')
    return value


def lines(block):
    value = block.get('lines')
    if not isinstance(value, list) or not value:
        raise ValueError('Missing lyric lines')
    if any(not isinstance(line, str) or '\ufffd' in line for line in value):
        raise ValueError('Invalid lyric line')
    return text('\n'.join(value), 'lyric block')


def record_fields(record, fmt):
    """Return a source record's number, title and lyric strings in source order."""
    if fmt == 'videopsalm':
        verses = record.get('Verses')
        strings = [verse.get('Text') for verse in verses if isinstance(verse, dict)] \
            if isinstance(verses, list) else []
        return record.get('ID'), record.get('Text'), strings
    verses = record.get('verses')
    strings = []
    for block in (verses if isinstance(verses, list) else []) + [record.get('refrain')]:
        if isinstance(block, dict) and isinstance(block.get('lines'), list):
            strings.extend(block['lines'])
    return record.get('pageNumber'), record.get('title'), strings


def omitted_records(records, manifest, fmt):
    """Indexes of source records withheld by explicit manifest decisions.

    Only unpublishable records (no lyrics, or text damaged by U+FFFD), a later
    duplicate of a retained number, or an exact lyric copy of a retained hymn
    filed under a different title may be withheld. Every decision names the
    record, a reason and a reviewer; numbers are never reassigned.
    """
    entries = manifest.get('omittedRecords', [])
    if not isinstance(entries, list):
        raise ValueError('Omitted records must be a list')
    fields = [record_fields(record, fmt) for record in records]
    chosen = {}
    for entry in entries:
        if not isinstance(entry, dict) or entry.get('kind') not in OMISSIONS:
            raise ValueError('Invalid omitted record')
        text(entry.get('reason'), 'omission reason')
        text(entry.get('reviewer'), 'omission reviewer')
        matches = [index for index, (number, title, _) in enumerate(fields)
                   if number == entry.get('number') and title == entry.get('title')
                   and ('guid' not in entry or records[index].get('Guid') == entry['guid'])]
        if len(matches) != 1 or matches[0] in chosen:
            raise ValueError('Omitted record must identify exactly one source record')
        chosen[matches[0]] = entry
    retained = [index for index in range(len(records)) if index not in chosen]
    for index, entry in chosen.items():
        number, title, strings = fields[index]
        kind = entry['kind']
        if kind == 'empty':
            allowed = not any(isinstance(s, str) and s.strip() for s in strings)
        elif kind == 'invalidText':
            allowed = any(isinstance(s, str) and '\ufffd' in s for s in [title, *strings])
        elif kind == 'duplicateNumber':
            allowed = any(fields[other][0] == number for other in retained)
        else:
            others = [other for other in retained if fields[other][0] == entry.get('lyricsOf')]
            allowed = (len(others) == 1 and bool(strings) and fields[others[0]][2] == strings
                       and fields[others[0]][1] != title)
        if not allowed:
            raise ValueError(f'Omitted record {number} does not meet the {kind} condition')
    return set(chosen)


def convert(source, manifest):
    fmt = manifest['format']
    if fmt == 'videopsalm':
        records = sequence(source.get('Songs') if isinstance(source, dict) else None, 'Songs')
    elif fmt == 'structured-verses':
        records = sequence(source, 'songs')
    else:
        raise ValueError(f'Unsupported format: {fmt}')
    expected = manifest['expectedNumbers']
    if (not isinstance(expected, list) or not expected
            or any(type(n) is not int or n < 1 for n in expected)
            or len(expected) != len(set(expected))):
        raise ValueError('Expected numbers must be explicit, positive and unique')
    omitted = omitted_records(records, manifest, fmt)
    items = []
    for index, record in enumerate(records):
        if index in omitted:
            continue
        if fmt == 'videopsalm':
            number = positive_number(record.get('ID'))
            title = text(record.get('Text'), 'title')
            blocks = []
            for verse in sequence(record.get('Verses'), 'Verses'):
                # Tags are source-specific. Only a reviewed manifest can label
                # one as a refrain; preserve every source occurrence in order.
                kind = 'refrain' if verse.get('Tag') in manifest.get('refrainTags', []) else 'verse'
                blocks.append(dict(kind=kind, text=text(verse.get('Text'), 'verse')))
        else:
            number = positive_number(record.get('pageNumber'))
            title = text(record.get('title'), 'title')
            if record.get('language') != manifest['sourceLanguage']:
                raise ValueError(f'Unexpected source language at {number}')
            blocks = []
            for verse in sequence(record.get('verses'), 'verses'):
                label = positive_number(verse.get('number'))
                blocks.append(dict(kind='verse', label=str(label), text=lines(verse)))
            # The source stores a separate refrain, without a performance
            # order. Preserve it once; never invent repetitions or MIDI timing.
            if record.get('refrain') is not None:
                if not isinstance(record['refrain'], dict):
                    raise ValueError('Invalid refrain')
                blocks.append(dict(kind='refrain', text=lines(record['refrain'])))
        items.append(dict(id=str(number), number=number, title=title,
                          sourceText='\n\n'.join(block['text'] for block in blocks),
                          blocks=blocks, sourceRecord=copy.deepcopy(record)))
    provenance = copy.deepcopy(manifest['source'])
    for field in ('repository', 'revision', 'path', 'sha256'):
        text(provenance.get(field), field)
    pack = dict(schemaVersion=1, book=copy.deepcopy(manifest['book']),
                contentVersion=provenance['revision'], source=provenance,
                coverage=dict(sourceRecords=len(records),
                              structurallyComplete=manifest['structurallyComplete'],
                              note=text(manifest.get('coverageNote'), 'coverage note')),
                items=items, topics=[])
    if type(pack['coverage']['structurallyComplete']) is not bool:
        raise ValueError('Coverage must explicitly declare completeness')
    errors = inspect_pack(pack, expected)['errors']
    if errors:
        raise ValueError(json.dumps(errors, ensure_ascii=False))
    return pack


def apply_overrides(pack, overrides):
    result = copy.deepcopy(pack)
    if overrides is None:
        return result
    if not isinstance(overrides, dict):
        raise ValueError('Reviewed overrides must be an object')
    if overrides.get('sourceRevision') != pack['source']['revision']:
        raise ValueError('Overrides target a different source revision')
    changes = sequence(overrides.get('changes'), 'reviewed changes')
    seen = set()
    for change in changes:
        key = (change.get('itemId'), change.get('field'))
        if key in seen or key[1] not in ('title', 'blocks', 'credits'):
            raise ValueError('Duplicate or unsupported override')
        seen.add(key)
        text(change.get('reviewer'), 'reviewer')
        text(change.get('reason'), 'review reason')
        matches = [item for item in result['items'] if item['id'] == key[0]]
        if len(matches) != 1 or matches[0].get(key[1]) != change.get('before'):
            raise ValueError('Override precondition does not match source')
        if 'after' not in change:
            raise ValueError('Override missing replacement')
        if key[1] in ('title', 'credits'):
            text(change['after'], key[1])
        matches[0][key[1]] = copy.deepcopy(change['after'])
    errors = inspect_pack(result)['errors']
    if errors:
        raise ValueError(json.dumps(errors))
    changed_blocks = {change['itemId'] for change in changes if change['field'] == 'blocks'}
    for item in result['items']:
        if item['id'] in changed_blocks:
            item['sourceText'] = '\n\n'.join(block['text'] for block in item['blocks'])
    result['reviewedOverrides'] = copy.deepcopy(overrides)
    result['contentVersion'] = pack['contentVersion'] + '-review-' + hashlib.sha256(json_bytes(overrides)).hexdigest()
    return result


def build(manifest_path, output, overrides_path=None, check=False):
    manifest = json.loads(manifest_path.read_text())
    data = local_asset(manifest_path.parent, manifest['snapshot']).read_bytes()
    source = manifest['source']
    if len(data) != source['bytes'] or hashlib.sha256(data).hexdigest() != source['sha256']:
        raise ValueError('Pinned source size/checksum mismatch')
    pack = convert(json.loads(data), manifest)
    overrides = json.loads(overrides_path.read_text()) if overrides_path else None
    pack = apply_overrides(pack, overrides)
    encoded = json_bytes(pack)
    if check:
        if not output.exists() or output.read_bytes() != encoded:
            raise ValueError('Generated staging pack differs')
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        staged = output.with_suffix(output.suffix + '.tmp')
        staged.write_bytes(encoded)
        staged.replace(output)
    return pack


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--overrides', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    build(args.manifest, args.output, args.overrides, args.check)
