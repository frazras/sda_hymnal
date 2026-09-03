# Classic design and Old Hymnal corrections

Implemented 28 August 2026 in the same app, not as a separate legacy binary.

## Design choice

Settings → App design offers Modern (default) and Classic. The saved
`appDesign` preference is independent of `theme` (System/Light/Dark) and
`midiTheme` (instrument/accompaniment). Missing or unknown values use Modern.
Switching preserves the active tab, number entry, search query, favorites,
recent hymns and font size. Existing installs remain Modern until changed.

Classic draws on the pre-redesign Flutter screens in Git (`6a860f7`, with
later pre-redesign behavior at `212e3aa`): historical logo, top Numbers /
Search / Settings navigation, rectangular outlined keypad with OLD / NEW
buttons, dark search field with cycling hymnal filter, bordered list rows,
and a plain lyric reader. Favorites remain accessible from the header.
Light and dark mode both work. Swipe and keyboard previous/next navigation
are retained. On New Hymnal pages, the header music-note icon shows or hides
the current playback controls without stopping the music; Classic starts
with the player hidden. Old Hymnal pages do not claim to have tunes.

This restores the familiar layout, not the old application's dependencies
or defects. The current settings, accessible touch targets, data, bounds
checks, screen-wake handling and MIDI engine remain shared. Top tabs are
tapped rather than swiped. It is not an exact binary/pixel restoration.

## Lyric corrections

Only two records in `assets/hymns.json` changed:

| Edition / number | Correction | Evidence |
| --- | --- | --- |
| Old 533 — On a Hill Far Away | Restore four stanzas plus refrain; body previously held 534's hymn. | [1941-specific transcription](https://adventisthymns.com/en/1941/lyrics/533/on-a-hill-far-away); [Hymnary's 1941 number/title record](https://hymnary.org/hymn/CHSD1941/533). |
| Old 534 — Tell Me the Story of Jesus | Restore its existing three-stanza/refrain body from the former Old 533 record, replacing the duplicate of 535. | Existing repository text and [Hymnary's 1941 number/title record](https://hymnary.org/hymn/CHSD1941/534). |

Old 535 (“'Tis Finished”) is unchanged. The user's photographs show the
**1985 New Hymnal**, whose 533–535 are O for a Faith, Will Your Anchor Hold,
and I Am Trusting Thee, Lord Jesus; those records were deliberately untouched.

The 533 transcription is listed as public domain by Adventist Hymns.
Apostrophes are normalized to the app's ASCII convention and stanza/refrain
markup follows the existing Old Hymnal format. Hymnary confirms edition,
number, title and opening/refrain, but its linked page images could not be
retrieved in this run. This is web-backed restoration, **not a claim of
line-by-line verification against a photographed 1941 book**. The restored
534 wording is preserved, not replaced with a generic or 1985 variant.

Regression tests lock the corrected openings, stanza counts and distinct
533/534/535 bodies, and the different New Hymnal identities. Other open
1941 issues (576 and 160/161) are outside these two corrections.

## MIDI integration

The completed SDA port from the task **Build Caribbean choruses app** was
already present as uncommitted changes and is retained. See
[MIDI playback and diagnostics](midi-playback.md) for its evidence, corrected
soundbank, paired iOS reggae volume, cache/export and lifecycle safeguards.
Both visual designs use that same player; selecting Classic design does not
select Classic instrumentation or discard the island styles.

The unfinished Caribbean-specific singlist/chord-timing work was not copied.
SDA keeps its single-hymn player, reggae 3/4-to-4/4 conversion and calypso 3/4.
Automated render/native lifecycle checks cannot certify perceived sound on
every physical device; final listening should use an SDA release build on
an iPhone and Android phone before store submission.

## Combined verification — 28 August 2026

- `./scripts/verify.sh`: 244 Flutter tests and 10 soundbank tests passed;
  static analysis found no issues. Coverage includes persisted design choice,
  retained keypad/search state, edition bounds, Old 533 → 534 → 535 swipes,
  narrow light/dark readers, and play/pause/resume/exit cleanup in both layouts.
- `./scripts/test_ios_midi.sh`: all 7 native tests passed on the iPhone 16 Pro
  simulator (iOS 18.2), including the bundled corrected bank's exact hash.
- Simulator visual checks: Modern ↔ Classic, light/dark, keypad previews,
  distinct Old/New search results, corrected Old readers and sequential
  navigation. Island Reggae in the Classic reader showed advancing progress
  and responded to pause; changing the design retained the instrument choice.
  QA captures are local, ignored artifacts in `build/design-qa/`.
- `./scripts/build_ios.sh`: signed iOS release built successfully; code-sign
  verification passed. Packaged hymn JSON matches the source, and the built
  soundbank matches the verified derivative byte-for-byte by SHA-256.
- `flutter build appbundle --release`: Android release bundle built
  successfully at `build/app/outputs/bundle/release/app-release.aab` (58.2 MB).
  Its packaged hymn JSON also matches the corrected source exactly.

No physical-device installation, store upload or publication was performed.
