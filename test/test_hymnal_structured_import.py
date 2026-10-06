import copy
import importlib.util
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

    def test_pinned_full_sources_regenerate_offline_and_detect_stale_output(self):
        for name, count in [('french', 520), ('tagalog', 237), ('swahili', 220)]:
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


if __name__ == '__main__':
    unittest.main()
