import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
from build_score_download_catalog import build


class ScoreDownloadCatalogTest(unittest.TestCase):
    def test_committed_catalog_is_reproducible(self):
        self.assertEqual(build(), json.loads((ROOT / 'assets/sheet_music/downloads.json').read_text()))
        self.assertEqual([book['pageCount'] for book in build()['books']], [723, 614, 506])

    def fixture(self, root):
        source = json.loads((ROOT / 'tool/data/score_download_sources.json').read_text())
        catalog = json.loads((ROOT / 'assets/sheet_music/catalog.json').read_text())
        page = copy.deepcopy(catalog['books']['sda-en-1985']['hymns']['1'][0])
        catalog['books'] = {'sda-en-1985': {'title': 'English', 'hymns': {'1': [page]}}}
        (root / 'tool/data').mkdir(parents=True)
        (root / 'assets/sheet_music').mkdir(parents=True)
        (root / 'tool/data/score_download_sources.json').write_text(json.dumps(source))
        (root / 'assets/sheet_music/catalog.json').write_text(json.dumps(catalog))
        target = root / page['asset']
        target.parent.mkdir(parents=True)
        target.write_bytes((ROOT / page['asset']).read_bytes())
        return source, catalog, target

    def test_changed_page_fails_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, _, page = self.fixture(root)
            self.assertEqual(build(root)['books'][0]['pageCount'], 1)
            page.write_bytes(b'corrupt')
            with self.assertRaises(ValueError):
                build(root)

    def test_invalid_identity_and_coverage_fail_before_publication(self):
        for mutation in ('mutable', 'duplicate', 'directory', 'number', 'dimension'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, catalog, _ = self.fixture(root)
                hymns = catalog['books']['sda-en-1985']['hymns']
                if mutation == 'mutable':
                    source['revision'] = 'main'
                elif mutation == 'duplicate':
                    hymns['2'] = hymns['1']
                elif mutation == 'directory':
                    hymns['1'][0]['asset'] = '../outside.png'
                elif mutation == 'number':
                    hymns['01'] = hymns.pop('1')
                else:
                    hymns['1'][0]['width'] += 1
                (root / 'tool/data/score_download_sources.json').write_text(json.dumps(source))
                (root / 'assets/sheet_music/catalog.json').write_text(json.dumps(catalog))
                with self.assertRaises(ValueError):
                    build(root)
