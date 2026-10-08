import sys
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tool'))
import build_abre_tu_corazon as builder
from build_verified_tune import events

class AbreTuCorazonTest(unittest.TestCase):
    def test_complete_score_phrase_and_two_clean_verse_endings(self):
        source = (ROOT/'tool/data/midi_sources/spanish-old-164.mid').read_bytes()
        data = builder.build(source)
        self.assertEqual(data, (ROOT/'assets/midi/es-2009-230.mid').read_bytes())
        at = 14
        for index in range(5):
            length = int.from_bytes(data[at+4:at+8], 'big')
            track = events(data[at+8:at+8+length]); at += length+8
            active = set()
            for tick, status, body in track:
                if status & 240 == 144 and body[1]:
                    self.assertNotIn((status&15,body[0]), active)
                    active.add((status&15,body[0]))
                elif status & 240 == 128 or status & 240 == 144 and not body[1]:
                    self.assertIn((status&15,body[0]), active)
                    active.remove((status&15,body[0]))
                if tick in (5640,11400) and status & 240 in (128,144):
                    self.assertFalse(status & 240 == 144 and body[1])
            self.assertFalse(active)
            self.assertEqual(track[-1][0], 11520)
            if index == 1:
                notes = [(t/240,b[0]) for t,s,b in track if s&240==144 and b[1]]
                self.assertEqual(len(notes),60)
                for verse in range(2):
                    phrase = notes[verse*30:(verse+1)*30]
                    self.assertEqual([p for _,p in phrase], [67,63,62,63,65,63,70,67,65,67,68,63,70,72,71,72,68,70,72,70,69,70,67,68,70,67,68,67,65,63])
                    self.assertEqual([t-24*verse for t,_ in phrase], builder.ONSETS)
                    self.assertIn((9+24*verse,63), phrase)
                offs = [t/240 for t,s,b in track if s&240==128 or s&240==144 and not b[1]]
                self.assertIn(23.5,offs);self.assertIn(47.5,offs)

    def test_changed_source_requires_new_review(self):
        with self.assertRaisesRegex(ValueError,'Source changed'):
            builder.build(b'changed source')
