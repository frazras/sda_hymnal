import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('verified_tune', ROOT / 'tool/build_verified_tune.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class VerifiedTuneTest(unittest.TestCase):
    def test_generated_asset_is_reproducible_and_notes_finish(self):
        source = (ROOT / 'assets/midi/108.mid').read_bytes()
        data = tool.build(source)
        self.assertEqual(data, tool.DEST.read_bytes())
        offset = 14
        for track in range(14):
            length = int.from_bytes(data[offset+4:offset+8], 'big')
            events = tool.events(data[offset+8:offset+8+length])
            active = set()
            for tick, status, body in events:
                key = (status & 15, body[0])
                if status & 240 == 144 and body[1]:
                    self.assertNotIn(key, active, (track, tick))
                    active.add(key)
                elif status & 240 == 128 or (status & 240 == 144 and not body[1]):
                    self.assertIn(key, active, (track, tick))
                    active.remove(key)
            self.assertFalse(active)
            self.assertLessEqual(events[-1][0], 174 * 384)
            if track == 1:
                starts = [tick for tick, status, body in events
                          if status & 240 == 144 and body[1]
                          and body[0] == 60 and tick in [29*384,77*384,125*384]]
                self.assertEqual(starts, [29*384,77*384,125*384])
            offset += 8 + length
        self.assertEqual(offset, len(data))

    def test_source_change_requires_new_review(self):
        data = bytearray((ROOT / 'assets/midi/108.mid').read_bytes())
        data[-1] ^= 1
        with self.assertRaisesRegex(ValueError, 'Source changed'):
            tool.build(data)


if __name__ == '__main__':
    unittest.main()
