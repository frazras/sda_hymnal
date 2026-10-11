# Offline sheet music

The hymn menu's **Sheet music** action opens the score inside the existing reader.
Use pinch/drag or zoom buttons, Previous/Next score page, Fit score to screen,
and Lyrics to return. The music player remains below the score rather than
covering it. While viewing scores, horizontal dragging pans the image instead
of turning to another hymn; hymn navigation is still available in the player.

The collection covers all 695 English New Hymnal numbers (723 pages), all 614
Spanish 2009 numbers (614 pages), and 384 Russian 1997 numbers (506 pages).
Russian #244 has no source score and shows a clear unavailable state. Spanish
1962 and Portuguese have no matched score collection yet. Old English songs show an unavailable
message instead of borrowing a same-numbered New Hymnal score. Page controls
reset zoom when changing score pages. Printed scores retain their original key
and arrangement, even when MIDI is transposed or played in a different style.

Scores stay on the same reader route, so changing between lyrics and scores
does not stop or reload music. Autoplay retains score mode and current category
order; a next song without a score still has its normal playback controls.
Both reader designs share this implementation. No persistent preference or
favorite migration is required for this first feature.

## Provenance and rebuilding

Source: [GoGoShift/Hymnal-Flutter, revision 42e1263](https://github.com/GoGoShift/Hymnal-Flutter/tree/42e1263684ddd756841f11581611b9c9c6cc574f/assets/musicSheets).
Images are imported unchanged. `assets/sheet_music/catalog.json` records source
revision, page order, dimensions, byte lengths, and SHA-256 checksums. The source
assets are attributed to that project; no remote server is needed at runtime.

```sh
python3 tool/import_sheet_music.py
python3 tool/import_sheet_music.py --check
```

The importer fetches a pinned Git tree, checks each download against its Git
blob checksum, verifies PNG dimensions and complete/ordered coverage, and writes
the catalog only after every page succeeds. Existing verified downloads are
reused. `--check` checks the committed catalog and assets without network access.

The catalog uses stable book IDs (`sda-en-1985`, `sda-es-2009`, and `sda-ru-1997`). The model translates
legacy `new`/`old` only at the lookup boundary; it does not implement the broader
multilingual migration. Future books need their own explicit score associations.

## Validation

- Catalog tests cover all numbers, multipage order, missing editions/numbers,
  unsupported schemas, and invalid asset paths.
- Viewer tests cover zoom/page resets, missing scores, failed-catalog retry,
  changing hymns, narrow screens, and Modern/Classic light/dark themes.
- Reader tests verify switching views leaves active audio playing without a
  reload; the autoplay regression verifies that score mode survives advancement
  into a different edition and that pausing prevents further advancement.
- `python3 tool/import_sheet_music.py --check` verifies all 1,843 bundled pages.

See [the broader integration plan](multilingual-resource-audit.md) for language
packs, recorded audio, and the remaining catalog/persistence migration.

## Download integrity foundation

The runtime catalog retains each page's byte count and SHA-256 checksum for
future optional-pack installation. It rejects empty catalogs/books/page lists,
noncanonical hymn numbers, invalid book identities, duplicate page assets,
wrong-edition directories, malformed checksums, and unbounded dimensions/sizes.
A page validator checks exact bytes, checksum, PNG signature, and IHDR dimensions
before a downloaded page may be activated. Regression checks apply it to all
1,843 published pages and reject changed, truncated, mislabeled, and non-PNG data.

This does not yet implement score-pack downloads or remove bundled score images.
The existing offline viewer and its page order are retained. Score transport
and atomic storage are implemented below. Management controls remain unfinished; installed-file viewer loading is
implemented below.

## Atomic score storage and transport

`ScorePackDownload` snapshots one edition's validated catalog and pins its image
URLs to a full Git commit on raw.githubusercontent.com. Each collection is
limited to 5,000 pages and 256 MiB; each page retains the validator's 16 MiB cap.
`downloadScorePage` rejects redirects/status/size mismatches, buffers only one
bounded page, validates its checksum and PNG header, and supports cancellation
and request/idle timeouts. It does not start networking on initialization.

`ScorePackStore` serializes mutations and writes all pages to a staging folder.
Only a complete verified collection activates through an atomic pointer rename.
Cancellation or a bad page removes staging and keeps the prior pointer. Successful
replacement cleans obsolete revisions. Offline reopening verifies every stored
page; corrupt or linked files return no installed pack for bundled fallback.
Removal deactivates only that edition and leaves unrelated data untouched.

Twenty focused storage, transport, catalog, and viewer regressions pass. The
transport uses mocked responses; this does not claim a published optional score
catalog or physical download-flow validation. The trusted score catalog publisher,
Settings management remain to be connected.

## Installed score viewer integration

Opening scores checks the local collection for that exact book, without starting
networking. Verified installed pages use file images through the same zoom/page
controls. Bundled pages remain available for hymns omitted from a partial local
collection; missing, corrupt, or unreadable local content falls back to bundled
scores. Switching books refreshes the source and resets page/zoom position.
Opening or changing score pages retains the reader's playback owner.

Source-loading tests cover installation, exact-edition isolation, partial
coverage, corruption, removal, and zero implicit downloads. Rendering checks
open real installed PNGs and turn pages. Existing theme/locale and playback
continuation checks remain in the focused suite. The Settings score controls and trusted collection catalog are now implemented
below; the current published collections remain bundled.

## Trusted score download catalog

`assets/sheet_music/downloads.json` adds only 832 bytes of metadata. It pins the
three existing collections to a published repository commit and records exact
hymn/page counts, byte totals, and included status. Its SHA-256 binds the complete
existing page catalog; no score images or page metadata are duplicated.

`tool/build_score_download_catalog.py` verifies every local PNG, its hash, size,
dimensions, edition directory, and unique assignment before generating metadata.
The offline content publication gate requires byte-identical regeneration. Use
`--check --verify-remote` to additionally verify the hosted page catalog against
its pinned checksum; this remote check does not download every hosted PNG.
The app reader rejects mutable revisions, checksum/coverage mismatches,
unknown/repeated collections, and incomplete metadata before creating downloads.

These collections remain included in the app. Settings score management now exposes included/installed states and avoids
redundant downloads. This
catalog does not claim an additional optional score collection is available.

## Score management controls

Settings > Hymnal downloads > Sheet music shows score collection sizes and
included/downloaded status. Optional entries offer download, progress, cancel,
update, and remove actions. A changed page catalog offers Update; changing only
the hosting revision does not create a redundant update. Closing the page cancels
a pending download. Removal affects local score copies only; included assets,
text books, favorites, service references, and music settings are retained.

The actual three collections are included and do not offer redundant downloads.
Compact regression fixtures exercise optional download, update, removal, failure,
and cancellation. They do not claim an additional optional score collection has
been published. Four interface locales and both designs are checked at 320×568
with increased text size. Published optional additions and physical device
workflow review remain separate follow-ups.
