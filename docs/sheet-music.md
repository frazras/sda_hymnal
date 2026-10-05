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
