"""Standard-library checks for the Apple-compatible SoundFont preparation.

Run: python3 -m unittest discover -s test -p 'test_ios_soundfont.py'
"""

import importlib.util
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_ios_soundfont", ROOT / "tool/prepare_ios_soundfont.py")
sf = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = sf
SPEC.loader.exec_module(sf)


def pack_generators(rows):
    return b"".join(struct.pack("<HH", generator, value & 0xFFFF) for generator, value in rows)


def fixture():
    """Two presets share a three-sample instrument with globals and modulators."""
    preset_zones = [
        [(48, 30)],
        [(43, 50 << 8), (44, 90 << 8), (38, -569), (41, 0)],
        [(43, 40 | 127 << 8), (44, 80 | 127 << 8), (38, -617), (41, 0)],
        [(41, 0)],
    ]
    instrument_zones = [
        [(34, -8000), (38, 667), (54, 1)],
        [(43, 20 << 8), (53, 0)],
        [(43, 40 | 60 << 8), (44, 100 << 8), (38, 814), (53, 1)],
        [(43, 61 | 127 << 8), (44, 110 | 127 << 8), (53, 2)],
    ]
    mod = struct.pack("<HHhHH", 2, 48, 200, 0, 0)
    def zone_tables(zones):
        bags, gens, mods = [], [], []
        for index, zone in enumerate(zones):
            bags.append(struct.pack("<HH", len(gens), len(mods)))
            gens.extend(zone)
            if index < 2:
                mods.append(mod)
        bags.append(struct.pack("<HH", len(gens), len(mods)))
        return b"".join(bags), pack_generators(gens + [(0, 0)]), b"".join(mods + [bytes(10)])
    pbag, pgen, pmod = zone_tables(preset_zones)
    ibag, igen, imod = zone_tables(instrument_zones)
    def phdr(name, program, bag):
        return struct.pack("<20sHHHIII", name, program, 0, bag, 0, 0, 0)
    pdta = [
        sf.Chunk(b"phdr", phdr(b"Piano", 0, 0) + phdr(b"Other", 1, 3) + phdr(b"EOP", 0, 4)),
        sf.Chunk(b"pbag", pbag), sf.Chunk(b"pmod", pmod), sf.Chunk(b"pgen", pgen),
        sf.Chunk(b"inst", struct.pack("<20sH20sH", b"Shared", 0, b"EOI", 4)),
        sf.Chunk(b"ibag", ibag), sf.Chunk(b"imod", imod), sf.Chunk(b"igen", igen),
        sf.Chunk(b"shdr", bytes(46 * 4)),
    ]
    top = [sf.Chunk(b"LIST", b"INFO" + sf.Chunk(b"INAM", b"odd", b"X").encode()),
           sf.Chunk(b"LIST", b"sdta" + sf.Chunk(b"smpl", bytes(range(128))).encode()),
           sf.Chunk(b"LIST", b"pdta" + b"".join(chunk.encode() for chunk in pdta))]
    payload = b"sfbk" + b"".join(chunk.encode() for chunk in top)
    return b"RIFF" + struct.pack("<I", len(payload)) + payload


class SoundFontPreparationTests(unittest.TestCase):
    def test_roundtrip_retains_odd_padding_and_unknown_data(self):
        original = fixture()
        self.assertEqual(sf.SoundFont(original).encode({}), original)

    def test_clones_scoped_instruments_and_keeps_modulators(self):
        original = sf.SoundFont(fixture())
        data, report = sf.prepare_soundfont(fixture())
        prepared = sf.SoundFont(data)
        self.assertEqual(report["cloned_instrument_count"], 2)
        self.assertEqual(report["kept_sample_zones"], 4)
        self.assertEqual(report["discarded_disjoint_sample_zones"], 2)
        self.assertEqual(report["verified_key_velocity_pairs"], 16384)
        self.assertEqual(report["preset_count"], 2)
        _, zones = sf.split_global(prepared.zones("preset", 0), sf.INSTRUMENT)
        self.assertEqual([zone.values[sf.INSTRUMENT] for zone in zones], [1, 2])
        for preset in zones:
            p = preset.values
            global_zone, samples = sf.split_global(prepared.zones("instrument", p[41]), sf.SAMPLE_ID)
            self.assertEqual(global_zone.generators, original.zones("instrument", 0)[0].generators)
            self.assertEqual(global_zone.modulators, original.zones("instrument", 0)[0].modulators)
            for sample in samples:
                self.assertEqual([generator for generator, _ in sample.generators][:2], [43, 44])
                self.assertEqual(sample.generators[-1][0], sf.SAMPLE_ID)
                for range_id in (43, 44):
                    low, high = sf.get_range(sample.values, range_id)
                    outer_low, outer_high = sf.get_range(p, range_id)
                    self.assertGreaterEqual(low, outer_low)
                    self.assertLessEqual(high, outer_high)

    def test_unrelated_preset_and_original_instrument_are_unchanged(self):
        original = sf.SoundFont(fixture())
        output, _ = sf.prepare_soundfont(fixture())
        prepared = sf.SoundFont(output)
        self.assertEqual(sf.sample_routes(original, 1), sf.sample_routes(prepared, 1))
        self.assertEqual(original.zones("instrument", 0), prepared.zones("instrument", 0))

    def test_ranges_can_have_deliberate_overlapping_layers(self):
        _, report = sf.prepare_soundfont(fixture())
        self.assertEqual(report["max_matching_sample_zones"], 2)

    def test_equivalence_detects_lost_or_modified_samples(self):
        original = sf.SoundFont(fixture())
        output, _ = sf.prepare_soundfont(fixture())
        prepared = sf.SoundFont(output)
        rows = list(prepared.rows[b"igen"])
        rows[-2] = struct.pack("<HH", sf.SAMPLE_ID, 0)
        changed = sf.SoundFont(prepared.encode({b"igen": b"".join(rows)}))
        with self.assertRaisesRegex(ValueError, "Sample route mismatch"):
            sf.verify_equivalence(original, changed, 0)

    def test_malformed_riff_and_missing_preset_are_rejected(self):
        with self.assertRaises(ValueError):
            sf.prepare_soundfont(fixture()[:-1])
        with self.assertRaisesRegex(ValueError, "exactly one preset"):
            sf.prepare_soundfont(fixture(), program=99)

    def test_deterministic_output(self):
        self.assertEqual(sf.prepare_soundfont(fixture()), sf.prepare_soundfont(fixture()))

    def test_cli_never_overwrites_input_or_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "original.sf2", Path(directory) / "output.sf2"
            source.write_bytes(fixture())
            output.write_bytes(b"existing")
            command = [sys.executable, str(ROOT / "tool/prepare_ios_soundfont.py"), str(source)]
            for destination in (source, output):
                run = subprocess.run(command + [str(destination)], capture_output=True, check=False)
                self.assertNotEqual(run.returncode, 0)
            self.assertEqual(source.read_bytes(), fixture())
            self.assertEqual(output.read_bytes(), b"existing")

    def test_cli_check_is_read_only_and_rejects_missing_or_stale_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "original.sf2", Path(directory) / "output.sf2"
            source.write_bytes(fixture())
            command = [sys.executable, str(ROOT / "tool/prepare_ios_soundfont.py"),
                       str(source), str(output), "--check"]
            missing = subprocess.run(command, capture_output=True, check=False)
            self.assertNotEqual(missing.returncode, 0)
            self.assertFalse(output.exists())
            prepared, _ = sf.prepare_soundfont(fixture())
            output.write_bytes(prepared)
            before = output.stat().st_mtime_ns
            current = subprocess.run(command, capture_output=True, check=False)
            self.assertEqual(current.returncode, 0, current.stderr)
            self.assertEqual(output.stat().st_mtime_ns, before)
            self.assertEqual(output.read_bytes(), prepared)
            output.write_bytes(b"stale")
            stale = subprocess.run(command, capture_output=True, check=False)
            self.assertNotEqual(stale.returncode, 0)
            self.assertEqual(output.read_bytes(), b"stale")
            self.assertEqual(source.read_bytes(), fixture())

    def test_actual_bank_all_keys_and_velocities(self):
        source = ROOT / "ios/Runner/Resources/GeneralUser-GS.sf2"
        if not source.exists():
            self.skipTest("Original app soundbank is not present")
        output, report = sf.prepare_soundfont(source.read_bytes())
        self.assertEqual(report["preset_count"], 287)
        self.assertEqual(report["cloned_instrument_count"], 48)
        self.assertEqual(report["verified_key_velocity_pairs"], 16384)
        # Preserve the original bank's intentional overlapping zones elsewhere;
        # the Fire Fall On Me pitches at velocity 96 each have exactly one.
        self.assertEqual(report["max_matching_sample_zones"], 2)
        prepared = sf.SoundFont(output)
        routes = sf.sample_routes(prepared, prepared.preset_index(0, 0))
        for pitch in (55, 57, 59, 60, 62, 64, 65):
            matching = [route for route in routes
                        if route[0][0] <= pitch <= route[0][1]
                        and route[1][0] <= 96 <= route[1][1]]
            self.assertEqual(len(matching), 1)
        self.assertGreater(len(output), source.stat().st_size)


if __name__ == "__main__":
    unittest.main()
