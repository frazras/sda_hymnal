#!/usr/bin/env python3
"""Stage reviewed interface corrections; never edit live catalogs automatically."""
import argparse
import csv
import datetime as dt
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from validate_translations import ROOT, load_catalog, validate

COLUMNS = {'language', 'key', 'english', 'translation', 'context', 'placeholders',
           'content_sha256', 'review_status', 'reviewer', 'review_date',
           'suggested_translation', 'notes'}


def flutter_syntax(directory):
    flutter = shutil.which('flutter')
    if not flutter:
        raise ValueError('Flutter is required to validate ICU syntax')
    project = directory.parent
    (project / 'pubspec.yaml').write_text('name: translation_review_validation\nenvironment:\n  sdk: ">=3.0.0 <4.0.0"\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  generate: true\n')
    try:
        subprocess.run([flutter, 'gen-l10n', '--arb-dir', str(directory),
                        '--output-dir', str(project / 'generated')], cwd=project, check=True,
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip()
        raise ValueError('Flutter rejected staged translations: ' + detail) from None
    return (project / 'generated/app_localizations.dart').read_bytes()


def stage_review(directory, review_file, output, syntax_validator=flutter_syntax):
    directory, output = directory.resolve(), output.resolve()
    if output.is_relative_to(directory) or output.exists():
        raise ValueError('Choose a new staging directory outside the live catalogs')
    validate(directory)
    raw = review_file.read_bytes()
    reader = csv.DictReader(io.StringIO(raw.decode('utf-8-sig')))
    if reader.fieldnames is None or set(reader.fieldnames) != COLUMNS or len(reader.fieldnames) != len(COLUMNS):
        raise ValueError('Review CSV columns do not match the exported template')
    rows = list(reader)
    languages = {row['language'] for row in rows}
    if len(languages) != 1 or not languages <= {'es', 'pt', 'ru'}:
        raise ValueError('Review must contain exactly one supported language')
    language = languages.pop()
    source = load_catalog(directory / 'app_en.arb')
    target = load_catalog(directory / f'app_{language}.arb')
    expected = {key for key in source if not key.startswith('@')}
    seen, decisions = set(), []
    for row in rows:
        key = row['key']
        if key not in expected or key in seen or None in row or any(v is None for v in row.values()):
            raise ValueError('Unknown, duplicate, or incomplete review row')
        seen.add(key)
        content = json.dumps([language, key, source[key], target[key]], ensure_ascii=False, separators=(',', ':'))
        if row['english'] != source[key] or row['translation'] != target[key] or row['content_sha256'] != hashlib.sha256(content.encode()).hexdigest():
            raise ValueError(f'Stale source or translation: {key}')
        metadata = source.get(f'@{key}', {})
        if row['context'] != metadata.get('description', '') or row['placeholders'] != ', '.join(metadata.get('placeholders', {})):
            raise ValueError(f'Stale review context: {key}')
        if row['review_status'] == 'unreviewed':
            continue
        if row['review_status'] != 'reviewed' or not row['reviewer'].strip():
            raise ValueError(f'Invalid review status or missing reviewer: {key}')
        try:
            date = dt.date.fromisoformat(row['review_date'])
        except ValueError:
            raise ValueError(f'Invalid review date: {key}') from None
        if row['review_date'] != str(date):
            raise ValueError(f'Use an ISO review date: {key}')
        if date > dt.date.today():
            raise ValueError(f'Future review date: {key}')
        replacement = row['suggested_translation'] or target[key]
        if not replacement.strip():
            raise ValueError(f'Empty correction: {key}')
        decisions.append(dict(key=key, before=target[key], after=replacement,
            reviewer=row['reviewer'], reviewDate=str(date), notes=row['notes']))
        target[key] = replacement
    if seen != expected:
        raise ValueError('Review CSV is missing message keys')
    with tempfile.TemporaryDirectory(prefix='translation-review-') as temp:
        catalogs = Path(temp) / 'catalogs'
        catalogs.mkdir()
        for path in directory.glob('*.arb'):
            shutil.copyfile(path, catalogs / path.name)
        baseline_api = syntax_validator(catalogs)
        (catalogs / f'app_{language}.arb').write_text(json.dumps(target, ensure_ascii=False, indent=2) + '\n')
        validate(catalogs)
        corrected_api = syntax_validator(catalogs)
        if baseline_api != corrected_api:
            raise ValueError('Corrections change the generated localization API')
        audit = dict(schemaVersion=1, language=language,
            reviewFileSha256=hashlib.sha256(raw).hexdigest(), reviewedMessages=len(decisions),
            unreviewedMessages=len(expected) - len(decisions), decisions=decisions)
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='review-stage-', dir=output.parent) as staged:
            staged = Path(staged)
            shutil.copyfile(catalogs / f'app_{language}.arb', staged / f'app_{language}.arb')
            (staged / 'review.csv').write_bytes(raw)
            (staged / 'review-audit.json').write_text(json.dumps(audit, ensure_ascii=False, indent=2) + '\n')
            staged.rename(output)
    return audit


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('review', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = stage_review(ROOT / 'lib/l10n', args.review, args.output)
    print(f"Staged {result['reviewedMessages']} reviewed messages; {result['unreviewedMessages']} remain unreviewed. Live catalogs unchanged.")
