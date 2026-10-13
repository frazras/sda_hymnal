import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


builder = load('recording_catalog', 'tool/build_recording_catalog.py')
validator = load('content_report', 'tool/validate_hymnal_content.py')

# Files per exact book and medium at isax5/hymnal dc744ac; none are missing.
EXPECTED = {
    ('sda-es-2009', 'instrumentalRecording'): 614,
    ('sda-es-1962', 'instrumentalRecording'): 527,
}
# SHA-256 of the Spanish instrumental entries audited on 2026-10-07 (canonical JSON).
SPANISH_INSTRUMENTAL = '7dafc1074c7a5c2eb4638c52782dcc6fe5be3f18c355ac877a74a643769b48db'


class RecordingCatalogTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((ROOT / 'tool/data/recording_sources.json').read_text())
        cls.runtime = json.loads((ROOT / 'assets/hymnals/recordings.json').read_text())
        cls.audit = json.loads((ROOT / 'tool/data/recording_audit.json').read_text())
        cls.collections = {(c['bookId'], c['medium']): c for c in cls.source['collections']}

    def test_runtime_catalog_and_dart_table_match_reviewed_sources(self):
        self.assertEqual(self.source, self.runtime)
        self.assertEqual((ROOT / builder.DART).read_text(), builder.render_dart(self.source))

    def test_every_file_is_exact_edition_complete_and_audited(self):
        self.assertEqual(self.source['revision'], self.audit['revision'])
        audited = {(c['bookId'], c['medium']): {i['itemId']: i for i in c['items']}
                   for c in self.audit['collections']}
        self.assertEqual(set(self.collections), set(EXPECTED))
        self.assertEqual(set(audited), set(EXPECTED))
        for key, count in EXPECTED.items():
            with self.subTest(collection=key):
                collection = self.collections[key]
                pack = json.loads((ROOT / f'assets/hymnals/{key[0]}.json').read_text())
                entries = {i['itemId'] for i in collection['items']}
                self.assertEqual(entries | set(collection['missingItemIds']),
                                 {i['id'] for i in pack['items']})
                self.assertEqual((len(entries), collection['missingItemIds']), (count, []))
                self.assertEqual(collection['expectedCount'], count)
                self.assertEqual(sum(i['bytes'] for i in collection['items']), collection['totalBytes'])
                settings_id, directory = validator.RECORDING_SOURCES[key]
                self.assertEqual((collection['settingsId'], collection['directory']),
                                 (settings_id, directory))
                self.assertEqual(set(audited[key]), entries)
                for item in collection['items']:
                    result = audited[key][item['itemId']]
                    self.assertEqual(item['path'], f"{directory}/{int(item['itemId']):03}.m4a")
                    self.assertEqual(result['gitBlobSha1'], item['gitBlobSha1'])
                    self.assertGreater(result['durationSeconds'], 0)

    def test_media_stay_in_their_own_source_directories(self):
        paths = [i['path'] for c in self.source['collections'] for i in c['items']]
        self.assertEqual(len(paths), len(set(paths)))
        for (book, medium), collection in self.collections.items():
            segment = '/sung/' if medium == 'sungRecording' else '/instrumental/'
            self.assertTrue(all(segment in i['path'] for i in collection['items']), (book, medium))

    def test_spanish_instrumental_entries_are_unchanged(self):
        spanish = [{k: c[k] for k in ('bookId', 'expectedCount', 'totalBytes', 'items')}
                   for c in self.source['collections']
                   if c['medium'] == 'instrumentalRecording' and c['bookId'].startswith('sda-es-')]
        canonical = json.dumps(spanish, sort_keys=True, separators=(',', ':'))
        self.assertEqual(hashlib.sha256(canonical.encode()).hexdigest(), SPANISH_INSTRUMENTAL)

    def test_enumeration_reproduces_entries_and_lists_gaps(self):
        collection = self.collections[('sda-es-1962', 'instrumentalRecording')]
        tree = dict(truncated=False, tree=[
            dict(path=self.source['settingsPath'], type='blob', sha=self.source['settingsGitBlobSha1'], size=1)] + [
            dict(path=i['path'], type='blob', sha=i['gitBlobSha1'], size=i['bytes'])
            for i in collection['items'] if i['itemId'] != '244'])
        settings = [dict(Id='es-oldVersion', InstrumentalMusicUrl=(
            'https://isax5.github.io/hymnal/music/spanish/1962%20version/instrumental/###.m4a'))]
        manifest = dict(self.source, collections=[collection])
        result = builder.enumerate_collections(manifest, tree, settings, ROOT)['collections'][0]
        self.assertEqual(result['missingItemIds'], ['244'])
        self.assertEqual(result['items'], [i for i in collection['items'] if i['itemId'] != '244'])
        self.assertEqual(result['expectedCount'], 526)
        self.assertEqual(collection['missingItemIds'], [], 'source manifest must not be mutated')
        for change in [dict(InstrumentalMusicUrl=None), dict(Id='es-newVersion')]:
            with self.subTest(settings=change), self.assertRaises((ValueError, KeyError)):
                builder.enumerate_collections(manifest, tree, [dict(settings[0], **change)], ROOT)
        extra = dict(tree, tree=tree['tree'] + [dict(path=collection['directory'] + '/528.m4a',
                                                      type='blob', sha='0' * 40, size=1)])
        with self.assertRaises(ValueError):
            builder.enumerate_collections(manifest, extra, settings, ROOT)
        moved = dict(tree, tree=[dict(e, sha='0' * 40) if e['path'] == self.source['settingsPath'] else e
                                 for e in tree['tree']])
        with self.assertRaises(ValueError):
            builder.enumerate_collections(manifest, moved, settings, ROOT)

    def test_availability_ranges_compress_gaps(self):
        self.assertEqual(builder.ranges([1, 2, 3, 5, 7, 8]), [[1, 3], [5, 5], [7, 8]])
        catalog = dict(collections=[dict(bookId='sda-ru-1997', medium='sungRecording',
                                         items=[dict(itemId=str(n)) for n in range(1, 200, 2)])])
        dart = builder.render_dart(catalog)
        self.assertIn('RecordingKind.sung: [\n      (1, 1),\n', dart)
        self.assertTrue(all(len(line) <= 80 for line in dart.splitlines()))


if __name__ == '__main__':
    unittest.main()
