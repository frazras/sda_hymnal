# SDA Hymnal — Old and New

Flutter app for iOS and Android, with hymn lyrics, favorites, chord tools and
MIDI accompaniment in Classic, Gospel, Island Reggae and Steel Pan Calypso styles.

Choose **Settings → App design → Classic** for the familiar older layout,
or **Modern** for the current design. This is separate from the music style
and light/dark setting; favorites and reading preferences are shared.
Modern is the default. Selecting Classic also restores the original home-screen
icon; switching back restores the Modern icon. See
[icon behavior and platform notes](docs/app-icons.md).
See [Classic design and lyric corrections](docs/classic-design-and-lyrics.md).

### Reading and auto-scroll

Hymns with choruses show a chorus after every verse, including the last.
Verse-specific refrains (such as Old 103's final chorus) are preserved.

Enable **Settings → Reading → Auto-scroll** (off by default). In the reader,
tap **Start** to scroll silently, or play the MIDI to follow its progress.
The single control row hides as scrolling starts. **Tap the lyrics** to pause
scrolling and reveal the controls; dragging the lyrics also pauses scrolling.
Tap Start again to resume. Leaving the reader or backgrounding the app pauses
the scrolling; reaching the bottom stops it and restores the controls.

Use **− / +** beside the speed value to adjust by 10% per tap, from **0.5× to
2.0×**, without changing the music's speed or jumping the lyrics. Tap the speed
value to reset to **1.0×**. Each hymn starts at 1.0×. Slower reading can continue
to the bottom after the music finishes.

Tap the **music note in the header** to hide or restore the bottom player
without stopping the music or auto-scroll. Classic starts with the player
hidden; Modern starts with it visible.

The full MIDI duration is 100% of the scrollable distance. Silent scrolling
uses `distance × playback speed × scroll speed ÷ MIDI duration` pixels per second, including
the selected arrangement's tempo changes. During music playback it follows
the player's position, pauses and seeks. Font/viewport changes recalculate the
distance. This is proportional scrolling, not word-by-word lyric alignment.
Both the New and Old Hymnal songs include MIDI timing and can auto-scroll.

```sh
flutter pub get
./scripts/verify.sh
flutter run
```

See [MIDI playback and diagnostics](docs/midi-playback.md) for the soundbank
fix shared from Caribbean Choruses, exact MIDI exports, cache safeguards,
native tests, and checked iPhone build/install scripts.

[Android app](http://bit.ly/SDAHymnal) · [Facebook](https://www.facebook.com/SDAHymnalApp/)
