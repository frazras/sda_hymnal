import csv
import json
from pathlib import Path
import tempfile
import unittest
from export_translation_review import export_review
from import_translation_review import stage_review

class ReviewImportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalogs = self.root / 'catalogs'
        self.catalogs.mkdir()
        for language in ('en', 'es', 'pt', 'ru'):
            data = {'@@locale': language, 'title': 'Hymn {number}',
                    '@title': {'description': 'Hymn heading', 'placeholders': {'number': {'type': 'int'}}},
                    'plain': 'Hello'}
            (self.catalogs / f'app_{language}.arb').write_text(json.dumps(data))
        self.csv = self.root / 'review.csv'
        export_review(self.catalogs, self.csv, 'es')
        with self.csv.open(encoding='utf-8-sig', newline='') as stream:
            reader = csv.DictReader(stream)
            self.columns = reader.fieldnames
            self.rows = list(reader)
        self.output = self.root / 'staged'
        self.original = {p.name: p.read_bytes() for p in self.catalogs.glob('*.arb')}

    def write(self):
        with self.csv.open('w', encoding='utf-8-sig', newline='') as stream:
            writer = csv.DictWriter(stream, fieldnames=self.columns)
            writer.writeheader(); writer.writerows(self.rows)

    def stage(self, syntax=lambda _: None):
        self.write()
        return stage_review(self.catalogs, self.csv, self.output, syntax)

    def approve(self):
        self.rows[0].update(review_status='reviewed', reviewer='Fixture reviewer',
                            review_date='2026-01-01', suggested_translation='Himno {number}')

    def test_only_reviewed_corrections_are_staged_with_audit(self):
        self.approve()
        self.rows[1]['suggested_translation'] = 'Unreviewed suggestion'
        called = []
        audit = self.stage(lambda path: called.append(path))
        self.assertEqual(audit['reviewedMessages'], 1)
        self.assertEqual(audit['unreviewedMessages'], 1)
        data = json.loads((self.output / 'app_es.arb').read_text())
        self.assertEqual(data['title'], 'Himno {number}')
        self.assertEqual(data['plain'], 'Hello')
        self.assertEqual((self.output / 'review.csv').read_bytes(), self.csv.read_bytes())
        self.assertEqual(audit, json.loads((self.output / 'review-audit.json').read_text()))
        self.assertEqual(len(called), 2)
        self.assertEqual(self.original, {p.name: p.read_bytes() for p in self.catalogs.glob('*.arb')})

    def test_stale_hash_context_or_missing_reviewer_fails_without_outputs(self):
        original = [dict(r) for r in self.rows]
        for changes in ({'content_sha256': '0'*64}, {'english': 'Changed'},
                        {'context': 'Changed'}, {'review_status': 'approved'},
                        {'review_status': 'reviewed', 'reviewer': ''},
                        {'review_status': 'reviewed', 'reviewer': 'Fixture', 'review_date': '2999-01-01'},
                        {'review_status': 'reviewed', 'reviewer': 'Fixture', 'review_date': 'bad'},
                        {'review_status': 'reviewed', 'reviewer': 'Fixture', 'review_date': '20260101'}):
            self.rows = [dict(r) for r in original]
            self.rows[0].update(changes)
            with self.assertRaises(ValueError): self.stage()
            self.assertFalse(self.output.exists())

    def test_missing_placeholder_and_icu_failure_never_publish(self):
        self.approve(); self.rows[0]['suggested_translation'] = 'Himno'
        with self.assertRaisesRegex(ValueError, 'missing argument'): self.stage()
        self.rows[0]['suggested_translation'] = 'Himno {number}'
        def reject(_): raise ValueError('ICU parse error')
        with self.assertRaisesRegex(ValueError, 'ICU parse error'): self.stage(reject)
        self.assertFalse(self.output.exists())

    def test_generated_api_changes_never_publish(self):
        self.approve()
        versions = iter([b'original API', b'changed API'])
        with self.assertRaisesRegex(ValueError, 'localization API'):
            self.stage(lambda _: next(versions))
        self.assertFalse(self.output.exists())

    def test_missing_duplicate_keys_or_live_output_directory_fails(self):
        original = [dict(r) for r in self.rows]
        for rows in ([self.rows[0]], [self.rows[0], self.rows[0]]):
            self.rows = rows
            with self.assertRaises(ValueError): self.stage()
        self.rows = original
        self.output = self.catalogs
        with self.assertRaises(ValueError): self.stage()
