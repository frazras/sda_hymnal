import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class SpanishRecordingsTest(unittest.TestCase):
    def test_complete_pinned_recordings_match_runtime_and_audit(self):
        source = json.loads((ROOT / 'tool/data/spanish_recording_sources.json').read_text())
        runtime = json.loads((ROOT / 'assets/hymnals/spanish_recordings.json').read_text())
        audit = json.loads((ROOT / 'tool/data/spanish_recording_audit.json').read_text())
        self.assertEqual(source, runtime)
        self.assertEqual(source['revision'], audit['revision'])
        validated = {(i['bookId'], i['itemId']): i for i in audit['items']}
        self.assertEqual(len(validated), 1141)
        for book, count, year in [('sda-es-2009', 614, 2009), ('sda-es-1962', 527, 1962)]:
            entries = next(b for b in source['books'] if b['bookId'] == book)
            pack = json.loads((ROOT / f'assets/hymnals/{book}.json').read_text())
            self.assertEqual({i['id'] for i in pack['items']}, {i['itemId'] for i in entries['items']})
            self.assertEqual(len(entries['items']), count)
            self.assertEqual(sum(i['bytes'] for i in entries['items']), entries['totalBytes'])
            for item in entries['items']:
                identity = (book, item['itemId'])
                self.assertEqual(item['gitBlobSha1'], validated[identity]['gitBlobSha1'])
                self.assertGreater(validated[identity]['durationSeconds'], 0)
                self.assertEqual(item['path'], f"music/spanish/{year} version/instrumental/{int(item['itemId']):03}.m4a")

if __name__ == '__main__':
    unittest.main()
