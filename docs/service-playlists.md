# Worship-service playlists

Service playlists are available from Favorites → More favorites options →
Service playlists. Create a named service, add hymns or readings by number or
title, and drag their handles into order. Tap an item to open the shared reader.
The item menu can repeat an entry at the end or remove that occurrence; the
service list menu offers rename and confirmed deletion.

Services use the existing Favorites options menu without adding a new main tab
or controls to the number pad. A named service contains ordered occurrences of hymns and
readings. The same hymn may appear several times; every occurrence has its own
ID. Each item retains its canonical book ID, item ID, and hymn/reading kind.
Unavailable books remain in the list and must be shown as unavailable rather
than silently omitted or substituted.

The service reader reuses the existing hymn and reading screens. Previous
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
reload. The editor shows a storage notice and disables editing after an error. Retry
reloads persisted data before allowing edits. Failed writes display an error
rather than publishing an unsaved sequence.

## Validation

- Editor tests cover creation, accent-insensitive Spanish selection, repeated
  entries, reading insertion, drag ordering, reload, and protected invalid storage.
- Reader tests cover occurrence IDs and progress labels, including repeats.
- Playback tests cover manual start, pause, repeated playback, and service-end
  stopping; boundary tests reject automatic advancement into readings or missing media.
- Unavailable entries retain their sequence position with manual Previous/Next.
- Compact 320×568 layouts at 1.3× text are checked in both designs and light/dark
  modes, including rendered inspection. Existing favorites and keypad tests run
  alongside the service tests.
- Store tests cover restart persistence, rapid edits, invalid/future storage,
  mixed editions, readings, repeated references, and unavailable item retention.
