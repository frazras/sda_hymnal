"""Score-reviewed Spanish New #230; explicit derivative, never automatic matching."""
import hashlib
import struct
from build_verified_tune import events, encode

SOURCE_SHA256 = 'fb1ef0129d66debbc32929d96d136af69fd148433c4e4fc496d26475d9b34f44'
# Complete soprano and rhythm read from Spanish New #230's printed score.
MELODY = [67,63,62,63,65,63,70,67,65,67,68,63,70,72,71,72,68,70,72,70,69,70,67,68,70,67,68,67,65,63]
ONSETS = [0,1,1.5,2,2.5,3,6,7,7.5,8,8.5,9,11.5,12,12.75,13,13.5,14,14.5,15,15.75,16,16.5,17.5,18,19,19.5,20,20.5,21]


def build(data):
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA256:
        raise ValueError('Source changed; repeat musical review')
    if data[:8] != b'MThd\0\0\0\6' or struct.unpack('>HHH', data[8:14]) != (1,5,240):
        raise ValueError('Unexpected source layout')
    tracks, at = [], 14
    for _ in range(5):
        if data[at:at+4] != b'MTrk':
            raise ValueError('Missing track')
        size = int.from_bytes(data[at+4:at+8], 'big')
        tracks.append(events(data[at+8:at+8+size]))
        at += size + 8
    if at != len(data):
        raise ValueError('Trailing source data')
    notes = [(t/240,b[0]-2) for t,s,b in tracks[1] if s & 240 == 144 and b[1]]
    pitches = [p for _,p in notes]
    # The Old candidate holds G after transposition at beat 9; New prints Eb.
    if pitches[11] != 67:
        raise ValueError('Unexpected source held note')
    pitches[11] = 63
    if pitches != MELODY or [t for t,_ in notes] != ONSETS:
        raise ValueError('Source differs from reviewed soprano')
    output = bytearray(data[:14])
    for index, track in enumerate(tracks):
        initial, musical = [], []
        for tick, status, body in track:
            if status == 255 and body[0] == 47:
                continue
            if status & 240 in (128,144):
                pitch = body[0] - 2
                if index == 1 and body[0] == 69 and tick in (2160,2760):
                    pitch = 63
                if not 0 <= pitch <= 127:
                    raise ValueError('Transposition outside MIDI range')
                # Printed final chord is tied for 2.5 beats, then an eighth rest.
                target = 5640 if tick == 5760 else tick
                musical.append((target,status,bytes([pitch])+body[1:]))
            elif tick == 0:
                initial.append((tick,status,body))
            else:
                raise ValueError('Unreviewed performance state change')
        if index == 0:
            initial.append((0,255,b'\x59\x02\xfd\x00'))  # Eb major
        sequence = initial + musical + [(t+5760,s,b) for t,s,b in musical]
        sequence.append((11520,255,b'\x2f\x00'))
        sequence.sort(key=lambda e:e[0])
        content, previous = bytearray(), 0
        for tick,status,body in sequence:
            content.extend(encode(tick-previous));content.append(status);content.extend(body)
            previous=tick
        output.extend(b'MTrk'+len(content).to_bytes(4,'big')+content)
    return bytes(output)


def mapping(output):
    return {'bookId':'sda-es-2009','itemId':'230','asset':'assets/midi/es-2009-230.mid',
            'sha256':hashlib.sha256(output).hexdigest(),
            'sourceBookId':'sda-es-1962','sourceItemId':'164','sourceSha256':SOURCE_SHA256,
            'sourceUrl':'https://4eange.org/espagnol/CAN/ESP/MID/E164.mid',
            'key':'Eb','meter':'6/8','verses':2,'includesIntroduction':False,
            'score':'assets/sheet_music/es_2009/piano_sheet_es_230.png',
            'adaptation':'Transpose down two semitones, use printed Eb held soprano at beat 9, end each verse with printed eighth rest, repeat for two verses. Source harmony retained as an arrangement.'}
