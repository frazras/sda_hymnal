# Optional offline audio packs

Full-edition audio downloads are deferred following the storage preference on
9 October 2026. The app downloads only the selected recording on demand, using
its bounded 128 MiB temporary cache. Audio is not bundled with the app.

The persistent store is tested groundwork only. It is not connected to playback
or Settings and does not create files, fetch tracks, or reserve storage at runtime.
Do not enable full-pack downloads as part of the current roadmap. The source is
currently pinned GitHub hosting; an S3 migration remains a separate infrastructure
change and must preserve exact-edition identities and integrity verification.

`RecordingPack` describes a complete edition with unique consecutive numbers,
exact book identities, declared sizes, and pinned Git blob hashes. Specifications
copy their entry list so a caller cannot mutate an in-flight download. The pack
revision hashes its complete ordered track metadata. Recordings now carry a kind
(instrumental or sung) and the store's file names include it, but the pack and
its active pointer are still keyed by book alone. Before a sung pack can coexist
with an instrumental pack of the same edition, both must be keyed by book and
kind, and a pack must hold a single kind.

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
last working pack, and follow the existing compact-screen UX contract. Full
editions are large: Spanish instrumental needs 1.11 GiB (2009) and 0.72 GiB
(1962), Spanish 2009 sung 1.12 GiB, Portuguese 1996 sung 1.18 GiB, and Russian
1997 instrumental 0.42 GiB; the whole recording catalog is about 4.55 GiB.

Tests cover offline reopening, corruption, failed updates, atomic activation,
cancellation, complete numbering, cross-edition isolation, revision removal, and
serialized install/remove behavior using small verified fixture files. They do
not certify production downloads, device storage behavior, or a finished UI.
