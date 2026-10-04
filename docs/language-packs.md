# Bundled language-pack sources

## Using the books

Use the hymnal selector above the Numbers or Search tab to switch editions.
English retains the combined Old/New keypad. Imported editions offer number
lookup, text search, and native topic lists. Book selection persists across
launches. Favorites and named categories can mix editions without number
collisions. The shared reader supports paging, text size, themes, and credits;
topic navigation stays in the selected topic.

The interface remains English. Hymn text, titles, credits, and topics retain
their source language. UI translation, accent-folded search, audio, and foreign
scores are separate roadmap items. Foreign music controls are hidden until
explicit media mappings exist. Cyrillic labels use a bundled font fallback.

Foreign per-hymn analytics are suppressed while the deployed collector still
accepts only English aliases. Content reports use its existing general-report
path, with the correct book, hymn number, and title prefilled in the report title.
No foreign hymn is reported as an English hymn with the same number.

Pack loading verifies catalog hashes, byte sizes, schema, book identities,
counts, and topic references. An unavailable pack does not prevent English
reading; Search offers a retry action. Source text is escaped before entering
the HTML reader, and English metadata or media is never inferred for a pack.

## Reproducible sources

`tool/import_hymnals.py` imports four audited GoGoShift books at revision
`42e1263684ddd756841f11581611b9c9c6cc574f`. Source paths, hashes, sizes, edition
metadata, and expected counts are pinned in `tool/data/hymnal_sources.json`.
The eight unmodified lyric/topic snapshots under `tool/data/hymnal_sources/`
make offline regeneration and review possible.

| Stable book ID | Edition | Hymns |
|---|---|---:|
| `sda-es-2009` | Español 2009 | 614 |
| `sda-es-1962` | Español 1962 | 527 |
| `sda-pt-1996` | Português 1996 | 610 |
| `sda-ru-1997` | Гимны Надежды 1997 | 385 |

The generated assets contain 2,136 hymns and 200 topic subdivisions. Every
source number, title, lyric text, and supplied author credit is retained. Source
text is plain text; it must be HTML-escaped before use in the legacy reader.
Paragraph blocks carry explicit stanza/refrain labels where the source supplied
one; missing labels are not invented and refrains are not automatically repeated.
Source order remains authoritative.

Each pack records provenance and coverage. Structural completeness means its
numbers match the audited source edition; it is not independent editorial
certification. The import rejects changed source hashes/sizes, duplicate or
missing numbers, empty text, encoding replacement characters, and invalid topic
references. Its catalog lists generated sizes and SHA-256 hashes. Nothing is
fetched from an upstream default branch at app runtime.

Regenerate with `python3 tool/import_hymnals.py`. Verify deterministically and
offline with `python3 tool/import_hymnals.py --check` or the import unit tests in
`scripts/verify.sh`. An upstream change requires a reviewed manifest update;
never silently replace existing English corrections with this source's English
files. No upstream scripts are executed.

These lyric/topic packs contain no MIDI, recordings, videos, or scores. Media
must be explicitly mapped by book and item in a later feature. New 388 in one
book does not authorize reuse of another book's hymn 388 music.
