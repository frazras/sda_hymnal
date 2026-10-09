# Background audio and system media controls

This roadmap feature remains in progress. The system audio handler and platform
background configuration are connected. Physical device validation and broader interruption coverage remain before
completion. Audio queue ownership is now independent of reader rendering.

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
Category/service queue ownership and audio completion now live in `AudioQueue`.
The reader observes occurrence selection and catches up after rendering resumes.
Leaving the reader deliberately still stops its own queue; minimizing the app
continues audio. Video continuation remains in the video reader.

The queue uses `HymnPlaybackQueue`, an immutable occurrence snapshot. Categories
retain displayed order, skip unsupported media within that list, and wrap.
Services retain repeated occurrences and stop at reading/unavailable barriers
without wrapping. System next/previous actions use the same queue and are offered
only when a playable adjacent occurrence exists. Repeated service hymns restart
as separate occurrences rather than toggling the same hymn into pause.

Explicit pause, interruptions, and headphone removal invalidate pending automatic
advancement. Preparation checks cancellation before loading/starting the next
hymn. No initial selection starts audio: a user Play action remains required.
Tests cover suspended reader rendering across two advances, catch-up on resume,
repeated service entries, queue boundaries, failed-load retry, cancellation during
preparation, and retained source identities and sheet-view state. The singleton
platform-player scenario stays in one fake-clock widget test so event subscriptions
are not stranded in a disposed test zone. Physical screen-lock, headphone, call,
and Android notification checks still remain; these tests do not substitute for them.
