# Changelog

Releases of Old & New Hymnal. The version code is `major * 10000 + minor * 100 + patch`
(see `pubspec.yaml`); the store "what's new" text for each release is the matching
file under `android/fastlane/metadata/android/en-US/changelogs/`.

## 4.1.0 (40100) — unreleased

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

## 4.0.1 (40001) — 2026-08

- App-specific privacy policy, linked from the About screen.

## 4.0.0 (40000) — 2026-08

- First release since 2020: the app rebuilt from its Cordova origins as a
  Flutter app, with audio playback, chord tools and generated accompaniment
  styles (Gospel, Island Reggae, Steel Pan Calypso).
- Ten years of in-app bug reports mined; 27 lyric corrections applied.
- New-Hymnal 314 restored (the 2016 data carried a truncated copy of 313 in
  its place).
