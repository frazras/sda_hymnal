# Hymnal catalog foundation

The app now loads its English books through `HymnalRepository`. Book identities
are `sda-en-1985` and `sda-en-1941`; `new` and `old` remain compatibility aliases
for the existing reader, MIDI, analytics, metadata, and video interfaces.

`HymnRef` identifies a book, item, and kind. Hymns and Scripture readings cannot
collide, even with the same item label. Existing reading IDs are retained.
Repository lookups are exact and preserve sparse numbering. Duplicate IDs and
unregistered books are rejected. The adapter retains the original hymn objects,
including corrected English lyrics, metadata, and media associations.

This milestone does **not** enable foreign language books, translate the UI,
change backend identities, or infer cross-language MIDI mappings. Those remain
separate roadmap work. The reader still accepts numeric hymn identifiers;
non-numeric songbooks require extending its UI adapter before activation.

## Saved-data migration

On startup, favorites/categories and recents migrate independently:

| Original keys, retained unchanged | Active versioned key |
|---|---|
| `hymnalFavorites`, `hymnalFavoriteSublists` | `hymnalFavorites.v2` |
| `hymnalRecents` | `hymnalRecents.v2` |

Each envelope has `schemaVersion: 2`. Saved items carry `bookId`, `itemId`, and
`kind`, rather than English edition aliases. Favorites and their named categories
are written as a single envelope. IDs, names, order, and independent memberships
survive migration. Recents retain their existing six-item limit on new visits.
Other settings are untouched.

Migration validates the **whole** collection before writing, checks the storage
result, reloads it, and verifies the saved value. Existing versioned data is
authoritative on subsequent launches; it is never replaced with an older legacy
snapshot. Writes are serialized to preserve rapid tap order. Original keys are
recovery snapshots, not live mirrors; downgrading to an older app will therefore
show the favorites that existed before migration.

Malformed data or an unsupported saved schema protects that collection from
further writes and displays a retry notice. The app continues to support reading
and music. Retry reloads without deleting or resetting saved data. It cannot repair
malformed data itself. Numeric references to unavailable books are retained in
storage, but cannot fall back to an English song in favorites or recent chips.

## Validation

`hymnal_repository_test.dart` checks all 1,398 bundled hymns and 225 readings,
same-number isolation, sparse numbers, duplicate rejection, immutable indexes,
and English MIDI availability. `saved_hymn_migration_test.dart` exercises legacy
fixtures twice, verifies retained originals/settings, category order and
membership, unavailable books, rapid writes, malformed/future data protection,
and the retry notice. Existing favorite, design, score, and playback tests cover
the compatibility adapters.

## Next integration step

Add pinned imports for Spanish 2009/1962, Portuguese 1996, and Russian 1997.
Then replace the shell's English-only presentation adapters with installed-book
selection and capability-aware navigation. Extend search, topics, labels, and
backend reporting before exposing these books in the shared reader. A foreign
number alone must never select English lyrics, recordings, scores, or MIDI.
