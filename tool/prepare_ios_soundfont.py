#!/usr/bin/env python3
"""Scope piano instruments to their preset ranges for Apple's SF2 importer.

GeneralUser GS reuses one piano instrument across multiple preset key/velocity
ranges. Apple's sampler import can broaden disjoint sample zones, activating
many unrelated samples for one key. Give each preset zone its own instrument
whose sample zones are already intersected with that preset's ranges.

This changes routing only: all non-range generators, modulators, original
instruments, other presets, sample headers and PCM bytes are retained. It does
not shorten releases, change MIDI notes, or insert all-sound-off messages.

Usage:
    python3 tool/prepare_ios_soundfont.py ORIGINAL.sf2 NEW.sf2
    python3 tool/prepare_ios_soundfont.py ORIGINAL.sf2 NEW.sf2 --check

The output must not already exist. The original is never modified. Verification
compares effective sample routes for all 128 keys x 128 velocities before any
output is written. Only Python's standard library is required.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct


INSTRUMENT = 41
KEY_RANGE = 43
VELOCITY_RANGE = 44
SAMPLE_ID = 53
RANGES = {KEY_RANGE, VELOCITY_RANGE}


@dataclass(frozen=True)
class Chunk:
    tag: bytes
    data: bytes
    padding: bytes = b""

    def encode(self) -> bytes:
        padding = (self.padding or b"\0") if len(self.data) & 1 else b""
        return self.tag + struct.pack("<I", len(self.data)) + self.data + padding


def chunks(data: bytes) -> list[Chunk]:
    result = []
    offset = 0
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("Truncated RIFF chunk header")
        tag, length = struct.unpack_from("<4sI", data, offset)
        end = offset + 8 + length
        padded_end = end + (length & 1)
        if padded_end > len(data):
            raise ValueError(f"Truncated {tag!r} chunk")
        result.append(Chunk(tag, data[offset + 8:end], data[end:padded_end]))
        offset = padded_end
    return result


def records(data: bytes, size: int) -> list[bytes]:
    if not data or len(data) % size:
        raise ValueError(f"Invalid SoundFont table length for {size}-byte records")
    return [data[index:index + size] for index in range(0, len(data), size)]


@dataclass(frozen=True)
class Zone:
    generators: tuple[tuple[int, int], ...]
    modulators: tuple[bytes, ...]
    first_generator: int

    @property
    def values(self) -> dict[int, int]:
        return dict(self.generators)


class SoundFont:
    def __init__(self, data: bytes):
        if (len(data) < 12 or data[:4] != b"RIFF" or data[8:12] != b"sfbk"
                or struct.unpack_from("<I", data, 4)[0] != len(data) - 8):
            raise ValueError("Expected a complete RIFF SoundFont2 bank")
        self.top = chunks(data[12:])
        pdta = [chunk for chunk in self.top if chunk.tag == b"LIST" and chunk.data[:4] == b"pdta"]
        if len(pdta) != 1:
            raise ValueError("Expected exactly one pdta list")
        self.pdta = chunks(pdta[0].data[4:])
        self.tables = {chunk.tag: chunk.data for chunk in self.pdta}
        if len(self.tables) != len(self.pdta):
            raise ValueError("Duplicate SoundFont table")
        sizes = {b"phdr": 38, b"pbag": 4, b"pmod": 10, b"pgen": 4,
                 b"inst": 22, b"ibag": 4, b"imod": 10, b"igen": 4, b"shdr": 46}
        if any(tag not in self.tables for tag in sizes):
            raise ValueError("Missing SoundFont hydra table")
        self.rows = {tag: records(self.tables[tag], size) for tag, size in sizes.items()}

    def encode(self, replacements: dict[bytes, bytes]) -> bytes:
        pdta = b"pdta" + b"".join(
            Chunk(chunk.tag, replacements[chunk.tag]).encode()
            if chunk.tag in replacements else chunk.encode()
            for chunk in self.pdta
        )
        payload = b"sfbk" + b"".join(
            Chunk(b"LIST", pdta).encode()
            if chunk.tag == b"LIST" and chunk.data[:4] == b"pdta" else chunk.encode()
            for chunk in self.top
        )
        return b"RIFF" + struct.pack("<I", len(payload)) + payload

    def preset_index(self, bank: int, program: int) -> int:
        found = [index for index, record in enumerate(self.rows[b"phdr"][:-1])
                 if struct.unpack_from("<HH", record, 20) == (program, bank)]
        if len(found) != 1:
            raise ValueError(f"Expected exactly one preset bank={bank}, program={program}")
        return found[0]

    def zones(self, kind: str, index: int) -> list[Zone]:
        if kind == "preset":
            headers, header_offset, bag_tag, gen_tag, mod_tag = b"phdr", 24, b"pbag", b"pgen", b"pmod"
        elif kind == "instrument":
            headers, header_offset, bag_tag, gen_tag, mod_tag = b"inst", 20, b"ibag", b"igen", b"imod"
        else:
            raise ValueError("Unknown zone kind")
        if not 0 <= index < len(self.rows[headers]) - 1:
            raise ValueError(f"Invalid {kind} index {index}")
        first = struct.unpack_from("<H", self.rows[headers][index], header_offset)[0]
        last = struct.unpack_from("<H", self.rows[headers][index + 1], header_offset)[0]
        bags, generators, modulators = self.rows[bag_tag], self.rows[gen_tag], self.rows[mod_tag]
        if not 0 <= first <= last < len(bags):
            raise ValueError("Invalid zone bag indices")
        result = []
        for bag in range(first, last):
            gen, mod = struct.unpack("<HH", bags[bag])
            end_gen, end_mod = struct.unpack("<HH", bags[bag + 1])
            if not (0 <= gen <= end_gen < len(generators) and 0 <= mod <= end_mod < len(modulators)):
                raise ValueError("Invalid generator/modulator indices")
            result.append(Zone(tuple(struct.unpack("<HH", row) for row in generators[gen:end_gen]),
                               tuple(modulators[mod:end_mod]), gen))
        return result


def split_global(zones: list[Zone], reference: int) -> tuple[Zone, list[Zone]]:
    empty = Zone((), (), 0)
    global_zone = zones[0] if zones and reference not in zones[0].values else empty
    local = zones[1:] if global_zone is not empty else zones
    if any(reference not in zone.values for zone in local):
        raise ValueError("Noninitial global zone")
    return global_zone, local


def get_range(values: dict[int, int], generator: int) -> tuple[int, int]:
    value = values.get(generator, 0x7F00)
    low, high = value & 255, value >> 8
    if not 0 <= low <= high <= 127:
        raise ValueError("Invalid SoundFont key/velocity range")
    return low, high


def intersection(a: tuple[int, int], b: tuple[int, int]) -> tuple[int, int] | None:
    low, high = max(a[0], b[0]), min(a[1], b[1])
    return (low, high) if low <= high else None


def sample_routes(font: SoundFont, preset_index: int) -> list[tuple]:
    """Canonical sample routes, preserving separate SF2 generator/modulator levels."""
    pglobal, presets = split_global(font.zones("preset", preset_index), INSTRUMENT)
    result = []
    for preset in presets:
        pv = {**pglobal.values, **preset.values}
        iglobal, samples = split_global(font.zones("instrument", pv[INSTRUMENT]), SAMPLE_ID)
        for sample in samples:
            iv = {**iglobal.values, **sample.values}
            key = intersection(get_range(pv, KEY_RANGE), get_range(iv, KEY_RANGE))
            vel = intersection(get_range(pv, VELOCITY_RANGE), get_range(iv, VELOCITY_RANGE))
            if key is None or vel is None:
                continue
            if not 0 <= iv[SAMPLE_ID] < len(font.rows[b"shdr"]) - 1:
                raise ValueError("Invalid sample reference")
            signature = (
                tuple(sorted((k, v) for k, v in pv.items() if k not in RANGES | {INSTRUMENT})),
                tuple(sorted((k, v) for k, v in iv.items() if k not in RANGES)),
                pglobal.modulators, preset.modulators, iglobal.modulators, sample.modulators,
            )
            result.append((key, vel, signature))
    return result


def verify_equivalence(original: SoundFont, prepared: SoundFont, preset_index: int) -> dict:
    if original.tables[b"phdr"] != prepared.tables[b"phdr"]:
        raise ValueError("Preset headers changed")
    if original.tables[b"pbag"] != prepared.tables[b"pbag"] or original.tables[b"pmod"] != prepared.tables[b"pmod"]:
        raise ValueError("Preset bags/modulators changed")
    if original.tables[b"shdr"] != prepared.tables[b"shdr"]:
        raise ValueError("Sample headers changed")
    def non_pdta(font: SoundFont) -> list[bytes]:
        return [chunk.encode() for chunk in font.top
                if not (chunk.tag == b"LIST" and chunk.data[:4] == b"pdta")]
    if non_pdta(original) != non_pdta(prepared):
        raise ValueError("Non-pdta data changed")
    for tag in (b"inst", b"ibag", b"igen", b"imod"):
        if original.rows[tag][:-1] != prepared.rows[tag][:len(original.rows[tag]) - 1]:
            raise ValueError(f"Original {tag.decode()} records changed")

    allowed = {zone.first_generator + index
               for zone in original.zones("preset", preset_index)
               for index, (generator, _) in enumerate(zone.generators) if generator == INSTRUMENT}
    if len(original.rows[b"pgen"]) != len(prepared.rows[b"pgen"]):
        raise ValueError("Preset generator count changed")
    for index, (old, new) in enumerate(zip(original.rows[b"pgen"], prepared.rows[b"pgen"])):
        if old != new and (index not in allowed or new[:2] != old[:2]):
            raise ValueError("An unrelated preset generator changed")

    ids = {}
    def grid(font: SoundFont) -> list[tuple[int, ...]]:
        cells = [[] for _ in range(128 * 128)]
        for key, vel, signature in sample_routes(font, preset_index):
            token = ids.setdefault(signature, len(ids))
            for pitch in range(key[0], key[1] + 1):
                for velocity in range(vel[0], vel[1] + 1):
                    cells[pitch * 128 + velocity].append(token)
        return [tuple(sorted(cell)) for cell in cells]
    before, after = grid(original), grid(prepared)
    for index, (old, new) in enumerate(zip(before, after)):
        if old != new:
            raise ValueError(f"Sample route mismatch at key={index // 128}, velocity={index % 128}")
    return {"verified_key_velocity_pairs": len(before), "max_matching_sample_zones": max(map(len, before))}


def prepare_soundfont(data: bytes, bank: int = 0, program: int = 0) -> tuple[bytes, dict]:
    font = SoundFont(data)
    preset_index = font.preset_index(bank, program)
    pglobal, presets = split_global(font.zones("preset", preset_index), INSTRUMENT)
    tables = {tag: list(font.rows[tag][:-1]) for tag in (b"inst", b"ibag", b"igen", b"imod")}
    pgen = list(font.rows[b"pgen"])
    kept = dropped = clones = 0

    for preset in presets:
        pv = {**pglobal.values, **preset.values}
        iglobal, samples = split_global(font.zones("instrument", pv[INSTRUMENT]), SAMPLE_ID)
        scoped = []
        for sample in samples:
            iv = {**iglobal.values, **sample.values}
            key = intersection(get_range(pv, KEY_RANGE), get_range(iv, KEY_RANGE))
            vel = intersection(get_range(pv, VELOCITY_RANGE), get_range(iv, VELOCITY_RANGE))
            if key is None or vel is None:
                dropped += 1
                continue
            generators = ((KEY_RANGE, key[0] | key[1] << 8),
                          (VELOCITY_RANGE, vel[0] | vel[1] << 8)) + tuple(
                (k, v) for k, v in sample.generators if k not in RANGES)
            scoped.append(Zone(generators, sample.modulators, 0))
            kept += 1
        if not scoped:
            raise ValueError("Preset zone has no reachable samples; refusing an empty instrument")

        instrument_index = len(tables[b"inst"])
        name = f"iOS piano {clones:03d}".encode("ascii").ljust(20, b"\0")
        tables[b"inst"].append(name + struct.pack("<H", len(tables[b"ibag"])))
        to_copy = ([iglobal] if iglobal.generators or iglobal.modulators else []) + scoped
        for zone in to_copy:
            tables[b"ibag"].append(struct.pack("<HH", len(tables[b"igen"]), len(tables[b"imod"])))
            tables[b"igen"].extend(struct.pack("<HH", *generator) for generator in zone.generators)
            tables[b"imod"].extend(zone.modulators)
        for index, (generator, _) in enumerate(preset.generators):
            if generator == INSTRUMENT:
                pgen[preset.first_generator + index] = struct.pack("<HH", INSTRUMENT, instrument_index)
        clones += 1

    tables[b"inst"].append(font.rows[b"inst"][-1][:20] + struct.pack("<H", len(tables[b"ibag"])))
    tables[b"ibag"].append(struct.pack("<HH", len(tables[b"igen"]), len(tables[b"imod"])))
    for tag in (b"igen", b"imod"):
        tables[tag].append(font.rows[tag][-1])
    replacements = {tag: b"".join(rows) for tag, rows in tables.items()}
    replacements[b"pgen"] = b"".join(pgen)
    output = font.encode(replacements)
    prepared = SoundFont(output)
    verified = verify_equivalence(font, prepared, preset_index)
    report = {
        "bank": bank, "program": program,
        "preset_count": len(font.rows[b"phdr"]) - 1,
        "original_instrument_count": len(font.rows[b"inst"]) - 1,
        "cloned_instrument_count": clones,
        "kept_sample_zones": kept, "discarded_disjoint_sample_zones": dropped,
        "input_bytes": len(data), "output_bytes": len(output),
        "input_sha256": hashlib.sha256(data).hexdigest(),
        "output_sha256": hashlib.sha256(output).hexdigest(),
        **verified,
    }
    return output, report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--bank", type=int, default=0)
    parser.add_argument("--program", type=int, default=0)
    parser.add_argument("--check", action="store_true",
                        help="Verify an existing output is current; do not write any files")
    args = parser.parse_args()
    if args.source.resolve() == args.destination.resolve():
        parser.error("Source and destination must differ")
    if args.destination.exists() and not args.check:
        parser.error("Destination already exists; refusing to overwrite")
    try:
        output, report = prepare_soundfont(args.source.read_bytes(), args.bank, args.program)
        if args.check:
            if args.destination.read_bytes() != output:
                raise ValueError("Destination is stale or modified; it does not match the prepared source")
            report["check"] = "matched"
        else:
            with args.destination.open("xb") as destination:
                destination.write(output)
    except (OSError, ValueError, struct.error) as error:
        parser.error(str(error))
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
