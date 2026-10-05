# Worship-service playlists

Status: saved sequence foundation implemented; editor and reader integration
remain in progress. This is not yet a user-visible feature and the roadmap item
stays unchecked.

Services will be reached from Favorites without adding a new main tab or controls
to the number pad. A named service contains ordered occurrences of hymns and
readings. The same hymn may appear several times; every occurrence has its own
ID. Each item retains its canonical book ID, item ID, and hymn/reading kind.
Unavailable books remain in the list and must be shown as unavailable rather
than silently omitted or substituted.

The service reader will reuse the existing hymn and reading screens. Previous
and Next follow occurrence order, across books, stopping at the service ends.
Autoplay may continue only to the immediate next entry when that entry supports
the current playback medium. Readings and unavailable media stop automatic
advancement; users advance those entries manually. A service must never skip a
reading, jump ahead to a playable hymn, or loop back to the opening hymn.

## Saved data

`servicePlaylists.v1` is a separate SharedPreferences envelope with schemaVersion
1 and a playlists array. Favorites, favorite categories, and their migrations are
unchanged. The model permits repeated references but rejects duplicate occurrence
IDs within a service and duplicate service IDs in the collection. References to
uninstalled books and nonnumeric item IDs survive round trips.

The store serializes edits against the latest verified sequence, writes and
reads back each snapshot, then publishes the new list. Loading invalid data or a
future schema protects the stored value by disabling writes until a successful
reload. A storage error is exposed to the upcoming editor; it must never dismiss
an edit as saved when the operation failed.

## Remaining integration and acceptance checks

- Add a service list/editor within Favorites, with naming, deletion confirmation,
  hymn/reading search, repeat insertion, removal, and drag ordering.
- Use occurrence IDs in reader navigation and progress labels, including repeats.
- Preserve manual-start/pause rules, stop at readings, and stop at service ends.
- Show unavailable entries without deleting or skipping them.
- Check compact screens, larger text, both designs and light/dark modes; keep
  existing favorites and the number pad intact.
- Test restart persistence, rapid edits, invalid storage, repeated hymns,
  mixed-language navigation, and hymn–reading–hymn playback boundaries.
