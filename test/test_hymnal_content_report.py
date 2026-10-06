import copy
import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('content_report', ROOT / 'tool/validate_hymnal_content.py')
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ContentReportTest(unittest.TestCase):
    def setUp(self):
        self.pack = dict(schemaVersion=1,
                         book=dict(id='test', languageTag='es', displayName='Prueba'),
                         source=dict(repository='example/book', revision='pinned'),
                         items=[dict(id='1', number=1, title='Corazón',
                                     sourceText='Línea', blocks=[dict(kind='verse', text='Línea')])],
                         topics=[dict(id='topic', group='Grupo', title='Tema', itemIds=['1'])])

    def codes(self, pack, expected=None):
        return {e['code'] for e in validator.inspect_pack(pack, expected)['errors']}

    def test_collects_multiple_failures_without_renumbering_or_mutation(self):
        self.pack['items'].append(copy.deepcopy(self.pack['items'][0]))
        self.pack['items'][1]['blocks'][0]['text'] = ''
        self.pack['items'][1]['title'] = ''
        self.pack['topics'][0]['itemIds'].append('3')
        before = copy.deepcopy(self.pack)
        self.assertTrue({'duplicate_id', 'duplicate_number', 'missing_number',
                         'empty_or_invalid_text', 'empty_or_invalid_block',
                         'absent_topic_reference'} <= self.codes(self.pack, [1, 2]))
        self.assertEqual(before, self.pack)

    def test_partial_numbering_requires_explicit_expected_numbers(self):
        self.pack['items'][0].update(id='237', number=237)
        self.pack['topics'][0]['itemIds'] = ['237']
        self.assertEqual(self.codes(self.pack), set())
        self.assertEqual(self.codes(self.pack, [237]), set())
        self.assertIn('missing_number', self.codes(self.pack, [1, 237]))

    def test_bad_shapes_are_reported(self):
        for field, value in [('items', [None]), ('items', None),
                             ('topics', [None]), ('topics', None),
                             ('source', []), ('book', None)]:
            with self.subTest(field=field, value=value):
                pack = copy.deepcopy(self.pack)
                pack[field] = value
                self.assertTrue(self.codes(pack))

    def test_duplicate_topics_and_unknown_block_kinds_are_rejected(self):
        self.pack['topics'].append(copy.deepcopy(self.pack['topics'][0]))
        self.pack['items'][0]['blocks'][0]['kind'] = 'guessed-chorus'
        self.assertEqual(self.codes(self.pack), {'duplicate_topic_id', 'invalid_block_kind'})

    def test_asset_paths_cannot_escape_root_even_through_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'escape').symlink_to(root.parent, target_is_directory=True)
            for name in ['../outside', '/etc/passwd', 'escape/outside']:
                with self.subTest(name=name), self.assertRaises(ValueError):
                    validator.local_asset(root, name)

    def test_corrupt_missing_and_wrong_edition_score_references_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def write(name, value):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(value))
                return path.read_bytes()
            data = write('assets/hymnals/test.json', self.pack)
            write('assets/hymnals/catalog.json', dict(books=[dict(
                id='test', asset='assets/hymnals/test.json', bytes=len(data),
                sha256=hashlib.sha256(data).hexdigest(), hymnCount=1, topicCount=1)]))
            write('tool/data/hymnal_sources.json', dict(books=[dict(id='test', expectedCount=1)]))
            score = root / 'score.png'
            score.write_bytes(b'actual')
            page = dict(asset='score.png', bytes=6, sha256=hashlib.sha256(b'actual').hexdigest())
            write('assets/sheet_music/catalog.json',
                  dict(books=dict(test=dict(hymns={'1': [page], '2': [page]}))))
            self.assertEqual(validator.report(root)['books'][0]['errors'],
                             [dict(code='absent_score_reference', location='2')])
            score.write_bytes(b'broken')
            self.assertIn('invalid_score_asset',
                          {e['code'] for e in validator.report(root)['books'][0]['errors']})
            score.unlink()
            result = validator.report(root)
            self.assertGreater(result['errorCount'], 0)
            self.assertEqual(result['books'][0]['media']['scoreHymns'], 0)

    def test_shipped_report_is_deterministic_and_exposes_known_score_gap(self):
        result = validator.report()
        self.assertEqual(result, validator.report())
        self.assertEqual(result['errorCount'], 0)
        books = {b['bookId']: b for b in result['books']}
        self.assertEqual(sum(b['items'] for b in books.values()), 2136)
        self.assertEqual(books['sda-es-2009']['media']['scoreHymns'], 614)
        self.assertEqual(books['sda-ru-1997']['media']['missingScoreItemIds'], ['244'])
        self.assertEqual(books['sda-es-1962']['media']['scoreHymns'], 0)


if __name__ == '__main__':
    unittest.main()
