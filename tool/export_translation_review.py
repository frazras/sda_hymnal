#!/usr/bin/env python3
"""Export draft interface messages for fluent review; never marks them approved."""
import argparse
import csv
import hashlib
import json
from pathlib import Path

from validate_translations import ROOT, load_catalog, validate


def export_review(directory, output, language):
    if language not in ('es', 'pt', 'ru'):
        raise ValueError('Choose es, pt, or ru')
    validate(directory)
    source = load_catalog(directory / 'app_en.arb')
    target = load_catalog(directory / f'app_{language}.arb')
    keys = [key for key in source if not key.startswith('@')]
    with output.open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=[
            'language', 'key', 'english', 'translation', 'context',
            'placeholders', 'content_sha256', 'review_status', 'reviewer',
            'review_date', 'suggested_translation', 'notes',
        ])
        writer.writeheader()
        for key in keys:
            metadata = source.get(f'@{key}', {})
            content = json.dumps([language, key, source[key], target[key]],
                                 ensure_ascii=False, separators=(',', ':'))
            writer.writerow({
                'language': language, 'key': key, 'english': source[key],
                'translation': target[key],
                'context': metadata.get('description', ''),
                'placeholders': ', '.join(metadata.get('placeholders', {})),
                'content_sha256': hashlib.sha256(content.encode()).hexdigest(),
                'review_status': 'unreviewed',
            })
    return len(keys)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('language', choices=['es', 'pt', 'ru'])
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print(f'Exported {export_review(ROOT / "lib/l10n", args.output, args.language)} draft messages to {args.output}')
