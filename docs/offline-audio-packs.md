# Optional offline audio packs

This feature is in progress. The persistent store is implemented and tested;
playback integration and the Settings download/update/remove screen are pending.
The app still uses its existing temporary on-demand recording cache.

`RecordingPack` describes a complete edition with unique consecutive numbers,
exact book identities, declared sizes, and pinned Git blob hashes. Specifications
copy their entry list so a caller cannot mutate an in-flight download. The pack
revision hashes its complete ordered track metadata.

`RecordingPackStore` receives a persistent application directory and a downloader.
It stages one verified track at a time, reports completed-track and byte progress,
and writes a manifest before atomically replacing the active pointer. Download
failure, corruption, or cancellation leaves the previous revision active. The
store serializes installation and removal; failure does not poison its queue.

Lookups verify the requested track's bytes and hash, so a recording from another
revision cannot satisfy playback. Missing or corrupt files return no match for
playback to handle. Reopening a store needs no network for installed tracks.
Removal deactivates the edition before deleting its manifest-owned revisions,
without touching another book, favorites, settings, lyrics, or temporary cache.
Unsafe pointer paths and symbolic-link directories are ignored.

Old revisions remain on disk until removal, avoiding deletion beneath existing
readers. Before enabling the feature, add disk-space accounting, obsolete-revision
and crash-staging cleanup, installed-state reporting, production directory and
network wiring, and localized download controls with clear coverage and sizes.
The UI must offer cancellation, failure/retry and update states, preserve the
last working pack, and follow the existing compact-screen UX contract. Downloading
Spanish audio is optional: both full editions together require about 1.8 GiB.

Tests cover offline reopening, corruption, failed updates, atomic activation,
cancellation, complete numbering, cross-edition isolation, revision removal, and
serialized install/remove behavior using small verified fixture files. They do
not certify production downloads, device storage behavior, or a finished UI.
