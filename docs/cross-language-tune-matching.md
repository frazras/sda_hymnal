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
