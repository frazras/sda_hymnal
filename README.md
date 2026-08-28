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

Choose **Settings → App design → Classic** for the familiar older layout,
or **Modern** for the current design. This is separate from the music style
and light/dark setting; favorites and reading preferences are shared.
See [Classic design and lyric corrections](docs/classic-design-and-lyrics.md).

```sh
flutter pub get
./scripts/verify.sh
flutter run
```

See [MIDI playback and diagnostics](docs/midi-playback.md) for the soundbank
fix shared from Caribbean Choruses, exact MIDI exports, cache safeguards,
native tests, and checked iPhone build/install scripts.

[Android app](http://bit.ly/SDAHymnal) · [Facebook](https://www.facebook.com/SDAHymnalApp/)
