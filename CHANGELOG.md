# Changelog

Releases of Old & New Hymnal. The version code is `major * 10000 + minor * 100 + patch`
(see `pubspec.yaml`); the store "what's new" text for each release is the matching
file under `android/fastlane/metadata/android/en-US/changelogs/`.

## Unreleased

- Read offline sheet music for all 695 New Hymnal numbers from the hymn menu.
  Zoom and pan, move between score pages, and return to lyrics while music
  continues. Available in Modern and Classic layouts, including dark mode.

## 4.5.0 (40500) — prepared (2026-09-25)

- Keep the actual melody in front when source voices share MIDI channels, including New 388.
- Correct 6/8 accompaniment timing across all musical styles, including Old 653 and New 388.
- Keep popular hymn shortcuts visible and improve dark-mode menu opacity and page-turn shading.
- Add optional autoplay for music and videos, continuing through the current hymn list after a manual start.

- Add Jazz accompaniment with piano chords, walking acoustic bass, and swung drums.

- Enjoy Jamaican Gospel accompaniment with its original synchronized rhythm and a 15% faster default tempo.
- Change musical style and toggle Choir Practice directly from the hymn menu.
- Reach every musical style in the scrolling picker, with Caribbean choices grouped together.
- Adjust drum-kit volume or solo the drums in all five backing styles; soloing another part now silences the kit.
- Find musical-style instrument controls below Sound in Settings and preview your ensemble with Amazing Grace.
- Find hymns more easily with search that prioritizes titles and opening lyric lines.
- Save favorites with refreshed heart feedback and a gentle reminder at the end of a hymn.
- Refresh generated MIDI caches for the corrected percussion mix.

## 4.4.0 (40400) — published

- Add opt-in Choir Practice with source-track names, mute, solo, instrument
  selection, and compact per-track volume controls.
- Add ensemble instrument customization, volume, solo, and previews in Settings.
- Expand the instrument picker to 111 presets in 11 common categories.
- Add automatic sustained-note steelpan rolls at six strikes per second.
- Explain that choir practice overrides the ensemble style; preserve original
  part timing and keep optional controls hidden until enabled.
- Make zero ensemble volume silent and honor volume-only adjustments during
  original-style Android playback.

## 4.3.0 (40300) — unreleased (2026-09-11)

### Additional readings and topics
- Add all 225 New Hymnal readings, numbered 696–920, with category and
  Scripture-reference metadata.
- Give readings a dedicated non-musical reader with the printed responsive
  typography, search and category filters, a reading-speed auto-scroll, and
  previous/next swipe navigation.
- Resolve reading numbers from the main keypad and label their result and
  category. Place the occasion and additional-reading browsers together below
  hymn search.
- Transcribe and integrate the New Hymnal topical index. Topic pages combine
  hymns with their referenced Scripture readings while keeping Old and New
  Hymnal numbering separate.

### Stories
- Restore inline titles, quotations, and passages omitted from the original
  ShareFaith import. Join the split “Because He Lives” account into one story
  and retain a reproducible archive-recovery tool.

### Community statistics and privacy
- Add privacy-conscious, offline-first usage summaries with a persistent
  Settings opt-out, bounded local storage, weekly uploads, retry-safe counting,
  and predefined diagnostic categories.
- Add an offline-capable Community Statistics page for popular hymns, repeat
  visits, favorite additions, days, broad times, and country highlights.
- Add the deployed aggregate collector, public suppressed reports, private
  administrator dashboard, operational verification, and updated privacy
  policy. No search text, advertising identifier, contact data, or raw event
  history is collected.

## 4.2.0 (40200) — 2026-09-05

- Add hymn stories, writer and composer details, and matching hymn videos.
- Add music playback, transposition, chords and auto-scroll to all 703 Old
  Hymnal songs, with the correct verse and chorus counts.
- Repeat each hymn's chorus after every verse, including the final verse, in
  both the Old and New Hymnals.
- Keep all 3/4 hymns in their written meter, with continuous offbeat reggae
  skanks and continuous steelpan responses in Calypso.
- Keep auto-scroll running after manual reading adjustments, add a speed
  slider, and make speed controls available from anywhere in the hymn.
- Let the music player stay hidden across songs and app launches, and restore
  the favorite button to the hymn header.
- Keep the lyrics visible below an in-app hymn video while it plays.
- Add an in-app, version-by-version update history and show it once when a
  user first opens each new version.
- Move Appearance near the bottom of Settings, immediately before More.
- Remove the external donation flow to comply with app-store payment rules.

## 4.1.1 (40101) — 2026-08-28

- Match the home-screen icon to the selected app design on iOS and Android:
  original green/black icon for Classic, current icon for Modern. Modern
  remains the default. Reconcile saved preferences on launch/resume and
  offer an icon-only retry if the operating system rejects a change.
- Add Settings → App design → Modern / Classic. Classic restores the
  pre-redesign logo, top navigation, outlined number pad, search rows and
  simple reader, while retaining current favorites, font settings and music.
  The choice persists independently of light/dark mode and instruments.
- Restore the missing Old Hymnal 533 text (On a Hill Far Away) from an
  edition-specific web transcription; move the displaced Tell Me the Story
  of Jesus text back to Old 534. Old 535 and New 533–535 are unchanged.
  See `docs/classic-design-and-lyrics.md` for sources and verification limits.

- Port the range-scoped piano soundbank from Caribbean Choruses to prevent
  Apple's sampler from stacking unrelated long-release layers and dropping
  chord tones. Pair it with the revised iOS reggae piano mix.
- Share the playback/export renderer; add exact full and piano-only MIDI
  exports, versioned atomic cache writes, and stale-cache detection.
- Guard native completions across pause/resume, replacement and replay;
  preserve a valid player on failed loads and reactivate audio on resume.
- Add soundbank, cache/export and native lifecycle regression checks plus
  release-only, data-preserving iPhone installation safeguards.

## 4.1.0 (40100) — 2026-08-23

### Old Hymnal
- Verse numbers and **CHORUS** labels, exactly as the New Hymnal shows them. The
  Old Hymnal's 703 lyrics had carried no markup at all since the 2016 app; 681
  hymns are now numbered and 170 have a styled chorus, derived from each hymn's
  own stanza structure (`tool/old_hymnal_verse_markup.py`). Every lyric word is
  unchanged. Four records fixed by hand on the way: 103 (a refrain repeated as a
  reminder after every verse), 421 (opens with its refrain, as the New Hymnal's
  93 does), 477 (had no line breaks at all), 535 (stray HTML from a scrape).

### Music
- **Island Reggae rebuilt** as a transcription of two reference recordings
  rather than from a description: the piano chop on beats 2 and 4 only, one
  steady tempo from first bar to last, the drop voiced as two kicks under a
  cross-stick, organ between the beats and held under the drop. Hymns in 3/4
  are played in four (each bar's last beat held through an added fourth) so
  the one-drop cycle fits.
- **iOS sound fixed.** The phone's synth plays the soundfont's keyboards 11–17
  dB louder than intended and was clipping the piano on every chop — the
  reason the reggae backing sounded harsh no matter how it was arranged. The
  reggae render now carries a measured per-channel correction on iOS.
- Island styles no longer follow a hymn's ritardandos and fermatas; the beat
  holds one tempo throughout.

### Reading
- **Keep screen on** while a hymn is open (Settings; on by default), so a
  propped-up phone doesn't lock mid-verse.

### Known limitations
- The island styles assume 3- or 4-beat bars; hymns in 6/4, 9/4, 12/4 and
  2-beat meters are not yet handled.

## 4.0.1 (40001) — 2026-08-21

- App-specific privacy policy, linked from the About screen.

## 4.0.0 (40000) — 2026-08-17

- First release since 2020: the app rebuilt from its Cordova origins as a
  Flutter app, with audio playback, chord tools and generated accompaniment
  styles (Gospel, Island Reggae, Steel Pan Calypso).
- Ten years of in-app bug reports mined; 27 lyric corrections applied.
- New-Hymnal 314 restored (the 2016 data carried a truncated copy of 313 in
  its place).
