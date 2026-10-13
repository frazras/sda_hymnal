import copy
import importlib.util
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
spec = importlib.util.spec_from_file_location('structured', ROOT / 'tool/import_structured_hymnals.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class StructuredImportTest(unittest.TestCase):
    def setUp(self):
        self.manifest = dict(format='videopsalm', expectedNumbers=[4],
                             book=dict(id='review', languageTag='fr', displayName='Français'),
                             source=dict(repository='example/book', revision='pinned',
                                         path='book.json', sha256='hash'),
                             structurallyComplete=False, coverageNote='Partial')
        self.record = dict(ID=4, Guid='source-guid', Text='Grâce',
                           Verses=[dict(Text='Première'), dict(Tag=1, Text='Réponse'),
                                   dict(ID=2, Text='Deuxième'), dict(Tag=1, Text='Réponse')])
        self.source = dict(Songs=[self.record])

    def test_videopsalm_retains_order_guids_and_repeated_occurrences(self):
        pack = importer.convert(self.source, self.manifest)
        item = pack['items'][0]
        self.assertEqual(item['sourceRecord'], self.record)
        self.assertEqual([b['text'] for b in item['blocks']],
                         ['Première', 'Réponse', 'Deuxième', 'Réponse'])
        self.assertTrue(all(b['kind'] == 'verse' for b in item['blocks']))
        self.manifest['refrainTags'] = [1]
        mapped = importer.convert(self.source, self.manifest)['items'][0]
        self.assertEqual([b['kind'] for b in mapped['blocks']],
                         ['verse', 'refrain', 'verse', 'refrain'])

    def test_structured_pages_keep_refrain_once_without_enabling_links(self):
        self.manifest.update(format='structured-verses', sourceLanguage='tagalog')
        source = [dict(pageNumber=4, language='tagalog', title='Awit',
                       verses=[dict(number=1, lines=['Una', 'Ikalawa']),
                               dict(number=2, lines=['Huli'])],
                       refrain=dict(lines=['Tugon', '', 'Wakas']), link='https://example.invalid/audio.mp3')]
        item = importer.convert(source, self.manifest)['items'][0]
        self.assertEqual(item['id'], '4')
        self.assertEqual([b['text'] for b in item['blocks']], ['Una\nIkalawa', 'Huli', 'Tugon\n\nWakas'])
        self.assertEqual(item['sourceRecord'], source[0])
        self.assertNotIn('audio', item)
        self.manifest['sourceLanguage'] = 'cebuano'
        with self.assertRaises(ValueError):
            importer.convert(source, self.manifest)

    def test_duplicate_empty_and_unexpected_records_fail(self):
        cases = [
            dict(Songs=[self.record, self.record]),
            dict(Songs=[dict(self.record, ID=True)]),
            dict(Songs=[dict(self.record, ID=5)]),
            dict(Songs=[dict(self.record, Verses=[dict(Text='')])]),
            dict(Songs=[]),
        ]
        for source in cases:
            with self.subTest(source=source), self.assertRaises(ValueError):
                importer.convert(source, self.manifest)

    def test_reviewed_omissions_withhold_only_unpublishable_or_repeated_records(self):
        songs = [self.record,
                 dict(ID=5, Guid='empty', Text='Vide', Verses=[]),
                 dict(ID=6, Guid='damaged', Text='Abîmé', Verses=[dict(Text='Per\ufffdu')]),
                 dict(ID=4, Guid='lettered', Text='(a) Variante', Verses=[dict(Text='Autre')]),
                 dict(ID=7, Guid='copy', Text='Autre titre', Verses=copy.deepcopy(self.record['Verses']))]

        def omit(number, guid, title, kind, **extra):
            return dict(number=number, guid=guid, title=title, kind=kind,
                        reason='Checked both source files', reviewer='Source reviewer', **extra)
        valid = [omit(5, 'empty', 'Vide', 'empty'), omit(6, 'damaged', 'Abîmé', 'invalidText'),
                 omit(4, 'lettered', '(a) Variante', 'duplicateNumber'),
                 omit(7, 'copy', 'Autre titre', 'duplicateLyrics', lyricsOf=4)]
        self.manifest['omittedRecords'] = valid
        pack = importer.convert(dict(Songs=songs), self.manifest)
        self.assertEqual([item['sourceRecord']['Guid'] for item in pack['items']], ['source-guid'])
        self.assertEqual(pack['coverage']['sourceRecords'], 5)
        same_title = copy.deepcopy(songs)
        same_title[4]['Text'] = 'Grâce'
        cases = [
            ('publishable record', songs, valid[:3] + [dict(valid[3], kind='empty')]),
            ('wrong condition', songs, [omit(5, 'empty', 'Vide', 'invalidText')] + valid[1:]),
            ('no retained number', songs, valid + [omit(4, 'source-guid', 'Grâce', 'duplicateNumber')]),
            ('lyric source withheld', songs, valid[:3] + [dict(valid[3], lyricsOf=6)]),
            ('same title retained', same_title, valid[:3] + [dict(valid[3], title='Grâce')]),
            ('unmatched record', songs, valid[:3] + [dict(valid[3], guid='other')]),
            ('listed twice', songs, valid + [valid[0]]),
            ('missing reviewer', songs, valid[:3] + [dict(valid[3], reviewer='')]),
            ('unknown kind', songs, valid[:3] + [dict(valid[3], kind='typo')]),
        ]
        for label, source, omissions in cases:
            with self.subTest(label), self.assertRaises(ValueError):
                importer.convert(dict(Songs=source), dict(self.manifest, omittedRecords=omissions))
        with self.assertRaises(ValueError):
            importer.convert(dict(Songs=songs), dict(self.manifest, expectedNumbers=[4, 5]))

    def test_structured_pages_can_withhold_records_without_lyrics(self):
        self.manifest.update(format='structured-verses', sourceLanguage='english', expectedNumbers=[2])
        source = [dict(pageNumber=1, language='english', title='Blank', verses=[]),
                  dict(pageNumber=2, language='english', title='Song', verses=[dict(number=1, lines=['Line'])])]
        with self.assertRaises(ValueError):
            importer.convert(source, self.manifest)
        self.manifest['omittedRecords'] = [dict(number=1, title='Blank', kind='empty',
                                                reason='No lyrics', reviewer='Source reviewer')]
        self.assertEqual([item['number'] for item in importer.convert(source, self.manifest)['items']], [2])

    def test_reviewed_override_is_guarded_and_retains_original(self):
        pack = importer.convert(self.source, self.manifest)
        before = copy.deepcopy(pack)
        overrides = dict(sourceRevision='pinned', changes=[
            dict(itemId='4', field='title', before='Grâce', after='Grâce corrigée',
                 reviewer='Content reviewer', reason='Checked printed title')])
        result = importer.apply_overrides(pack, overrides)
        self.assertEqual(pack, before)
        self.assertEqual(result['items'][0]['sourceRecord']['Text'], 'Grâce')
        self.assertEqual(result['items'][0]['title'], 'Grâce corrigée')
        for field, value in [('before', 'Stale'), ('field', 'number'),
                             ('reviewer', ''), ('after', '')]:
            bad = copy.deepcopy(overrides)
            bad['changes'][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                importer.apply_overrides(pack, bad)
        overrides['sourceRevision'] = 'changed'
        with self.assertRaises(ValueError):
            importer.apply_overrides(pack, overrides)

    def test_lyric_override_updates_search_text_without_mutating_source(self):
        pack = importer.convert(self.source, self.manifest)
        before = copy.deepcopy(pack)
        overrides = dict(sourceRevision='pinned', changes=[
            dict(itemId='4', field='blocks', before=pack['items'][0]['blocks'],
                 after=[dict(kind='verse', text='Texte corrigé'),
                        dict(kind='refrain', text='Nouvelle réponse')],
                 reviewer='Content reviewer', reason='Checked printed lyrics')])
        result = importer.apply_overrides(pack, overrides)
        self.assertEqual(result['items'][0]['sourceText'], 'Texte corrigé\n\nNouvelle réponse')
        self.assertEqual(result['items'][0]['sourceRecord'], self.record)
        self.assertEqual(result['reviewedOverrides'], overrides)
        self.assertEqual(pack, before)
        for replacement in [[], [dict(kind='verse', text='')], [None]]:
            bad = copy.deepcopy(overrides)
            bad['changes'][0]['after'] = replacement
            with self.assertRaises(ValueError):
                importer.apply_overrides(pack, bad)

    def test_build_returns_the_corrected_pack_it_writes_and_checks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            snapshot = root / 'source.json'
            snapshot.write_text(json.dumps(self.source))
            manifest = copy.deepcopy(self.manifest)
            manifest['snapshot'] = 'source.json'
            manifest['source'].update(bytes=snapshot.stat().st_size,
                                      sha256=hashlib.sha256(snapshot.read_bytes()).hexdigest())
            manifest_path = root / 'manifest.json'
            manifest_path.write_text(json.dumps(manifest))
            overrides = dict(sourceRevision='pinned', changes=[
                dict(itemId='4', field='title', before='Grâce', after='Titre corrigé',
                     reviewer='Reviewer', reason='Printed title')])
            override_path = root / 'overrides.json'
            override_path.write_text(json.dumps(overrides))
            output = root / 'pack.json'
            result = importer.build(manifest_path, output, override_path)
            self.assertEqual(result, json.loads(output.read_text()))
            self.assertEqual(result['items'][0]['title'], 'Titre corrigé')
            self.assertEqual(importer.build(manifest_path, output, override_path, check=True), result)

    def test_pinned_full_sources_regenerate_offline_and_detect_stale_output(self):
        for name, count in [('french', 520), ('tagalog', 237), ('swahili', 220), ('cebuano', 237), ('chichewa', 350),
                            ('icibemba', 311), ('isizulu-ndebele', 300), ('kalenjin', 245), ('kikuyu', 299),
                            ('kinyarwanda', 500), ('sepedi', 303), ('shona', 300), ('tswana', 300),
                            ('venda', 306), ('xhosa', 352), ('xitsonga', 311), ('kamba', 469), ('maasai', 243),
                            ('dholuo', 329), ('ekegusii', 365), ('sotho', 268), ('tonga', 339),
                            ('tumbuka', 352), ('twi', 751)]:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                manifest = ROOT / f'tool/data/structured_sources/{name}.manifest.json'
                output = Path(directory) / 'pack.json'
                pack = importer.build(manifest, output)
                self.assertEqual(len(pack['items']), count)
                importer.build(manifest, output, check=True)
                self.assertEqual(json.loads(output.read_text())['items'], pack['items'])
                output.write_text('{}')
                with self.assertRaises(ValueError):
                    importer.build(manifest, output, check=True)

    def test_published_optional_packs_regenerate_from_one_manifest(self):
        sources = json.loads((ROOT / 'tool/data/language_download_sources.json').read_text())
        manifests = {}
        for path in sorted((ROOT / 'tool/data/structured_sources').glob('*.manifest.json')):
            manifests.setdefault(json.loads(path.read_text())['book']['id'], []).append(path)
        self.assertEqual(len(sources['optionalPacks']), len(set(sources['optionalPacks'])))
        for asset in sources['optionalPacks']:
            with self.subTest(asset=asset):
                identity = Path(asset).stem
                self.assertEqual(len(manifests.get(identity, [])), 1)
                pack = importer.build(manifests[identity][0], ROOT / asset, check=True)
                book = pack['book']
                # The app parser requires the tag to match the identity segment.
                self.assertEqual(book['id'], identity)
                self.assertEqual(book['languageTag'], identity.split('-')[1])
                self.assertIsNone(book['year'])
                self.assertEqual(pack['topics'], [])
                self.assertTrue(all(item['id'] == str(item['number']) for item in pack['items']))


if __name__ == '__main__':
    unittest.main()
