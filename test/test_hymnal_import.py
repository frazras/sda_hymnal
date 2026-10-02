import copy
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('import_hymnals', ROOT / 'tool/import_hymnals.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class HymnalImportTest(unittest.TestCase):
    def setUp(self):
        self.book = dict(id='test-es', languageTag='es', displayName='Español',
                         year=2009, expectedCount=2)
        self.lyrics = [dict(number=1, title='Señor', content='1.\nLínea uno.\n\nCoro:\n¡Gloria!'),
                       dict(number=2, title='Всё', content='Славьте Бога!')]
        self.topics = [dict(thematic='Grupo', ambits=[dict(ambit='Tema', star=1, end=2)])]

    def build(self):
        return importer.build_pack(self.book, self.lyrics, self.topics,
                                   dict(revision='pinned'))

    def test_shipped_packs_match_verified_sources_offline(self):
        importer.build(check=True)

    def test_unicode_credits_and_source_text_survive(self):
        self.lyrics[0]['author'] = 'Letra: José'
        pack = self.build()
        self.assertEqual(pack['items'][0]['sourceText'], self.lyrics[0]['content'])
        self.assertEqual(pack['items'][0]['credits'], 'Letra: José')
        self.assertEqual(pack['items'][0]['blocks'], [
            dict(kind='verse', label='1.', text='Línea uno.'),
            dict(kind='refrain', label='Coro:', text='¡Gloria!')])
        self.assertEqual(pack['items'][1]['title'], 'Всё')
        self.assertEqual(pack['topics'][0]['itemIds'], ['1', '2'])

    def test_missing_duplicate_empty_or_invalid_records_are_rejected(self):
        original = copy.deepcopy(self.lyrics)
        for bad in [dict(number=1), dict(number=0), dict(number=3),
                    dict(number=True), dict(title=' '), dict(content=''),
                    dict(content='Bad\ufffdencoding')]:
            with self.subTest(bad=bad):
                self.lyrics = copy.deepcopy(original)
                self.lyrics[1].update(bad)
                with self.assertRaises(ValueError):
                    self.build()

    def test_missing_topic_references_are_rejected(self):
        self.topics[0]['ambits'][0]['end'] = 3
        with self.assertRaises(ValueError):
            self.build()

    def test_hash_and_size_both_must_match(self):
        data = b'[]'
        source = dict(path='source.json', bytes=2,
                      sha256=importer.hashlib.sha256(data).hexdigest())
        self.assertEqual(importer.verified(data, source), [])
        for modified in [b'{}', b'[]\n']:
            with self.assertRaises(ValueError):
                importer.verified(modified, source)

    def test_refrains_are_not_inserted_or_reordered(self):
        source = 'Primera estrofa\n\nCoro:\nRespuesta\n\nSegunda estrofa'
        blocks = importer.lyric_blocks(source)
        self.assertEqual([block['kind'] for block in blocks], ['verse', 'refrain', 'verse'])
        self.assertEqual(blocks[-1]['text'], 'Segunda estrofa')
        self.assertEqual(importer.lyric_blocks('Coro celestial canta')[0]['text'],
                         'Coro celestial canta')


if __name__ == '__main__':
    unittest.main()
