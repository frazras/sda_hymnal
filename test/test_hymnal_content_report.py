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
            write('assets/hymnals/spanish_recordings.json', dict(
                schemaVersion=1, repository='owner/repo', revision='a'*40,
                books=[dict(bookId='unknown', expectedCount=1, totalBytes=100,
                            items=[dict(itemId='1', path='wrong.m4a', bytes=100,
                                        gitBlobSha1='b'*40)])]))
            result = validator.report(root)
            self.assertIn('absent_recording_book',
                          {e['code'] for e in result['catalogErrors']})
            self.assertEqual(result['errorCount'], len(result['catalogErrors']) +
                             sum(len(book['errors']) for book in result['books']))
            self.assertEqual(result['books'][0]['media']['instrumentalRecordingItemIds'], [])

    def test_recording_metadata_rejects_wrong_edition_duplicates_and_bad_hashes(self):
        item = dict(itemId='1', path='music/spanish/2009 version/instrumental/001.m4a',
                    bytes=100, gitBlobSha1='a' * 40)
        catalog = dict(schemaVersion=1, repository='owner/repo', revision='b' * 40,
                       books=[dict(bookId='sda-es-2009', expectedCount=1,
                                   totalBytes=100, items=[item])])
        identities = {'sda-es-2009': {'1', '2'}}
        available, errors = validator.inspect_recordings(catalog, identities)
        self.assertEqual(errors, [])
        self.assertEqual(available, {'sda-es-2009': {'1'}})
        before = copy.deepcopy(catalog)
        bad = copy.deepcopy(catalog)
        bad['books'][0]['items'].append(copy.deepcopy(item))
        bad['books'][0]['items'][1]['gitBlobSha1'] = 'not-a-hash'
        bad['books'][0]['items'].append(dict(
            itemId='999', path='../another-book.m4a', bytes=True, gitBlobSha1='a'*40))
        available, errors = validator.inspect_recordings(bad, identities)
        self.assertTrue({'duplicate_recording_reference', 'absent_recording_reference',
                         'invalid_recording_path', 'invalid_recording_integrity',
                         'recording_count_mismatch', 'recording_bytes_mismatch'} <=
                        {e['code'] for e in errors})
        self.assertEqual(available['sda-es-2009'], set())
        self.assertEqual(catalog, before)
        bad = copy.deepcopy(catalog)
        bad['books'][0]['items'][0]['path'] = 'music/spanish/1962 version/instrumental/001.m4a'
        available, errors = validator.inspect_recordings(bad, identities)
        self.assertEqual(available['sda-es-2009'], set())
        self.assertEqual(errors[0]['code'], 'invalid_recording_path')
        bad['books'][0]['bookId'] = 'unknown'
        _, errors = validator.inspect_recordings(bad, identities)
        self.assertIn('absent_recording_book', {e['code'] for e in errors})

    def test_recording_shapes_and_provenance_fail_without_crashing(self):
        for catalog in [None, [], {}, dict(schemaVersion=1, books=None),
                        dict(schemaVersion=1, books=[None, {}])]:
            with self.subTest(catalog=catalog):
                _, errors = validator.inspect_recordings(catalog, {})
                self.assertTrue(errors)

    def test_midi_gate_rejects_unknown_duplicate_corrupt_and_invalid_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            asset = b'MThd' + (6).to_bytes(4, 'big') + bytes([0, 0, 0, 1, 0, 96])
            (root / 'song.mid').write_bytes(asset)
            mapping = dict(bookId='test', itemId='1', asset='song.mid',
                           sha256=hashlib.sha256(asset).hexdigest())
            catalog = dict(schemaVersion=1, mappings=[mapping])
            before = copy.deepcopy(catalog)
            available, errors = validator.inspect_midi(catalog, {'test': {'1'}}, root)
            self.assertEqual(available, {'test': {'1'}})
            self.assertEqual(errors, [])
            for field, value in [('bookId', 'unknown'), ('itemId', '2'),
                                 ('sha256', 'wrong'), ('asset', '../song.mid')]:
                bad = copy.deepcopy(catalog)
                bad['mappings'][0][field] = value
                available, errors = validator.inspect_midi(bad, {'test': {'1'}}, root)
                self.assertEqual(available, {})
                self.assertEqual(len(errors), 1)
            bad = copy.deepcopy(catalog)
            bad['mappings'].append(copy.deepcopy(mapping))
            available, errors = validator.inspect_midi(bad, {'test': {'1'}}, root)
            self.assertEqual(available['test'], set())
            self.assertEqual(len(errors), 1)
            (root / 'song.mid').write_bytes(b'not MIDI')
            bad = copy.deepcopy(catalog)
            bad['mappings'][0]['sha256'] = hashlib.sha256(b'not MIDI').hexdigest()
            self.assertTrue(validator.inspect_midi(bad, {'test': {'1'}}, root)[1])
            self.assertEqual(catalog, before)
        for malformed in [None, [], {}, dict(schemaVersion=1, mappings=[None, {}])]:
            self.assertTrue(validator.inspect_midi(malformed, {}, ROOT)[1])

    def test_shipped_report_is_deterministic_and_exposes_known_score_gap(self):
        result = validator.report()
        self.assertEqual(result, validator.report())
        self.assertEqual(result['errorCount'], 0)
        books = {b['bookId']: b for b in result['books']}
        self.assertEqual(sum(b['items'] for b in books.values()), 2876)
        self.assertEqual(books['sda-es-2009']['media']['scoreHymns'], 614)
        self.assertEqual(books['sda-ru-1997']['media']['missingScoreItemIds'], ['244'])
        self.assertEqual(books['sda-es-1962']['media']['scoreHymns'], 0)
        self.assertEqual(result['catalogErrors'], [])
        for book, count in [('sda-es-2009', 614), ('sda-es-1962', 527)]:
            self.assertEqual(len(books[book]['media']['instrumentalRecordingItemIds']), count)
            self.assertEqual(books[book]['media']['missingInstrumentalRecordingItemIds'], [])
        self.assertEqual(len(books['sda-pt-1996']['media']['missingInstrumentalRecordingItemIds']), 610)


if __name__ == '__main__':
    unittest.main()
