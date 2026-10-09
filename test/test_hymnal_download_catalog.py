import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('download_catalog', ROOT / 'tool/build_language_download_catalog.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class DownloadCatalogTest(unittest.TestCase):
    def test_shipped_catalog_is_deterministic_and_pins_all_six_text_objects(self):
        catalog = builder.build()
        self.assertEqual(catalog, builder.build())
        self.assertEqual(catalog, json.loads(builder.DEST.read_text()))
        self.assertEqual(len(catalog['books']), 6)
        for book in catalog['books']:
            self.assertIn(catalog['source']['revision'], book['url'])
            self.assertTrue(book['url'].endswith(f'/assets/hymnals/{book["bookId"]}.json'))
            self.assertGreater(book['hymnCount'], 0)
            self.assertIn('note', book['coverage'])
            self.assertNotIn('audio', book)

    def test_unpinned_source_and_stale_catalog_fail_before_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tool/data').mkdir(parents=True)
            (root / 'assets/hymnals').mkdir(parents=True)
            source = json.loads((ROOT / 'tool/data/language_download_sources.json').read_text())
            original = json.loads((ROOT / 'assets/hymnals/catalog.json').read_text())
            entry = original['books'][0]
            (root / entry['asset']).write_bytes((ROOT / entry['asset']).read_bytes())
            def save(metadata, catalog):
                (root / 'tool/data/language_download_sources.json').write_text(json.dumps(metadata))
                (root / 'assets/hymnals/catalog.json').write_text(json.dumps(catalog))
            save(source, dict(books=[entry]))
            self.assertEqual(len(builder.build(root)['books']), 1)
            bad_source = dict(source, revision='main')
            save(bad_source, dict(books=[entry]))
            with self.assertRaises(ValueError):
                builder.build(root)
            for field, value in [('bytes', entry['bytes'] + 1), ('sha256', 'a'*64),
                                 ('asset', '../outside'), ('hymnCount', 1), ('topicCount', 0)]:
                changed = copy.deepcopy(entry)
                changed[field] = value
                save(source, dict(books=[changed]))
                with self.subTest(field=field), self.assertRaises(ValueError):
                    builder.build(root)
            save(source, dict(books=[entry, entry]))
            with self.assertRaises(ValueError):
                builder.build(root)


if __name__ == '__main__':
    unittest.main()
