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

    def test_duplicate_topic_members_are_rejected(self):
        self.pack['topics'][0]['itemIds'].append('1')
        self.assertEqual(self.codes(self.pack), {'duplicate_topic_reference'})

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
            write('assets/hymnals/recordings.json', dict(
                schemaVersion=2, repository='owner/repo', revision='a'*40,
                collections=[dict(bookId='unknown', medium='sungRecording', expectedCount=1,
                                  totalBytes=100, missingItemIds=[],
                                  items=[dict(itemId='1', path='wrong.m4a', bytes=100,
                                              gitBlobSha1='b'*40)])]))
            result = validator.report(root)
            self.assertIn('absent_recording_book',
                          {e['code'] for e in result['catalogErrors']})
            self.assertEqual(result['errorCount'], len(result['catalogErrors']) +
                             sum(len(book['errors']) for book in result['books']))
            media = result['books'][0]['media']
            self.assertEqual((media['instrumentalRecordingItemIds'], media['sungRecordingItemIds']), ([], []))
            self.assertEqual(media['missingSungRecordingItemIds'], ['1'])

    @staticmethod
    def recording_catalog(medium='instrumentalRecording', book='sda-es-2009',
                          settings='es-newVersion', directory='music/spanish/2009 version/instrumental'):
        item = dict(itemId='1', path=f'{directory}/001.m4a', bytes=100, gitBlobSha1='a' * 40)
        return dict(schemaVersion=2, repository='owner/repo', revision='b' * 40, collections=[dict(
            bookId=book, medium=medium, settingsId=settings, directory=directory,
            expectedCount=1, totalBytes=100, missingItemIds=['2'], items=[item])])

    def test_recording_metadata_rejects_wrong_edition_duplicates_and_bad_hashes(self):
        catalog = self.recording_catalog()
        item = catalog['collections'][0]['items'][0]
        identities = {'sda-es-2009': {'1', '2'}}
        available, errors = validator.inspect_recordings(catalog, identities)
        self.assertEqual(errors, [])
        self.assertEqual(available, {('sda-es-2009', 'instrumentalRecording'): {'1'}})
        before = copy.deepcopy(catalog)
        bad = copy.deepcopy(catalog)
        bad['collections'][0]['items'].append(copy.deepcopy(item))
        bad['collections'][0]['items'][1]['gitBlobSha1'] = 'not-a-hash'
        bad['collections'][0]['items'].append(dict(
            itemId='999', path='../another-book.m4a', bytes=True, gitBlobSha1='a'*40))
        available, errors = validator.inspect_recordings(bad, identities)
        self.assertTrue({'duplicate_recording_reference', 'absent_recording_reference',
                         'invalid_recording_path', 'invalid_recording_integrity',
                         'recording_count_mismatch', 'recording_bytes_mismatch'} <=
                        {e['code'] for e in errors})
        self.assertEqual(available[('sda-es-2009', 'instrumentalRecording')], set())
        self.assertEqual(catalog, before)
        bad = copy.deepcopy(catalog)
        bad['collections'][0]['items'][0]['path'] = 'music/spanish/1962 version/instrumental/001.m4a'
        available, errors = validator.inspect_recordings(bad, identities)
        self.assertEqual(available[('sda-es-2009', 'instrumentalRecording')], set())
        self.assertEqual(errors[0]['code'], 'invalid_recording_path')
        bad['collections'][0]['bookId'] = 'unknown'
        _, errors = validator.inspect_recordings(bad, identities)
        self.assertIn('absent_recording_book', {e['code'] for e in errors})

    def test_sung_and_instrumental_files_cannot_stand_in_for_each_other(self):
        identities = {'sda-es-2009': {'1', '2'}, 'sda-pt-1996': {'1', '2'}, 'sda-ru-1997': {'1', '2'}}
        sung = self.recording_catalog('sungRecording', directory='music/spanish/2009 version/sung')
        available, errors = validator.inspect_recordings(sung, identities)
        self.assertEqual((available, errors), ({('sda-es-2009', 'sungRecording'): {'1'}}, []))
        both = copy.deepcopy(sung)
        both['collections'] += self.recording_catalog()['collections']
        available, errors = validator.inspect_recordings(both, identities)
        self.assertEqual(errors, [])
        self.assertEqual(set(available), {('sda-es-2009', 'sungRecording'),
                                          ('sda-es-2009', 'instrumentalRecording')})
        for change, code in [
                (dict(directory='music/spanish/2009 version/instrumental'), 'invalid_recording_source'),
                (dict(settingsId='es-oldVersion'), 'invalid_recording_source'),
                (dict(medium='vocalGuess'), 'invalid_recording_collection'),
                (dict(bookId='sda-ru-1997'), 'unreviewed_recording_source')]:
            with self.subTest(change=change):
                bad = copy.deepcopy(sung)
                bad['collections'][0].update(change)
                available, errors = validator.inspect_recordings(bad, identities)
                self.assertIn(code, {e['code'] for e in errors})
                self.assertFalse(any(available.values()))
        # A Portuguese sung file cannot be reused for Russian instrumental playback.
        borrowed = self.recording_catalog(book='sda-ru-1997', settings='ru-newVersion',
                                          directory='music/portuguese/1996 version/sung')
        available, errors = validator.inspect_recordings(borrowed, identities)
        self.assertTrue({'invalid_recording_source', 'invalid_recording_path'} <= {e['code'] for e in errors})
        self.assertEqual(available[('sda-ru-1997', 'instrumentalRecording')], set())
        duplicate = copy.deepcopy(sung)
        duplicate['collections'].append(copy.deepcopy(sung['collections'][0]))
        self.assertIn('duplicate_recording_collection',
                      {e['code'] for e in validator.inspect_recordings(duplicate, identities)[1]})

    def test_missing_recordings_must_be_declared_gaps(self):
        identities = {'sda-es-2009': {'1', '2', '3'}}
        catalog = self.recording_catalog()
        _, errors = validator.inspect_recordings(catalog, identities)
        self.assertEqual(errors, [dict(code='undeclared_recording_gap',
                                       location='sda-es-2009:instrumentalRecording:3')])
        for gaps in [['2', '3', '3'], ['1', '2', '3'], ['2', '3', '4'], None]:
            with self.subTest(gaps=gaps):
                bad = copy.deepcopy(catalog)
                bad['collections'][0]['missingItemIds'] = gaps
                codes = {e['code'] for e in validator.inspect_recordings(bad, identities)[1]}
                self.assertTrue(codes & {'invalid_recording_gap', 'invalid_recording_gaps'})

    def test_recording_shapes_and_provenance_fail_without_crashing(self):
        for catalog in [None, [], {}, dict(schemaVersion=1, books=[]),
                        dict(schemaVersion=2, collections=None),
                        dict(schemaVersion=2, collections=[None, {}])]:
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

    def test_optional_publication_checks_hash_numbering_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def write(name, value):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(json.dumps(value))
                return path.read_bytes()
            pack = copy.deepcopy(self.pack)
            pack['book']['id'] = 'sda-ny-example'
            data = write('resources/hymnals/sda-ny-example.json', pack)
            write('assets/hymnals/catalog.json', {'books': []})
            write('tool/data/hymnal_sources.json', {'books': []})
            write('assets/sheet_music/catalog.json', {'books': {}})
            book = dict(bookId='sda-ny-example', path='resources/hymnals/sda-ny-example.json',
                        bytes=len(data), sha256=hashlib.sha256(data).hexdigest(),
                        hymnCount=1, topicCount=1, displayName='Prueba', languageTag='es', year=None)
            write('assets/hymnals/downloads.json', {'books': [book]})
            manifest = dict(book={'id': 'sda-ny-example'}, expectedNumbers=[1])
            write('tool/data/structured_sources/optional.manifest.json', manifest)
            result = validator.report(root)
            self.assertEqual(result['errorCount'], 0)
            self.assertTrue(result['books'][0]['optionalDownload'])
            write('tool/data/structured_sources/optional.manifest.json', dict(manifest, expectedNumbers=[1, 2]))
            self.assertIn('missing_number', {e['code'] for e in validator.report(root)['books'][0]['errors']})
            write('tool/data/structured_sources/optional.manifest.json', manifest)
            for field, invalid in [('sha256', '0' * 64), ('displayName', 'Wrong edition'), ('hymnCount', 2)]:
                write('assets/hymnals/downloads.json', {'books': [dict(book, **{field: invalid})]})
                errors = validator.report(root)['books'][0]['errors']
                self.assertIn({'code': 'catalog_mismatch', 'location': field}, errors)
            write('assets/hymnals/downloads.json', {'books': [book, book]})
            self.assertIn('duplicate_optional_book', {e['code'] for e in validator.report(root)['catalogErrors']})
            (root / book['path']).unlink()
            self.assertIn('unreadable_pack', {e['code'] for e in validator.report(root)['books'][0]['errors']})

    def test_shipped_report_is_deterministic_and_exposes_known_score_gap(self):
        result = validator.report()
        self.assertEqual(result, validator.report())
        self.assertEqual(result['errorCount'], 0)
        books = {b['bookId']: b for b in result['books']}
        self.assertEqual(sum(b['items'] for b in books.values()), 3226)
        self.assertEqual(books['sda-es-2009']['media']['scoreHymns'], 614)
        self.assertEqual(books['sda-ru-1997']['media']['missingScoreItemIds'], ['244'])
        self.assertEqual(books['sda-es-1962']['media']['scoreHymns'], 0)
        self.assertEqual(result['catalogErrors'], [])
        self.assertTrue(books['sda-ny-khristu-mu-nyimbo']['optionalDownload'])
        self.assertEqual(books['sda-ny-khristu-mu-nyimbo']['items'], 350)
        self.assertEqual(len(books['sda-ny-khristu-mu-nyimbo']['media']['missingScoreItemIds']), 350)
        for book, count in [('sda-es-2009', 614), ('sda-es-1962', 527), ('sda-ru-1997', 385)]:
            self.assertEqual(len(books[book]['media']['instrumentalRecordingItemIds']), count)
            self.assertEqual(books[book]['media']['missingInstrumentalRecordingItemIds'], [])
        for book, count in [('sda-es-2009', 614), ('sda-pt-1996', 610)]:
            self.assertEqual(len(books[book]['media']['sungRecordingItemIds']), count)
            self.assertEqual(books[book]['media']['missingSungRecordingItemIds'], [])
        self.assertEqual(len(books['sda-pt-1996']['media']['missingInstrumentalRecordingItemIds']), 610)
        for book, count in [('sda-es-1962', 527), ('sda-ru-1997', 385), ('sda-fr-hymnes-et-louanges', 520)]:
            self.assertEqual(len(books[book]['media']['missingSungRecordingItemIds']), count)


if __name__ == '__main__':
    unittest.main()
