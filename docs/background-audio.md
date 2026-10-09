# Background audio and system media controls

This roadmap feature remains in progress. The system audio handler and platform
background configuration are connected. Device validation, interruption coverage,
and a shared queue independent of the reader remain before completion.

The first prerequisite is implemented: `MidiPlayer.pause()` and `resume()` are
explicit serialized commands for native MIDI and recorded audio. Repeating either
command leaves the state unchanged; neither loads a new file or downloads a song.
They preserve playback position and current hymn identity, use the existing rate,
and do not start anything when no track is loaded. A failed engine command leaves
the reported state unchanged and does not poison later queued commands.

The next integration should wrap the existing engines in one audio handler rather
than creating a second player. The [audio_service package documentation](https://pub.dev/packages/audio_service)
describes system callbacks and platform setup. Retain the established
manual-start rule, explicit user pause, category/service ordering, verified media
identity, and on-demand bounded recording cache. Do not download entire books or
bundle new audio for background playback.

Before completing this feature, validate native MIDI and recordings, engine
switching, headphone removal, calls/interruption resume rules, lock-screen play,
pause and seeking, Android notification controls, background completion and queue
advancement, and reader lifecycle. Video remains governed by its supported player
behavior and must not compete with the audio handler for system controls.

`HymnalAudioHandler` observes the existing player and publishes stable book/item
identity, source title, source edition, duration, rate, and playback state. System
play/pause/stop and absolute seek/ten-second seek commands call the same engines.
No system Play event starts a song if none is loaded. Instrument previews do not
publish a media item. Position updates are throttled to once per second.

Startup initializes audio_service and configures a music session after the player
plugins load. Calls/audio interruptions and headphone removal request an explicit
pause; resumption always requires the user. Initialization failure is recorded
and does not prevent the app from opening. Android uses AudioServiceActivity
while retaining the existing launcher aliases and icon channel, with a media
foreground service and receiver. iOS declares only the audio background mode.

Bridge tests cover source metadata, repeated system commands, failed pause
recovery, native/recording switches, absolute and relative seek, and stopped
metadata clearing. They do not prove lock-screen behavior on physical hardware.
Category/service queue ownership and completion currently remain in the reader;
background queue persistence and screen-independent advancement still need work.

Queue groundwork now uses `HymnPlaybackQueue`, an immutable occurrence snapshot.
Category continuation uses this model to retain displayed order, skip unsupported
media within that list, and wrap. Service snapshots can retain repeated hymn
occurrences and null reading/unavailable barriers with no wrapping or skipping.
The selected occurrence must be carried separately from hymn identity before
service/system integration, since the same hymn may appear twice. The model is
connected to existing category target selection; background ownership and system
next/previous wiring remain pending.
