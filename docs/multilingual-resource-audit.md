# Multilingual hymnals: resource audit and integration plan

Audited 1 October 2026 against app commit `821baabd57aa69c458c259c22403ac448e76ad70`.
This is research and planned work, not implemented multilingual support.

## Recommendation

Keep the current Flutter app and its English content. Add a catalog of named
hymnal editions, a repeatable import/validation pipeline, and optional offline
content packs. Start with Spanish 2009/1962, Portuguese 1996, and Russian 1997
from GoGoShift; expand to French, Swahili, and the other Rejnac collections after
editorial checks. Offer the Philippine collections as explicitly partial songbooks.

The reviewed projects provide useful coverage, not a verified inventory of every
SDA hymnal worldwide. Language, edition, and collection are distinct: a shared
language or hymn number does not establish that two books contain the same song.

The audit examined five main projects and all 26 repositories linked by Rejnac.
[The source inventory](multilingual-source-inventory.json) records pinned revisions,
file hashes, counts, numbering problems, sheet coverage, and audio probes. Counts
below are source records, not a guarantee of complete or correct printed editions.
External project documentation was treated as evidence, not work instructions;
no upstream scripts were executed.

## 1. GoGoShift / Hymnal-Flutter

[Project](https://github.com/GoGoShift/Hymnal-Flutter) ·
[Audited revision](https://github.com/GoGoShift/Hymnal-Flutter/tree/42e1263684ddd756841f11581611b9c9c6cc574f)

This is the strongest initial source. Six JSON books use `number`, `title`, and
plain-text `content`; the Spanish 2009 file also carries author data. Six separate
topic-index files use `thematic` and `ambits`. Edition metadata is in
[`assets/info_constants.json`](https://github.com/GoGoShift/Hymnal-Flutter/blob/42e1263684ddd756841f11581611b9c9c6cc574f/assets/info_constants.json).

| Book | Lyric records | Topic groups | Sheet music found in repository |
|---|---:|---:|---|
| English 1985 | 695 | 13 | 723 PNG pages for 695 hymn numbers; 12.51 MiB |
| English 1941 | 703 | 15 | No mapped sheet collection |
| Spanish 2009 | 614 | 9 | 614 PNG pages for 614 hymn numbers; 15.91 MiB |
| Spanish 1962 | 527 | 10 | No mapped sheet collection |
| Portuguese 1996 | 610 | 11 | No mapped sheet collection |
| Russian 1997 | 385 | 16 | 506 PNG pages for 384 hymn numbers; 14.49 MiB; #244 missing |

All six lyric files parse and have unique, contiguous numbers and nonempty content.
That structural check does not establish lyric accuracy. Sheet counts came from
the Git tree; every image has not been visually reviewed. Multiple pages use a
base filename plus numbered suffixes. Build explicit page lists instead of
guessing URLs or hard-coding the upstream viewer's six-extra-pages limit.

Recorded audio is external, not bundled MIDI. The live
[music settings](https://isax5.github.io/hymnal/backend-data/v1/settings.json)
configure instrumental recordings for English 1985/1941, Spanish 2009/1962, and
Russian 1997; sung recordings for Spanish 2009 and Portuguese 1996. HTTP HEAD for
#001 in all seven streams returned 200 and `audio/mp4`. This verifies sample
availability only, not full coverage or whether every recording matches its hymn.

Relevant implemented features are zoomable scores, selectable/shared lyrics,
reorderable favorites, a 50-entry history with clear action, an alphabet index,
localized English/Spanish/Portuguese/Russian UI, recorded-audio selection, and
system media controls. Evidence is in `lib/layers/screens/{sheets,hymn,favorites,
history,lists}`, `lib/l10n`, and `lib/services/audio_handler.dart` at the revision
above. Continuous playback overlaps our existing autoplay.

**Use:** import the four non-English books and topic indexes; use English files as
comparison sources, preserving our corrections, metadata, readings, and MIDI.
The source has an English #314 record worth reviewing against our documented gap;
do not replace the full English catalog automatically. Sheet music can ship as a
separate feature before the multilingual refactor, starting with English 1985.

## 2. GoGoShift / Hymnal-Xamarin

[Project](https://github.com/GoGoShift/Hymnal-Xamarin) ·
[Audited revision](https://github.com/GoGoShift/Hymnal-Xamarin/tree/b8d9e551f2526492f5651146dccb5034fd55ebe5)

Archived and superseded by the Flutter project. The six books under
`src/Hymnal.XF/Resources/Assets` have the same counts as Flutter, along with topic
JSON, sheet assets, language resources, and historical audio-service code.
Parsed content is identical for five of six lyric files and all six topic files;
Russian lyrics differ between snapshots. These are related sources, not two
independent confirmations of correctness.

**Use:** retain as a fallback and change-history reference when reconciling data or
missing assets. Prefer the maintained Flutter source for new imports. Do not port
the Xamarin app, Realm database, or old Azure service into our runtime. Its core
features add no distinct priority beyond the Flutter successor. The SourceForge
mirror previously mentioned is a distribution mirror, not another language source.

## 3. Adore / thebiblelover7 / hymnal

[Project](https://github.com/thebiblelover7/hymnal) ·
[Audited revision](https://github.com/thebiblelover7/hymnal/tree/484079f99ce177002f618fc255393432ea894c19)

Adore is a separate native Android/Kotlin app. Its README explicitly identifies
Xamarin as the source of its hymn text and sheets. The six JSON books have the
same record counts as GoGoShift, and the tree contains 1,843 score PNGs. It does
not supply an additional set of languages beyond those six books. The GoGoShift
app, whose code links both stores, is a closer match to the earlier description
of an iOS-and-Android competitor; Adore's reviewed repository describes Android.

The useful public script is
[`convert-json-to-db.py`](https://github.com/thebiblelover7/hymnal/blob/484079f99ce177002f618fc255393432ea894c19/app/src/main/assets/convert-json-to-db.py).
It converts six JSON sources and score filenames into SQLite tables with a
Unicode full-text index. It is a build-time converter, not an all-language
downloader. Its hard-coded schema/version and Android resource paths should not
be copied as our production pipeline.

Implemented features worth adapting:

- Ordered service playlists: separate playlist-entry identity and position,
  with move-up/down controls, beyond our deduplicated favorite categories.
- Custom hymnal import: a ZIP with `hymnal.json`, metadata, content version,
  hymn records, and score paths, handled in `HymnalViewModel.kt`.
- Search backed by SQLite FTS and weighted ranking (`HymnDao.kt`). A fuzzy-search
  helper exists, but the inspected active search path calls FTS; this audit does
  not claim typo tolerance is a shipped feature.
- A community UI-translation workflow linked through Weblate.

**Use:** take the import-format and playlist concepts into our own Flutter
implementation. Keep stable entry IDs so the same hymn can appear twice in a
service without changing favorite-category semantics. Treat UI translation as a
separate project from hymn-text availability. No MIDI/audio files were found in
the inspected Adore tree.

## 4. Rejnac / compiled-hymnal and all linked books

[Directory](https://github.com/rejnac/compiled-hymnal/tree/03398dc2c597c10bba29a1e8db48934cbce75b82)

The directory has only a README and license. It currently links **26** book
repositories, correcting the earlier rough count of 25. Every child has a JSON
book and a VideoPsalm `.vpc` file. JSON shape is book metadata plus
`Songs[{ID, Guid, Text, Verses:[{ID?, Text}]}]`: song `Text` is the title and verse
`Text` holds lyrics. Verse IDs can be absent; preserve source order and GUIDs.
Presentation styles should not become our reader styling.

All 26 JSON files parsed, containing 10,375 source records in total. There are no
score, MIDI, or recording collections in these child trees. The `.vpc` files are
presentation packages, not audio. Blank detection below means an empty title or
no nonempty verse text; it does not catch every typo, fragment, or placeholder.

| Collection / source | Records | Structural findings / import decision |
|---|---:|---|
| [Chichewa](https://github.com/rejnac/chichewa-hymnal) | 350 | Basic checks pass; editorial review |
| [Dholuo](https://github.com/rejnac/dholuo-hymnal) | 332 | Basic checks pass; editorial review |
| [Ekegusii](https://github.com/rejnac/ekegusii-hymnal) | 371 | Duplicate #86; 5 empty entries; resolve before publication |
| [English](https://github.com/rejnac/sdah-hymnal) | 952 | Extended song collection; #696 onward are songs, not our New Hymnal readings |
| [French](https://github.com/rejnac/french-hymnal) | 520 | Basic checks pass; good expansion candidate |
| [Icibemba](https://github.com/rejnac/icibemba-hymnal) | 311 | Basic checks pass; editorial review |
| [isZulu/Ndebele](https://github.com/rejnac/isiZulu-ndebele-hymnal) | 300 | Combined source label; verify language/edition metadata |
| [Kalenjin](https://github.com/rejnac/kalenjin-hymnal) | 245 | Basic checks pass; editorial review |
| [Kikuyu](https://github.com/rejnac/kikuyu-hymnal) | 299 | Basic checks pass; editorial review |
| [Kinyarwanda](https://github.com/rejnac/kinyarwanda-hymnal) | 500 | Basic checks pass; editorial review |
| [Portuguese](https://github.com/rejnac/portuguese-hymnal) | 610 | 36 empty entries; prefer GoGoShift for the initial Portuguese pack |
| [Russian](https://github.com/rejnac/russian-hymnal) | 384 | #223 absent; title is Psalmi Siona; reconcile edition before any merge |
| [Sepedi](https://github.com/rejnac/sepedi-hymnal) | 303 | Basic checks pass; editorial review |
| [Shona](https://github.com/rejnac/shona-hymnal) | 300 | Basic checks pass; editorial review |
| [Sotho](https://github.com/rejnac/sotho-hymnal) | 300 | 32 empty entries; resolve before publication |
| [Spanish](https://github.com/rejnac/spanish-hymnal) | 614 | Basic checks pass; compare with GoGoShift, do not duplicate catalog |
| [Swahili](https://github.com/rejnac/swahili-hymnal) | 220 | Basic checks pass; good expansion candidate |
| [Tonga](https://github.com/rejnac/tonga-hymnal) | 341 | Verify precise language/edition designation |
| [Tswana](https://github.com/rejnac/tswana-hymnal) | 300 | Basic checks pass; editorial review |
| [Tumbuka](https://github.com/rejnac/tumbuka-hymnal) | 372 | 20 empty entries; resolve before publication |
| [Twi](https://github.com/rejnac/twi-hymnal) | 770 | 16 empty entries; resolve before publication |
| [Venda](https://github.com/rejnac/venda-hymnal) | 306 | Basic checks pass; editorial review |
| [Xhosa](https://github.com/rejnac/xhosa-hymnal) | 352 | Basic checks pass; editorial review |
| [XiTsonga](https://github.com/rejnac/xitsonga-hymnal) | 311 | Basic checks pass; editorial review |
| [Kamba](https://github.com/rejnac/kamba-hymnal) | 469 | Basic checks pass; editorial review |
| [Maasai](https://github.com/rejnac/maasai-hymnal) | 243 | Basic checks pass; editorial review |

**Use:** one VideoPsalm-JSON adapter can handle the shared structure, with
per-book metadata and reviewed corrections. Do not infer refrain placement from
verse position or English labels. Preserve the original text alongside normalized
blocks. Cross-language matching needs explicit editorial mappings; neither
identical numbers nor similar titles are sufficient.

Projection export is a reasonable later feature suggested by their VideoPsalm
workflow. It is a proposal for our app, not a claim that these repositories
contain a ready-made Flutter projector or casting implementation.

## 5. wanmigs / sda-hymnal-data

[Project](https://github.com/wanmigs/sda-hymnal-data/tree/8fba6417536b1a36e7d35c5cea3773e5bea3c47b)

This is a data repository, not an app whose UI features can be compared.

| Resource | Verified contents | Use |
|---|---|---|
| `english.json` | 237 records, odd page numbers 1–473 | Reference/parallel collection, not replacement for our English hymnal |
| `tagalog.json` | 237 records, even page numbers 2–474 | Partial Tagalog collection |
| `cebuano.json` | 237 records, even page numbers 2–474 | Partial Cebuano collection |
| `sdahymnal.json` | Three roots: 237 English, 237 Tagalog, 237 Cebuano records | Alternate stanza-based representation; avoid double import |
| `ay-songs.json` | 10 entries | Optional Adventist Youth collection |
| `scripture-songs.json` | 3 entries | Optional Scripture-song collection |
| `special-songs.json` | 382 entries | Supplemental collection, subject to content review |
| `data.json` | Concatenated JSON documents; manifest describes 20 themed snippets and 7 full-lyrics records | Explicit multi-document adapter; not 27 automatically complete songs |
| `others.json` | 5 structured entries | Inspect by content type; not a hymn array |

The main format is `pageNumber/title/language/verses[{number,lines}]/refrain?`.
Page numbers are not SDA English hymn numbers: the first English entry is
“O Worship The Lord” at page 1. Preserve source page labels; establish any
parallel-language relationships by review, not odd/even arithmetic alone.

[`scripts/update-manifest.py`](https://github.com/wanmigs/sda-hymnal-data/blob/8fba6417536b1a36e7d35c5cea3773e5bea3c47b/scripts/update-manifest.py)
generates file sizes, SHA-256 hashes, counts, and content versions. All nine
manifest file hashes and sizes matched the fetched bytes. Its count for
`sdahymnal.json` explicitly covers only `english_hymns`; do not read that as the
whole file count. Its custom decoder supports concatenated documents in
`data.json`, which ordinary Dart/Python JSON decoding rejects.

**Use:** adapt the manifest/versioning pattern and structured stanza format.
Introduce separate Tagalog/Cebuano packs and optional youth/Scripture collections.
The repository has no accompanying music asset files. Some structured records
include external audio URLs; these are unverified candidate links, not confirmed
language-specific recordings or permission to enable playback. Hash validity proves file
integrity, not editorial quality or schema compatibility.

## Fit with our current architecture

| Current integration point | Required change |
|---|---|
| `lib/models/hymn.dart`, `lib/services/api.dart` | Add stable book/item identity and structured lyric blocks; retain a compatibility adapter for current HTML |
| `lib/ui/tabs.dart` | Replace the two `_hymnsNew/_hymnsOld` buckets with a catalog/repository and installed-book selection |
| `lib/ui/buttons.dart`, `hymnlist.dart`, `hymnPage.dart`, `classic.dart` | Book-aware labels, keypad rules, filters, and navigation; stop assuming all books have 695/703 items |
| `lib/services/prefs.dart`, `ui/favorites.dart` | Migrate `{n,v}` references to stable book/item IDs without losing ordering, category membership, recents, or settings |
| `lib/models/hymn_metadata.dart`, `hymn_video.dart`, `additional_reading.dart`, `hymn_occasion.dart` | Namespace metadata, readings, videos, and topics by book; keep printed readings separate from similarly numbered songs |
| `lib/services/hymn_search.dart` | Unicode normalization, optional accent-folded search, locale-aware refrain labels; index installed books and retain existing ranking |
| `lib/services/midi_player.dart`, `midi_cache.dart` | Use explicit MIDI assets/capabilities; replace old/new-only path and cache rules |
| `lib/services/playback_continuation.dart`, `ui/hymnPage.dart`, `hymn_video_overlay.dart` | Continue the same selected queue across books/media; one owner for playback and pause cancellation |
| `lib/main.dart` and UI text | Flutter localization resources and locale selector independent of the selected hymnal |
| `analytics/server/collector.py`, `error_reports.py`, schema, trends/admin | Version book identities end to end; current server only accepts old/new and their number ranges |
| `tool/build_*.py`, `tool/data`, `assets` | Extend the existing source → normalize → generated-asset workflow instead of parsing upstream formats in widgets |

### Proposed internal contract

- `HymnalEdition`: stable ID (for example `sda-en-1985`), language tag, native
  display name, edition/year when verified, collection kind, completeness notes,
  ordered item IDs, content version, and source provenance.
- `HymnRef`: book ID plus stable item ID. Keep printed number/page label separate;
  do not use array position or language alone as identity. Bundled numeric books
  can use their verified number as the item ID.
- `HymnContent`: title, optional original title/credits, ordered verse/refrain
  blocks, optional refrain playback order, plain text for search/share, and topic
  references. Preserve source text; escape plain text when producing legacy HTML.
- `MediaCatalog`: explicit MIDI, ordered score pages, instrumental recording,
  vocal recording, and video per item; include version/hash/size where managed.
  Absent capabilities hide unsupported controls. PNG scores are not transposable
  notation and recorded audio does not supply separable choir voices.
- `TuneLink`: reviewed relationship with evidence and confidence, distinct from
  a translation link. Sharing a tune alone does not establish identical rhythm,
  repeats, verse order, or suitability for the existing MIDI arrangement.

### Import and release workflow

1. Pin source commits and paths in a source manifest under `tool/data`; keep
   provenance and locally reviewed overrides separate from upstream snapshots.
2. Add adapters for GoGoShift text, VideoPsalm JSON, and wanmigs stanza formats.
   Produce a common schema. Preserve non-Latin text, line breaks, stanza order,
   original numbering, source IDs, and special refrain endings.
3. Validate duplicate IDs, empty text, malformed encodings, missing numbers,
   topic references, score page ordering, media mappings, and source/output hashes.
   Generate a human-readable diff and quarantine unresolved records; never silently
   renumber or overwrite a previous edition.
4. Review a sample from each book with a language reader and verify edition
   identity/completeness. Published pack metadata must disclose partial coverage.
   Failed books do not block already reviewed books.
5. Generate deterministic JSON packs and a catalog using the pattern of our
   current metadata/readings builders. First integrate a small bundled pack;
   later publish versioned optional downloads with counts, sizes, minimum schema,
   and checksums. Do not depend on upstream default branches at app runtime.
6. For downloads, stage and validate before activation; retain the previous
   working version on interruption or failure. Keep English bundled, offer
   separate score/audio downloads, and show storage/removal controls. Retain
   favorites for removed packs so reinstalling restores their references.
7. Compare source updates in reviewable commits. Keep source corrections, import
   tooling, and app features separately reviewable. App-release validation still
   includes the normal iPhone installation workflow when runtime changes land.

### Migration and rollout order

1. **Foundation:** introduce the catalog/repository with English 1941/1985 adapters.
   Map `old` → `sda-en-1941`, `new` → `sda-en-1985`. Write migrated preferences to
   new versioned keys, verify them, and retain old keys for recovery. No silent
   catch-and-reset of favorites. Readings retain their own item kind and IDs.
2. **First language release:** Spanish 2009/1962, Portuguese 1996, Russian 1997;
   book selector, search, topics, and shared reader. Preserve both Modern and
   Classic behavior. UI localization can follow incrementally; text content alone
   does not make all settings translated.
3. **Media:** English/Spanish/Russian score packs with explicit missing-page
   handling. Add recorded-audio selection separately from MIDI/video. Never choose
   an English MIDI by matching a foreign hymn number. Jazz/choir remain available
   only for explicitly verified MIDI-backed items.
4. **Breadth:** reviewed Rejnac packs, then partial Tagalog/Cebuano and optional
   supplemental songbooks. Download only what the user selects.
5. **Worship tools:** ordered service playlists, custom book imports, and
   presentation export build on stable content identities.

Deploy a compatible analytics/error-report schema before emitting new book IDs;
continue accepting older clients. Until then, suppress unsupported per-hymn
events rather than reporting another language as English. Keep existing public
statistics comparable, bounded, and subject to the existing opt-out/suppression
rules. Use per-book popular lists only when enough data exists.

### Required checks for implementation

- Upgrade real legacy favorites/recents/category fixtures twice: migration must
  be idempotent and preserve memberships, order, English assets, and settings.
- Same number in several books must resolve to separate lyrics, media, topics,
  cache entries, error reports, and statistics.
- Validate foreign scripts, accents, refrain structure, large text, dark mode,
  Modern/Classic layouts, sparse numbering, and any future right-to-left packs.
- Check a missing MIDI/score/recording independently; one missing medium must not
  prevent reading. Test score multipage order and samples against printed pages.
- Test interrupted pack downloads, hash/schema failures, offline restart, update
  rollback, pack removal/reinstall, and retained user references.
- Exercise MIDI/video/recording end events, manual start requirement, pause during
  loading, queue order, duplicate playlist entries, and unavailable-media skips.
- Validate backend compatibility and bounded search performance on the full
  installed catalog before choosing whether SQLite FTS is needed. Start with the
  existing search abstraction; Adore's database is a useful option, not a mandate.

## Feature comparison and roadmap decisions

| Feature found | Our current app | Roadmap action |
|---|---|---|
| Multiple language editions (GoGoShift, Adore, Rejnac data) | English old/new | Add catalog, language packs, selector, and migration |
| Zoomable multipage scores (GoGoShift, Adore) | Already an unchecked roadmap item | Expand that item with source coverage and offline packs |
| Recorded vocal/instrumental choice (GoGoShift) | MIDI styles and YouTube | Add optional recordings with explicit availability |
| Persistent player/system media controls (GoGoShift) | Reader owns playback; no equivalent system controls found | Add background playback and lock-screen controls |
| Ordered service playlists (Adore), favorite reordering (GoGoShift) | Named favorite categories, deduplicated/prepended entries | Add ordering; service entries may repeat and mix books/readings |
| Import custom hymnals (Adore) | Bundled content | Add validated user book import |
| Share selected/full lyrics (GoGoShift) | No hymn-sharing flow found | Add copy/share with book and number |
| Full history and clear action (GoGoShift) | Six recent chips | Add history page and clear control |
| Alphabetical jump index (GoGoShift) | Ranked search | Add locale-aware A–Z browsing |
| Accent normalization/localized UI (GoGoShift); Unicode FTS (Adore) | Unicode letters retained, but accents not folded; English UI | Add multilingual search and localization workflow |
| Youth/Scripture collections (wanmigs data) | Hymns and responsive readings | Add optional collections; avoid confusing songs with readings |
| VideoPsalm presentation workflow (Rejnac) | No export | Add later projection/export exploration, explicitly proposed |
| Keypad, themes, text size, favorites, topic lists, continuous play | Already present | No duplicate roadmap items |

Our musical styles, configurable instruments/mix, choir-part practice, generated
chords, hymn stories, responsive readings, category-aware autoplay, and community
statistics already provide substantial differentiation. The next useful work is
content breadth and practical worship tools; importing another app wholesale
would discard that investment.

See [the product roadmap](../ROADMAP.md) for unchecked deliverables and the
recommended next sequence. This audit did not install/run the competitor apps,
listen to every recording, certify translations, or publish any content packs.
