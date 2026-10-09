# Bundled language-pack sources

## Using the books

Use the hymnal selector above the Numbers or Search tab to switch editions.
Every language uses the shared number pad. English and Spanish each offer
paired Old/New previews; Portuguese, Russian, French and Swahili show their single book.
Search remains on the Search tab, with native topic lists available through
Topics. Book selection persists across
launches. Favorites and named categories can mix editions without number
collisions. The shared reader supports paging, text size, themes, and credits;
topic navigation stays in the selected topic. Imported editions also support
opt-in silent auto-scroll with adjustable reading speed.

Search can target one edition or All languages, with book labels on every
combined result. Opening a result keeps navigation in its own book. The search
scope persists without replacing the Numbers tab's selected book. Latin accents
are optional in queries; canonical Unicode forms match, while meaningful
Cyrillic letters such as й and ё remain distinct. Native refrain labels are
recognized for ranking. Displayed titles and lyrics are never normalized.

The interface remains English. Hymn text, titles, credits, and topics retain
their source language. UI translation and audio are separate roadmap items.
Spanish 2009 and Russian 1997 scores use the shared offline sheet-music viewer. Both Spanish editions now offer instrumental recordings for every hymn (614 New and 527 Old). Spanish New #303 (three verses) and #230 (two verses) prefer their score-reviewed MIDI arrangements, retaining styles, choir parts, and key changes. Other Spanish hymns use the same player with recording-supported controls; other foreign editions remain silent. Recordings download on first play into a bounded temporary cache, so first use requires a connection. Cyrillic labels use a bundled font fallback.

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

These lyric/topic packs contain no MIDI, recordings, or videos. Scores have a
separate verified catalog keyed by exact book and number. Other media must also
be explicitly mapped by book and item. New 388 in one
book does not authorize reuse of another book's hymn 388 music.

## Content validation report

Run `python3 tool/validate_hymnal_content.py --output /tmp/hymnal-content-report.json`
to produce a deterministic, offline JSON review of all bundled imported books.
The report collects structural errors across books instead of stopping at the
first invalid entry. A nonzero exit status means publication must stop.

Checks include duplicate identities/numbers, empty or invalid text and lyric
blocks, missing provenance, invalid topic references, expected numbering from
the pinned manifest, catalog hashes/counts, and exact-edition score references.
Every referenced score file is checked against its byte count and SHA-256.
Missing scores are listed separately as coverage gaps; absent language audio
is explicitly disclosed. No media association is inferred from a title or number.
Instrumental recording references now require a known exact book and item,
unique book/item entries, pinned repository/revision metadata, positive byte
counts, valid Git blob hashes, and the matching edition-specific source path.
Declared counts and total sizes must agree with their entries. Catalog failures
are collected in `catalogErrors` and contribute to the nonzero publication status.
Coverage lists include only valid recording references and explicitly list
missing recordings. This offline report validates catalog metadata; the separate
recording audit verifies downloaded bytes and durations.

The reusable pack inspector accepts an explicit expected-number set for partial
collections; it never fills gaps or renumbers source records. This report
covers the current canonical packs. VideoPsalm/structured-source adapters and reviewed override tracking are
available for staged review; catalog integration of their books remains separate. Structural validation does not
replace lyric review or certify cross-language musical equivalence.


## Additional source adapters (review staging)

`tool/import_structured_hymnals.py` accepts pinned VideoPsalm JSON and structured
verse/refrain JSON. The manifests and unmodified full snapshots in
`tool/data/structured_sources/` exercise French (520 records) and the partial
Tagalog collection (237 records, source pages 2–474 with six odd-label discrepancies). The standalone tool does not register books in the app catalog. French and
Swahili are included through the main importer described below; Tagalog retains
a temporary review identity and is not published.

Example:
```sh
python3 tool/import_structured_hymnals.py   tool/data/structured_sources/french.manifest.json   --output /tmp/french-review-pack.json
```

Repeat with `--check` to require byte-identical output, or substitute the Tagalog
manifest. Every run verifies the snapshot size and SHA-256 before parsing.
Explicit expected-number lists support source page numbering without inventing
missing pages. Invalid numbers, duplicates, empty blocks and language mismatches
fail before output replacement.

VideoPsalm verse order, repeated occurrences, GUIDs and original records remain
intact. A manifest may map reviewed `refrainTags`; unreviewed numeric tags are
not interpreted. Structured sources retain numbered verses and one separate
refrain after them. This represents the source fields, not an inferred singing
sequence. Blank separator lines remain intact. Original source records and text
are preserved alongside display blocks.

Optional `--overrides reviewed.json` accepts a source-revision-pinned object
with `changes`: each change supplies `itemId`, `field`, `before`, `after`,
`reviewer`, and `reason`. Only title, blocks and credits may change. Duplicate
changes, stale values and identity changes fail; applied decisions are included
in `reviewedOverrides`. This does not imply that an override was reviewed merely
because it passes schema validation.

Some structured records carry external audio links. They remain in the original
record as research leads only; the importer does not activate, download, or
certify them as matching recordings. Playback requires separate verification.


The pinned Tagalog snapshot uses 19, 143, 201, 237, 269 and 465 in place of
the expected even labels 18, 142, 200, 236, 268 and 464. The staging manifest
enumerates the actual source labels. No correction has been inferred, and
publication remains pending editorial reconciliation.


## French and Swahili expansion

The catalog now also includes the 520-entry **Hymnes et Louanges** collection
(`sda-fr-hymnes-et-louanges`) and the 220-entry **Nyimbo za Kristo** collection
(`sda-sw-nyimbo-za-kristo`). These use the pinned Rejnac snapshots and manifests
under `tool/data/structured_sources/`; the standard import/check command
regenerates all six books (2,876 imported hymns and 200 topic subdivisions).

Source titles establish the collection names, but do not establish a print
edition year. Their year is therefore null, not the repository copyright date.
Stable IDs name the books without fabricating an edition date. Numbering covers
1–520 and 1–220 respectively. Structural completeness describes source coverage,
not independent certification of every lyric.

Both use the existing Numbers keypad, Search, favorites, service playlists, and
shared reader. Long selector labels truncate within the available width. There
are no supplied topic indexes, scores, or verified audio, so unavailable actions
are omitted. Original source verse order and repeated occurrences are retained;
numeric presentation tags are not interpreted without review. English and
paired Old/New Spanish remain unchanged.

Tagalog remains a staging-only partial collection. Its page-label discrepancies
are unresolved. French and Swahili have graduated from staging IDs to the stable
catalog IDs above; their source snapshots remain unmodified.

## Philippine collection numbering review

Cebuano now has a pinned 237-record staging manifest and snapshot alongside
Tagalog, exercised by the same offline importer tests. Neither partial
collection is enabled in the app.

The structured Tagalog and Cebuano files both use 19, 143, 201, 237, 269 and
465 for six entries. In the same repository revision, `sdahymnal.json` uses
18, 142, 200, 236, 268 and 464 for those exact titles in the respective language.
`tool/data/structured_sources/philippine-numbering-review.json` records the
twelve title/number pairs and the alternate source URL, byte size and checksum.
This corroborates a source conflict; it does not establish which label matches
the printed book. Both staging manifests preserve the structured source labels.


### Spanish instrumental recordings (2026-10-07)

`assets/hymnals/spanish_recordings.json` pins 1,141 edition-specific files from
`isax5/hymnal` revision `dc744acaa3971fa630e6d68193d9ddfb4c11a710`.
The source settings explicitly associate Spanish 2009 and 1962 with their own
instrumental directories. This is not a cross-language number match.
All files were downloaded and checked against source byte counts and Git blob
hashes; M4A headers and positive audio durations were checked with macOS afinfo.
The per-file results are in `tool/data/spanish_recording_audit.json`.
Re-run the network audit with `python3 tool/validate_spanish_recordings.py`.
It downloads about 1.8 GiB; it is intentionally separate from routine checks.

These checks establish source integrity and complete file coverage, not a manual
musical review of every recording. The supplied performances vary in duration;
some Old hymns are short and may cover only one verse. No inferred repetition,
transposition, or style transformation is applied to recordings. Complete MIDI
coverage and individual musical/form review remain open work.

Playback validates each download before use, retains up to 128 MiB in temporary
storage, and repairs corrupt cached files. The OS may clear this cache. Permanent
offline downloads remain a separate roadmap item. Loading and connection failures
are visible in the existing player. Recordings use the media player on iOS;
verified MIDI continues through the native soundfont player. Only the active
engine can publish completion events. Autoplay remains opt-in and starts only
after manual playback; pausing does not advance the queue.

The MIDI publication gate checks all catalog mappings globally, including unknown
book references. Duplicate book/item mappings fail validation and are excluded
from coverage rather than being counted twice. Local assets must stay within the
repository, match their SHA-256, and carry a standard MIDI header. These checks
protect catalog integrity; they do not verify tune equivalence or replace
individual musical review. Regression fixtures exercise unknown references,
duplicates, path escapes, checksum failures, malformed records, and non-MIDI files.

Reviewed lyric-block overrides regenerate the derived `sourceText` used for
search, so corrected lyrics and displayed blocks stay consistent. Original
`sourceRecord` data and the before/after review log remain intact. The importer
returns the same corrected pack it writes, and `--check` compares that complete
corrected output against the staged file. Regression tests cover both paths
and reject empty or malformed replacement blocks before writing.

## Automated publication gates

Run `python3 tool/check_content.py` from any working directory to run the importer,
structured-source, and content-report regression suites, translation validator
suite, byte-identical bundled import check, translation catalog check, and final
content coverage report. Use `--report /absolute/path/report.json` to retain the
report; otherwise it stays in temporary storage. A failure stops the command and
returns a nonzero exit code. It never regenerates bundled assets or downloads audio.

The Content publication checks GitHub workflow runs this same command on pushes,
pull requests, and manual dispatch with read-only repository permission. This is
an automated structural gate, not fluent lyric review, musical equivalence review,
or an automatic release. Branch protection is not changed by adding the workflow.

Runtime pack parsing rejects empty books, empty edition labels, language labels
that conflict with canonical book IDs, invalid replacement characters in titles
or lyrics, empty topic metadata, and repeated topic members. The publication
report also rejects repeated topic members. Regression checks load all six
shipped packs successfully and reject malformed metadata and text variants.
These activation checks are groundwork for optional downloads; downloaded pack
management is not yet available in Settings.

## Downloaded text storage groundwork

`LanguagePackDownload` describes a reviewed HTTPS text object with exact byte size,
SHA-256, book identity, hymn count, and topic count. It rejects text objects larger
than 16 MiB and validates decoded content against the runtime parser before any
activation. `LanguagePackStore` uses an injected downloader; it is not connected
to Settings, repository loading, or a published remote catalog yet.

The store stages verified text and metadata in a separate directory, flushes both,
and atomically replaces the active pointer. Failed or cancelled updates leave the
working pointer intact; writes/removals serialize and a failed download does not
poison subsequent operations. Successful updates remove obsolete text revisions.
Loading rechecks integrity, rejects linked/traversing files, and returns null for
invalid local data so the caller can retain bundled content. Removal deactivates
only the specified downloaded edition. It never writes preferences, favorites,
English assets, media, or the on-demand recording cache.

Seven store tests cover offline reopening, edition-isolated removal, failed
updates, bounded revision retention, cancellation during a pending download,
serialized operations and recovery, corrupt local metadata, and linked files.
The optional-download roadmap item remains incomplete until trusted catalog
publication, transport, repository integration, score storage, translated size/
coverage management UI, and physical-device validation are connected.
