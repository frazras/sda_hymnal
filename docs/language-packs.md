# Bundled language-pack sources

## Using the books

Tap the language pill in the header of the Numbers or Search tab (for example
**EN** or **ES**) to choose a hymnal. The picker lists every installed book by its
native language name, offers **All languages** on the Search tab, and ends with
**More languages**, which opens Hymnal downloads.
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
Spanish 2009 and Russian 1997 scores use the shared offline sheet-music viewer. Recordings cover every hymn in four editions: instrumental for Spanish 2009 (614), Spanish 1962 (527), and Russian 1997 (385); sung for Spanish 2009 (614) and Portuguese 1996 (610). Spanish New #303 (three verses) and #230 (two verses) prefer their score-reviewed MIDI arrangements, retaining styles, choir parts, and key changes. Other recorded hymns use the same player with recording-supported controls; a saved sung/instrumental preference applies where both exist. French, Swahili, and Chichewa remain silent. Recordings download on first play into a bounded temporary cache, so first use requires a connection. Cyrillic labels use a bundled font fallback.

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
Instrumental and sung recording references require a known exact book and item,
one collection per book and medium, a reviewed source (settings ID and
directory) for that book and medium, unique items, pinned repository/revision
metadata, positive byte counts, valid Git blob hashes, and the matching source
path. Every item must have a file or appear in `missingItemIds`. Declared counts
and total sizes must agree with their entries. Catalog failures
are collected in `catalogErrors` and contribute to the nonzero publication status.
Coverage lists per medium include only valid recording references and explicitly
list missing recordings. This offline report validates catalog metadata; the
separate recording audit verifies downloaded bytes and durations.

The reusable pack inspector accepts an explicit expected-number set for partial
collections; it never fills gaps or renumbers source records. This report
covers the current canonical packs. VideoPsalm/structured-source adapters and reviewed override tracking are
available for staged review; catalog integration of their books remains separate. Structural validation does not
replace lyric review or certify cross-language musical equivalence.


## Additional source adapters (review staging)

`tool/import_structured_hymnals.py` accepts pinned VideoPsalm JSON and structured
verse/refrain JSON. The manifests and unmodified full snapshots in
`tool/data/structured_sources/` exercise French (520 records) and the partial
Tagalog collection (237 records, source pages 2–474). The standalone tool does
not register books in the app catalog. French and Swahili are included through
the main importer described below; Tagalog, Cebuano and the other optional books
are generated by this tool into `resources/hymnals/` (see
[Expanded optional text collections](#expanded-optional-text-collections)).

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

A manifest may instead pin its review file with `reviewedOverrides` (`path`,
`bytes`, SHA-256), as the main importer does; passing `--overrides` as well
fails. A review file may also hold `labelCorrections`, the only way to change a
number: each names `sourceNumber`, `sourceTitle`, the corrected `number`,
`reviewer` and `reason`. Corrections apply during conversion, before numbering
is checked. Only a source label outside `expectedNumbers` may move, only onto an
expected number, and only for the record with that source title. Unmatched,
duplicate or colliding corrections fail, and the original label stays in
`sourceRecord`. Manifests may also withhold unpublishable records through
`omittedRecords`, described below.

Some structured records carry external audio links. They remain in the original
record as research leads only; the importer does not activate, download, or
certify them as matching recordings. Playback requires separate verification.


The pinned Tagalog snapshot uses 19, 143, 201, 237, 269 and 465 in place of
the expected even labels 18, 142, 200, 236, 268 and 464. A reviewed label
correction now restores the even pages; the snapshot itself is unchanged.


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

Tagalog and Cebuano are now optional partial downloads with reviewed page
labels. French and Swahili have graduated from staging IDs to the stable catalog
IDs above; their source snapshots remain unmodified.

## Philippine collection numbering review

The structured Tagalog and Cebuano files both use 19, 143, 201, 237, 269 and
465 for six entries. In the same repository revision, `sdahymnal.json` uses
18, 142, 200, 236, 268 and 464 for those exact titles in the respective language.
`tool/data/structured_sources/philippine-numbering-review.json` records the
twelve title/number pairs and the alternate source URL, byte size and checksum.

The book is bilingual: English occupies the odd pages 1–473 and Tagalog or
Cebuano the even pages 2–474, 237 records each. `sdahymnal.json` follows that
layout throughout, and the six even labels exactly fill the six gaps in the
2–474 even sequence. `english.json` mirrors the error: it uses even labels 18,
142, 200, 236, 268 and 464 for the English hymns that `sdahymnal.json` numbers
19, 143, 201, 237, 269 and 465, and every other English label is odd. Each
corrected Tagalog page, and five of the six Cebuano pages, translates the English
hymn on the preceding odd page, for example Tagalog 464 "Dinggin, Pangino'n, ang
Panalangin" after English 463 "Hear Our Prayer, O Lord". The review file now
records the mirrored English evidence.

`tagalog.reviewed-overrides.json` and `cebuano.reviewed-overrides.json` apply
the six `labelCorrections` (reviewer "Claude (automated source reconciliation)",
each citing this evidence). Both books are complete for even pages 2–474 and
keep page numbers as hymn numbers; they are not renumbered 1–237. Cebuano page
142 (source label 143) repeats the title and lyrics of page 140, "Hupnga Man sa
Espiritu", in both source files, although the preceding English page, 141, is
"Holy Spirit, Light Divine". The page is kept because the record is internally
consistent, and its coverage note flags it for lyric review.


### Recordings: instrumental and sung (2026-10-13)

`assets/hymnals/recordings.json`, a copy of `tool/data/recording_sources.json`,
pins 2,750 files from `isax5/hymnal` revision
`dc744acaa3971fa630e6d68193d9ddfb4c11a710`. Each collection names one exact
book and medium (`instrumentalRecording` or `sungRecording`):

| Book | Medium | Files | Gaps | Bytes | Audited |
|---|---|---:|---:|---:|---|
| `sda-es-2009` | instrumental | 614 | 0 | 1,194,774,139 | 2026-10-07 |
| `sda-es-1962` | instrumental | 527 | 0 | 771,075,461 | 2026-10-07 |
| `sda-es-2009` | sung | 614 | 0 | 1,197,473,215 | 2026-10-13 |
| `sda-pt-1996` | sung | 610 | 0 | 1,268,867,227 | 2026-10-13 |
| `sda-ru-1997` | instrumental | 385 | 0 | 453,708,837 | 2026-10-13 |

The source's pinned `backend-data/v1/settings.json` (Git blob `f45543dc`)
assigns each directory to one edition ID. Our lyric source, GoGoShift
Hymnal-Flutter at the imported revision, reads those settings: its
`info_constants.json` maps `es-newVersion`, `es-oldVersion`, `pt-newVersion`,
and `ru-newVersion` to the files imported as `sda-es-2009`, `sda-es-1962`,
`sda-pt-1996`, and `sda-ru-1997`, and its player fills `###` with the hymn
number padded to three digits. File `NNN.m4a` therefore belongs to item NNN of
the same book; this is not a cross-language number match. Every book's item
numbers, including Russian 1–385, were compared with the actual file names:
each item has one file and no file is unassigned, so no gaps are declared. A
missing file is listed in the collection's `missingItemIds`, never filled from
another book or medium. The source's English recordings are not used.

`python3 tool/build_recording_catalog.py --enumerate` rebuilds the collections
from the pinned Git tree after checking the settings blob and each directory
assignment. Without `--enumerate` it regenerates the bundled catalog and the
synchronous availability table `lib/services/recording_availability.dart`;
`--check` compares both offline as part of `tool/check_content.py`. A new
collection needs a reviewed `RECORDING_SOURCES` entry in
`tool/validate_hymnal_content.py` and a manifest stub before enumeration.

`python3 tool/validate_recordings.py` replaces `validate_spanish_recordings.py`.
It downloads each selected file once into the ignored `tmp/recording_audit/`,
reusing files already checked, and verifies byte count, Git blob SHA-1, the M4A
`ftyp` header, and a positive macOS `afinfo` duration; throttled requests back
off and retry. Fully validated collections are merged into
`tool/data/recording_audit.json`, which keeps the 2026-10-07 Spanish results.
Select with `--collection sda-pt-1996:sungRecording`, `--book`, or `--medium`.
All 1,609 new files (2.72 GiB) passed without a retry. The whole catalog is
about 4.55 GiB, so this network audit stays outside routine checks.

These checks establish source integrity and complete file coverage, not a
manual musical review. Durations vary; some Old hymns cover only one verse. Sung
lyrics and verse order are the source's and have not been compared with the
bundled text. Spanish 2009 sung and instrumental durations nearly match (median
difference 0.2 s, at most 2.4 s), but no shared timeline is verified. Two pairs
share one identical file: Russian #182 and #193, which the bundled scores set
to the same Goncharov tune, and Spanish 1962 #28 and #31 (no 1962 score is
bundled to confirm a shared tune). Recordings are never repeated, transposed,
or restyled. Complete MIDI coverage and individual musical review remain open.

Verified MIDI keeps precedence (English, Spanish New #303 and #230). Other
hymns play the saved `recordingVoice` preference (`RecordingVoice`, default
`instrumental`) when recorded, otherwise their other recorded kind. Changing it
swaps a loaded recording from its start and keeps a paused one paused; a
stopped player stays stopped. Each download is validated before use; up to
128 MiB stays in temporary storage and corrupt cached files are repaired. Cache
names include the kind, so a hymn's two recordings never collide. The OS may
clear this cache; nothing is bundled and no full edition is downloaded. Loading
and connection failures are visible in the existing player. Recordings use the
media player on iOS; verified MIDI continues through the native soundfont
player. Only the active engine can publish completion events. Autoplay remains
opt-in and starts only after manual playback; pausing does not advance the
queue. The player has no Sung/Instrumental control yet;
`MidiPlayer.recordingKinds` lists a hymn's choices.

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

`downloadLanguagePack` now provides the text transport: a streamed GET to the
reviewed HTTPS URL, with redirects disabled, exact optional Content-Length,
received-byte limits, progress callbacks, header/idle timeouts, and full checksum/
pack validation. Cancellation is passed to the HTTP abort trigger and checked
between chunks; no partial buffer becomes an installed pack. Its five transport
regressions use streamed responses, including cancellation before headers, wrong
status/size, truncated or changed text, oversized bodies, and stalled streams.
The HTTP dependency stays at the already-resolved 1.6.0 version, promoted to direct.
This transport still awaits trusted catalog and app-loader/UI wiring.

`loadInstalledLanguagePacks` now connects downloaded text to the app shell.
It verifies the bundled packs first, retains their edition order, and overlays
only an exact-edition locally verified pack. Missing/corrupt downloaded content
retains the bundled edition. Application-support storage is initialized lazily;
loading never starts a network request. Failure to obtain local storage retains
bundled books. English books continue using their existing loader and assets.

Real-file integration tests install an updated Spanish pack, reopen it offline,
remove it back to bundled text with unchanged references, and corrupt it to
verify fallback while other editions remain available. Modern and Classic shell
checks show an updated Spanish title through the existing paired number pad.
The shell accepts an injected pack loader for deterministic widget tests; those
UI checks are separate from the real filesystem integration tests. Remote
catalog publication, management controls, live reload after management actions,
and optional scores remain incomplete.

## Reviewed text download catalog

`assets/hymnals/downloads.json` now lists 29 exact-edition text objects (the six
bundled books and 23 optional downloads) with byte sizes, SHA-256, hymn/topic
counts, and source coverage notes. URLs pin this repository's commit recorded in
`tool/data/language_download_sources.json`; no branch-name URL or number-based
music reuse is involved. The bundled metadata is 25,559 bytes. It does not add
another lyric pack or any audio to the app.

`tool/build_language_download_catalog.py` derives it from reviewed bundled packs
and `tool/data/language_download_sources.json`. `--check` is part of the offline
publication gate. Before publishing a changed source revision, run
`python3 tool/build_language_download_catalog.py --check --verify-remote` to
fetch each pinned text object and verify its exact destination, byte size and
checksum. All six hosted objects passed this check on 9 October 2026. The remote
check is intentionally separate from offline CI and downloads no recordings.

The app-side catalog reader rejects mutable revisions, duplicate books, empty
catalogs, and URLs that differ from the pinned repository/commit/edition path.
Tests verify every descriptor against its real bundled pack plus invalid catalog
fixtures. A management screen still needs to distinguish already-bundled content
from installed updates so it never downloads redundant text merely to show an
installed status. Catalog hosting uses the existing GitHub repository, not S3;
no new infrastructure has been created.

## First optional text collection: Chichewa staging

The pinned [Rejnac Chichewa source](https://github.com/rejnac/chichewa-hymnal/tree/690b953ec1426e04b5e2ebe7eddfcb2db878c754)
identifies the book as **Khristu Mu Nyimbo**, in Chichewa (Chewa/Nyanja), with
350 hymns. The [Library of Congress language registry](https://www.loc.gov/standards/iso639-2/php/langcodes-keyword.php?SearchTerm=ny&SearchType=iso_639_1)
confirms `ny` as its two-letter code. Source metadata and README do not establish
a print year; the manifest retains null rather than guessing an edition year.

The source snapshot and checksum are pinned in
`tool/data/structured_sources/chichewa.manifest.json`. A structural pass found
350 unique numbers, exactly 1–350, no empty titles, and no empty lyric blocks.
The standard structured importer preserves source song records/GUIDs and every
lyric occurrence in order. Refrains are not inferred from position or language.
Independent fluent lyric review remains pending, as disclosed in the coverage note.
No topics, MIDI, video, scores, or recordings are attached by number matching.

The generated pack lives at `resources/hymnals/sda-ny-khristu-mu-nyimbo.json`,
**outside Flutter's bundled asset paths**. It is intended for optional text
downloads, not another automatic increase in installed app size. The offline
publication gate checks byte-identical regeneration, and the structured-source
regression suite includes all 350 records. The trusted download catalog now
registers its exact published bytes, and the shared loader adds the book only
when a valid local copy is installed. Removal restores the six bundled books.
The shared number pad and reader support this collection in both designs and
themes. The Settings download page now installs, cancels, updates, and removes trusted
text copies, refreshing the shell after activation. Music coverage is still
unavailable.

## Text download management

Settings > Hymnal downloads shows the trusted catalog separately from the book
picker. It displays text size and hymn count. Included books remain available
offline without redundant downloads. Optional books disclose missing music and
pending independent lyric review. Their text downloads are integrity checked,
show progress, and can be cancelled before activation; leaving the page also
cancels a pending download. One management operation runs at a time.

An installed copy with a different checksum offers Update. Removal deletes only
the local text override; bundled books fall back to their included text. Saved
favorites and service references are retained. After a successful change the
shell reloads its shared content: newly installed books become selectable, and
removing the selected optional book safely returns to English. Audio remains
on demand with its existing bounded cache. Optional score-pack management and a
remote catalog update channel are still separate unfinished work.

## Reviewed corrections in the main publication path

GoGoShift book entries in `tool/data/hymnal_sources.json` may now declare an
optional `reviewedOverrides` descriptor with `path`, exact `bytes`, and SHA-256.
The path is relative to the manifest directory and must stay inside it, including
when resolving symlinks. French/Swahili structured manifests use the same field.
Review files retain the existing source-revision, before/after, reviewer, and
reason contract. Invalid hashes, stale decisions, missing reviewer details, or
identity changes fail before generated assets are replaced.

A corrected pack retains its original source revision and records the applied
review decisions; its content version adds a deterministic review fingerprint.
Original source snapshots remain untouched. Title/credit corrections preserve
original lyric text, while block corrections rebuild search text only for the
affected hymn. Without a review descriptor, generated bundled packs remain
byte-identical. These checks validate review records; they do not certify that
a named reviewer has performed fluent editorial or musical review.

## Published optional-pack coverage

The offline content report now includes every optional book carrying a local
resource path in the published download catalog, alongside bundled imported
books. It verifies the resource checksum, count, language/edition metadata, and
explicit expected numbers from its structured-source manifest. Media reference
checks apply to these books too; unavailable scores/recordings remain coverage
gaps rather than fabricated assets. Duplicate optional identities fail the gate.

The current report covers 29 imported packs and 10,353 hymns, including 23
optional collections (7,477 hymns). This total excludes the original English
books. The full publication gate passes 52 content tests, regenerates every
optional pack from its single pinned manifest, and checks all 29 text downloads,
three score collections, five recording collections, and 612 interface
messages.

## Expanded optional text collections

The 19 remaining Rejnac books follow the Chichewa pattern. Each has an unmodified
pinned snapshot and manifest in `tool/data/structured_sources/`, a pack generated
by the structured importer with the Chichewa options (no reviewed refrain tags)
in `resources/hymnals/`, and an `optionalPacks` entry. None is bundled. Paths,
revisions, byte sizes and SHA-256 match the [source inventory](multilingual-source-inventory.json),
and every fetched file also matched its pinned Git blob hash.

Identity rules: the ID is `sda-<tag>-<slug of the source title>`, where the title
is the source metadata `Text` field (not the file name). The tag is the ISO 639-1
code where one exists, otherwise ISO 639-2/3. Display names read
`<native language name> · <source title>`. Years are null: no source states an
edition year, and repository copyright dates are not edition years.

| Book ID | Tag | Display name | Hymns | Numbers | Coverage |
|---|---|---|---:|---|---|
| `sda-sn-kristu-munzwiyo` | `sn` | chiShona · Kristu MuNzwiyo | 300 | 1–300 | Complete |
| `sda-ki-nyimbo-cia-agendi` | `ki` | Gĩkũyũ · Nyimbo Cia Agendi | 299 | 1–299 | Complete |
| `sda-bem-klistu-mu-nyimbo` | `bem` | Icibemba · Klistu Mu Nyimbo | 311 | 1–311 | Complete |
| `sda-rw-indirimbo-zo-guhimbaza-imana` | `rw` | Ikinyarwanda · Indirimbo Zo Guhimbaza Imana | 500 | 1–500 | Complete |
| `sda-xh-ukristu-engomeni` | `xh` | isiXhosa · UKristu Engomeni | 352 | 1–352 | Complete |
| `sda-zu-ukrestu-esihlabelelweni` | `zu` | isiZulu · UKrestu Esihlabelelweni | 300 | 1–300 | Complete |
| `sda-kln-tienwogik-che-kilosune-jehovah` | `kln` | Kalenjin · Tienwogik che Kilosune Jehovah | 245 | 1–245 | Complete |
| `sda-kam-mbathi-sya-kumutaia-ngai` | `kam` | Kikamba · Mbathi sya Kumutaia Ngai | 469 | 1–469 | Complete |
| `sda-mas-isinkolioitin` | `mas` | Maa · Isinkolioitin | 243 | 1–243 | Complete |
| `sda-nso-kreste-ka-kopelo` | `nso` | Sepedi · Kreste Ka Kopelo | 303 | 1–303 | Complete |
| `sda-tn-keresete-mo-kopelong` | `tn` | Setswana · Keresete mo Kopelong | 300 | 1–300 | Complete |
| `sda-ve-ngosha-yadzingosha` | `ve` | Tshivenḓa · Ngosha YaDzingosha | 306 | 1–306 | Complete |
| `sda-ts-tinsimu-ta-mhalamhala` | `ts` | Xitsonga · Tinsimu Ta Mhalamhala | 311 | 1–311 | Complete |

Identity decisions, also recorded in each manifest's `notes`:

- **isiZulu/Ndebele.** The README says "isiZulu and Ndebele" and the metadata
  names no language. A book carries one tag, so the text was checked for forms
  that differ between isiZulu and Northern Ndebele: Zulu comitatives
  (*nami/nawe/naye/nathi/nani*) occur 124 times against one Ndebele *la-* form,
  *manje* ("now") 54 times against no *khathesi*, and *nina* six times against
  no *lina*. The text follows isiZulu, so the tag is `zu`; the coverage note
  repeats the source's isiZulu/Ndebele label.
- **Icibemba.** The metadata declares `ibb`, the ISO 639-3 code for Ibibio. The
  README and the lyrics (*Lesa*, *Yesu*, *Mfumu*) are Bemba, so the tag is `bem`.
- **Kalenjin** uses the macrolanguage code `kln`; the source names no variety.
- **Xhosa and Xitsonga** use the metadata titles "UKristu Engomeni" and
  "Tinsimu Ta Mhalamhala", which differ slightly from their file names.

Source text is kept as published, including literal `&amp;` entities in
Setswana and isiXhosa voice-part labels, a stray `<h2>` heading in Xitsonga #84,
and tonic sol-fa fragments in seven Kikamba records. Same-title pairs with
identical lyrics (Kalenjin 199/200, Kinyarwanda 439/440) are kept as possible
alternate settings. These are lyric-review items, not structural failures.

### Reconciled partial collections

Ekegusii, Sesotho, Chitumbuka and Twi had known empty entries and a duplicate
number. Dholuo and Chitonga were listed as clean, but closer checks found lyrics
filed under the wrong titles and lost characters. For every Rejnac book, the
VideoPsalm package (`.vpc`) at the same pinned revision was verified against its
Git blob hash, opened in memory, and compared record by record. All 19 packages
match their JSON (Kikuyu differs only in an explicit verse ID and a description
typo), so no package supplies missing or corrected text and no text override was
applied. `tool/data/structured_sources/rejnac-vpc-reconciliation.json` records
each package's path, size, hashes and result.

| Book ID | Tag | Display name | Hymns | Numbers | Withheld numbers |
|---|---|---|---:|---|---|
| `sda-toi-kristu-mu-nyimbo` | `toi` | Chitonga · Kristu Mu Nyimbo | 339 | 1–341 | 26, 223 (lost character) |
| `sda-tum-nyimbo-za-mpingo-wa-sda` | `tum` | Chitumbuka · Nyimbo za Mpingo wa SDA | 352 | 1–372 | 51, 66, 250, 266, 348–361, 363, 365 (no lyrics) |
| `sda-luo-wende-nyasae` | `luo` | Dholuo · Wende Nyasae | 329 | 1–332 | 43, 48, 66 (lyrics of 44, 49, 65) |
| `sda-guz-ogotera-kwa-nyasae` | `guz` | Ekegusii · Ogotera Kwa Nyasae | 365 | 1–370 | 13, 309, 327, 329, 343 (no lyrics); second #86 |
| `sda-st-keresete-pineng` | `st` | Sesotho · Keresete Pineng | 268 | 1–300 | 177, 180–183, 190–194, 196–199, 274, 279–282, 284–286, 288–292, 294–297, 300 (no lyrics) |
| `sda-tw-memeneda-akwanhwefo-nnwom` | `tw` | Twi · Memeneda Akwanhwefo Nnwom | 751 | 1–770 | 215–219, 740–750 (no lyrics); 312, 640, 737 (lyrics of 311, 639, 736) |

Manifests withhold records through `omittedRecords`. Each entry names the
record by number, GUID and title, with a kind, reason and reviewer
("Claude (automated source reconciliation)"). The importer accepts four kinds and
verifies each against the source: `empty` (no lyric text), `invalidText` (text
contains U+FFFD), `duplicateNumber` (another record with that number is kept),
and `duplicateLyrics` (lyrics exactly equal a kept record's, named by
`lyricsOf`, under a different title). A publishable unique record cannot be
withheld, numbers are never reassigned, and `expectedNumbers` must leave out
every withheld number. Each coverage note lists the omitted numbers.

- **Ekegusii #86.** Both records are complete hymns. The second is titled
  "(a) Ebisio Amang`ana Y`enkoro", a lettered 86a. Its lyrics match no other
  record and every number 1–370 already has a record, so it is not a misnumbered
  hymn. The first occurrence is kept; 86a is withheld because numeric identities
  cannot represent it without renumbering.
- **Misfiled lyrics.** Six records (Dholuo 43, 48, 66; Twi 312, 640, 737) carry
  the complete lyrics of a neighbouring hymn, opening with that hymn's title, so
  their own lyrics are absent. They are withheld rather than shown under the
  wrong title. Same-title identical pairs, such as Twi's alternate settings
  154/155 and 694/695, are kept.
- **Chitonga.** The README names "Sotho", "Chitonga, Zambezi" and "Lea
  Faka-Tonga" (Polynesian Tongan, `to`). The lyrics are Zambian Tonga: *Leza*
  occurs 199 times and *Mwami* 553 times, while Malawian Tonga/Tumbuka *Chiuta*
  never does. The tag is therefore ISO 639-3 `toi`. #26 and #223 each lost a
  character to U+FFFD in both files and are withheld rather than guessed;
  apostrophes garbled as Ô/Õ elsewhere are kept for lyric review.
- **Twi** entries 696–770 carry source labels N1–N55 and NG1–NG20. The N-series
  titles name the English originals; their lyrics are Twi.

### Philippine and supplemental collections

The wanmigs books use the same pinned revision as the
[numbering review](#philippine-collection-numbering-review). Their titles come
from the repository's `manifest.json`; it names no printed edition, so the
Philippine display names repeat the language.

| Book ID | Tag | Display name | Hymns | Numbers | Coverage |
|---|---|---|---:|---|---|
| `sda-ceb-cebuano-hymns` | `ceb` | Cebuano · Cebuano Hymns | 237 | Even pages 2–474 | Partial; six labels corrected; page 142 repeats page 140 |
| `sda-en-adventist-youth-songs` | `en` | English · Adventist Youth Songs | 10 | 1–10 | Complete; 3–5 are the AY Pledge, Aim and Motto |
| `sda-tl-tagalog-hymns` | `tl` | Tagalog · Tagalog Hymns | 237 | Even pages 2–474 | Partial; six labels corrected |

- **Page numbers.** Tagalog and Cebuano are page-numbered partial collections:
  237 songs of the printed bilingual book, numbered by their even pages and not
  renumbered. Cebuano has no ISO 639-1 code, so its tag is `ceb`.
- **Language.** Every Adventist Youth record is labelled `english`, and a
  per-record check of the lyrics found English throughout.
- **Withheld pending rights review.** The Scripture songbook
  (`scripture-songs.json`, 3 songs) and the special songbook
  (`special-songs.json`, 382 songs) are not published: they contain songs under
  active copyright, such as "Thy Word" (1984) and "Seek Ye First" (1972) and many
  contemporary worship songs, and the wanmigs repository has no license file,
  unlike the MIT-licensed Rejnac repositories. Neither has a pack or catalog
  entry until the owner reviews publication rights.
- **Not imported.** `data.json` (themed Scripture snippets in a multi-document
  format) and `others.json` are out of scope, as is `english.json`; the English
  hymnal remains the app's own.
- External audio links in these records stay in `sourceRecord` as unverified
  leads and are not activated.

### Registration and hosting

The runtime parser opens only books registered in `_supportedImportedBook`;
all 22 books above are registered, and
`test/installed_language_packs_test.dart` opens every catalog entry through
that parser. The catalog pins commit
`ed69835a756edf026b2bb25daa8e5a0c96487008`, the first published commit that
hosts all 23 optional packs, and
`python3 tool/build_language_download_catalog.py --check --verify-remote`
confirmed every pinned object's size and SHA-256 on 13 October 2026.

On the Hymnal downloads page, a language search matches native names, titles,
language codes and English language names ("Zulu" finds isiZulu, "Kikuyu"
finds Gĩkũyũ). A finished download keeps its row in place and offers **Open**,
which closes the page and shows the new book; from Settings it also returns to
the number screen.

## Importing community interface reviews

Export a fresh CSV with `tool/export_translation_review.py`. Reviewers leave
untouched messages `unreviewed`; use `reviewed` only for messages actually checked,
with a reviewer name and an ISO date (`YYYY-MM-DD`). A suggested translation on
an unreviewed row is never applied. An empty suggestion on a reviewed row keeps
the existing translation and records that decision.

Run `python3 tool/import_translation_review.py review.csv /path/to/new-stage`.
The importer requires the complete exported key set and rejects stale English,
translations, hashes, context, or placeholder descriptions. It validates required
arguments and ICU syntax with Flutter in a separate temporary project, then
compares the generated localization API to prevent undeclared arguments from
changing app callers. Successful output contains one staged ARB, the original CSV, and a review
audit with file checksum, counts, before/after decisions, names, and dates.
The live catalogs are never overwritten; existing output directories are refused.

Fluent review remains pending for the current drafts. This workflow provides a
way to receive and validate human corrections; it does not itself approve the
583 existing messages. Publishing staged corrections still requires updating the
catalog, regenerating localizations, and checking the affected app layouts.
