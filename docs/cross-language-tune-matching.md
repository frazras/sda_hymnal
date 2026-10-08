# Sharing music across language editions

A translated hymn can reuse instrumental music when its actual tune and musical
form match. Text title, translated title, and hymn number are candidate-finding
hints; they are not proof. Two editions can set the same text to different tunes.

## Verified score example: Amazing Grace / Sublime gracia

Reviewed against the bundled source scores:

- English 1985 #108: `assets/sheet_music/en_1985/piano_sheet_en_108.png`.
- Spanish 2009 #303: `assets/sheet_music/es_2009/piano_sheet_es_303.png`.

The printed melody, key (F major), 3/4 meter, pickup, phrase order, and cadence
match on visual comparison. Both editions credit Robert J. Batastini's
arrangement and Virginia Harmony. The Spanish source has three verses; the
English score has five. Minor notational choices in the supporting voices and
lyric underlay do not change the tune identity, but the playback duration and
verse repetitions must follow the target edition.

Hymnary identifies English 1985 #108 as NEW BRITAIN:
https://hymnary.org/hymn/SDAH1985/108
Its tune authority also associates the Spanish text with NEW BRITAIN:
https://hymnary.org/tune/new_britain

Important counterexample: English 1941 #295 has the same English title but is
set to BELMONT, in G major. It is not an equivalent music source for this Spanish
entry: https://hymnary.org/hymn/CHSD1941/295

Spanish 2009 #303 now has verified instrumental playback. The full 35-note
soprano phrase and its onset rhythm in all five source verses match the Spanish
score (allowing the source's four-tick humanized offsets). The source is pinned
by SHA-256, and changes require a new review.

The generated asset keeps the introduction and first two verses, then joins
the source's final verse to retain the ending. Removed beats are [125, 221);
both boundaries have no active notes and the same tempo, with no discarded
controller/program changes. The result has three verses, 174 quarter-note
beats, and a duration of about 116.418 seconds. English New #108 is unchanged
at about 180.700 seconds. Melody volume and style settings are unchanged.

Rebuild using `python3 tool/build_verified_tune.py`; `--check` verifies both the
generated MIDI and `assets/midi/verified_tunes.json`. The app resolver enables
only this exact Spanish book/item. It keeps Spanish playback identity and a
separate render-cache key across styles, transposition, and choir practice.
Other languages/editions and videos are not inferred from this mapping.

## Integration rules

1. Find candidates from documented tune identifiers, composer/arranger credits,
   meter, and known translation relationships.
2. Compare full melody pitch intervals and note durations, allowing transposition
   and proportional tempo changes. Check pickups, repeats, refrains, alternate
   endings, and phrase order. A matching opening alone is insufficient.
3. Record a reviewed association keyed by the two exact book/item identities,
   with source evidence, target key, target verse count, and form adjustments.
4. Keep displayed hymn identity separate from its instrumental asset identity.
   Favorites, history, category/service queues, reporting, and analytics retain
   the target edition; only the music resolver follows the verified association.
5. MIDI styles may reuse the verified musical material. Sung audio and videos
   need separate language-specific associations. Do not show an English vocal
   performance as though it were Spanish.
6. Verify the actual asset's melody track and arrangement against the source
   score, then test target playback, key, duration, pause, and autoplay boundaries.

The same tune may have different harmony or verse rhythm across editions. Such
pairs can share the underlying tune without claiming that every existing
recording or MIDI arrangement is interchangeable. Keep uncertain candidates out
of automatic playback until reviewed.

## Spanish Old MIDI candidate audit (2026-10-07)

The edition-specific [1962 MIDI index](https://4eange.org/espagnol/CAN/ESP/MID/Index.htm)
lists 527 hymns and has a corresponding
[score index](https://4eange.org/espagnol/CAN/ESP/JPG/Index.htm).
The stopped download batch yielded 249 actual MIDI files (1–247, 350, 527),
101 HTML challenge responses masquerading as `.mid` files (248–348), and
177 items without a downloaded file. Do not retry the batch blindly or import
HTML responses. No candidate in this audit is automatically enabled for playback.

`tool/data/spanish_old_midi_candidates.json` pins the downloaded bytes and records
actual renderer results. All 249 MIDI candidates produce positive-duration files
in all six music styles with both the portable and iOS rendering paths: 2,988
successful renders. This verifies structural compatibility only. The files still
need melody, meter, pickup, refrain/repeat, and verse-form review against their
edition's scores before replacing recordings or enabling style controls.

Reproduce against the existing downloaded directory with:

```sh
dart tool/audit_spanish_midi.dart tmp/spanish_music_audit tool/data/spanish_old_midi_candidates.json
```

The [Old/New correlation project](https://github.com/Alexisvt/correlacion-himnario)
is an additional candidate-identification resource. Number/title correlations
must not be treated as proof that two editions use identical music or performance
form. Review the printed scores before sharing any MIDI arrangement.

## Spanish New #230: Abre tu corazón (2026-10-08)

Reviewed the entire printed soprano against
`assets/sheet_music/es_2009/piano_sheet_es_230.png`: Eb major, 6/8,
eight bars, no pickup or introduction, two verses. The 30-note phrase and
quarter-note onset positions are recorded in `tool/build_abre_tu_corazon.py`.

The Spanish Old #164 candidate from the edition-specific source is pinned at
`tool/data/midi_sources/spanish-old-164.mid` (SHA-256
`fb1ef0129d66debbc32929d96d136af69fd148433c4e4fc496d26475d9b34f44`).
It contains a single eight-bar verse in F, with named soprano/alto/tenor/bass.
After transposition down two semitones, its soprano matches the New score except
for the held note beginning at quarter beat 9: the candidate has G4, whereas the
New score prints Eb4. Both the note-on and note-off are corrected explicitly.
The final chord is shortened by half a quarter beat to preserve the printed
closing eighth rest. Each verse occupies 24 quarter beats; repeating once gives
48 beats and approximately 46.452 seconds. Eb-major key metadata is added.

This is a target-specific accompaniment arrangement. The source harmony is
retained after transposition; it is not claimed to duplicate every printed
supporting voice. The New edition's complete soprano and rhythm are checked,
and its two-verse form follows the target text. The Old edition is not enabled
by this mapping because its score review is still pending. Existing recordings
remain available for all other Spanish hymns.

The shared builder generates/checks both reviewed Spanish arrangements and the
mapping catalog. Tests check both full soprano repetitions, balanced note events,
closing rests, written key, duration, all style/engine renders, and manual
play/pause while preserving the exact Spanish book/item identity.
