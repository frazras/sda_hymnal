#!/usr/bin/env python3
"""Build the reviewed Spanish 2009 #303 three-verse NEW BRITAIN arrangement.

Stdlib only. This is an explicit, checksum-pinned edit, not tune inference.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = 'a6f74d1bb227df2512a03464a4f488e05f16197aebbc45ebcbe80f8eac972c4e'
DEST = ROOT / 'assets/midi/es-2009-303.mid'
# Full soprano phrase, read against the Spanish score. Tied notes are one event.
MELODY = [60,65,69,65,69,67,65,62,60,60,65,69,65,69,67,72,
          69,72,69,72,69,65,60,62,65,65,62,60,60,65,69,65,69,67,65]
ONSETS = [0,1,3,3.5,4,6,7,9,10,12,13,15,15.5,16,18,19,
          24,25,26.5,27,27.5,28,30,31,32.5,33,33.5,34,36,37,39,39.5,40,42,43]


def vlq(data, at):
    value = 0
    for _ in range(4):
        byte = data[at]
        at += 1
        value = (value << 7) | (byte & 127)
        if byte < 128:
            return value, at
    raise ValueError('Invalid MIDI variable length')


def encode(value):
    result = [value & 127]
    while value > 127:
        value >>= 7
        result.insert(0, (value & 127) | 128)
    return bytes(result)


def events(data):
    tick, at, running = 0, 0, 0
    result = []
    while at < len(data):
        delta, at = vlq(data, at)
        tick += delta
        if data[at] >= 128:
            status = data[at]
            at += 1
        else:
            status = running
        start = at
        if status == 255:
            at += 1
            length, at = vlq(data, at)
            at += length
            running = 0
        elif status in (240, 247):
            length, at = vlq(data, at)
            at += length
            running = 0
        elif 128 <= status < 240:
            at += 1 if status & 240 in (192, 208) else 2
            running = status
        else:
            raise ValueError('Unsupported status')
        if at > len(data):
            raise ValueError('Truncated event')
        result.append((tick, status, data[start:at]))
    return result


def build(data):
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError('Source changed; repeat musical review before rebuilding')
    header = data[:14]
    if header[:8] != b'MThd\0\0\0\6':
        raise ValueError('Unexpected header')
    fmt, count, ppq = struct.unpack('>HHH', header[8:])
    if (fmt, count, ppq) != (1, 14, 384):
        raise ValueError('Unexpected reviewed MIDI layout')
    tracks, offset = [], 14
    for _ in range(count):
        if data[offset:offset+4] != b'MTrk':
            raise ValueError('Missing track')
        length = int.from_bytes(data[offset+4:offset+8], 'big')
        tracks.append(events(data[offset+8:offset+8+length]))
        offset += 8 + length
    if offset != len(data):
        raise ValueError('Unexpected trailing bytes')
    for start in (29, 77, 125, 173, 221):
        notes = [(tick / ppq - start, body[0]) for tick, status, body in tracks[1]
                 if start * ppq <= tick < (start + 48) * ppq
                 and status & 240 == 144 and body[1] > 0]
        if [pitch for _, pitch in notes] != MELODY or any(
                abs(onset - expected) > 4 / ppq + 1e-9
                for (onset, _), expected in zip(notes, ONSETS)):
            raise ValueError('Soprano differs from reviewed full score phrase')
    cut_start, cut_end = 125 * ppq, 221 * ppq
    output = bytearray(header)
    for track in tracks:
        for boundary in (cut_start, cut_end):
            active = set()
            for tick, status, body in track:
                if tick >= boundary:
                    break
                if status & 240 == 144 and body[1]:
                    active.add((status & 15, body[0]))
                elif status & 240 == 128 or (status & 240 == 144 and not body[1]):
                    active.discard((status & 15, body[0]))
            if active:
                raise ValueError('Cut crosses sustained notes')
        # No controller/program/key changes may be lost; tempo returns to
        # the same value at both joins in this specifically reviewed source.
        removed = [(status, body) for tick, status, body in track
                   if cut_start <= tick < cut_end and status & 240 not in (128, 144)]
        if any(status != 255 or body[0] != 81 for status, body in removed):
            raise ValueError('Cut would discard non-tempo state')
        tempos = []
        for boundary in (cut_start, cut_end):
            prior = [body for tick, status, body in track
                     if tick < boundary and status == 255 and body[0] == 81]
            tempos.append(prior[-1] if prior else None)
        if tempos[0] != tempos[1]:
            raise ValueError('Tempo differs at join')
        content, previous = bytearray(), 0
        for tick, status, body in track:
            if cut_start <= tick < cut_end:
                continue
            target = tick if tick < cut_start else tick - (cut_end - cut_start)
            content.extend(encode(target - previous))
            content.append(status)
            content.extend(body)
            previous = target
        output.extend(b'MTrk' + len(content).to_bytes(4, 'big') + content)
    return bytes(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = build((ROOT / 'assets/midi/108.mid').read_bytes())
    catalog = {'schemaVersion': 1, 'mappings': [{
        'bookId': 'sda-es-2009', 'itemId': '303', 'asset': 'assets/midi/es-2009-303.mid',
        'sha256': hashlib.sha256(output).hexdigest(),
        'sourceBookId': 'sda-en-1985', 'sourceItemId': '108',
        'sourceSha256': SOURCE_SHA256, 'tune': 'NEW BRITAIN',
        'key': 'F', 'meter': '3/4', 'verses': 3,
        'includesIntroduction': True,
        'score': 'assets/sheet_music/es_2009/piano_sheet_es_303.png'
    }]}
    catalog_path = ROOT / 'assets/midi/verified_tunes.json'
    catalog_bytes = (json.dumps(catalog, ensure_ascii=False, indent=2) + '\n').encode()
    if args.check:
        if not catalog_path.exists() or catalog_path.read_bytes() != catalog_bytes:
            raise SystemExit('Verified mapping catalog differs')
        if not DEST.exists() or DEST.read_bytes() != output:
            raise SystemExit('Verified arrangement differs')
    else:
        DEST.write_bytes(output)
        catalog_path.write_bytes(catalog_bytes)
    print(f'Verified Spanish 303: intro + 3 verses, {len(output)} bytes')
