# Background audio and system media controls

This roadmap feature remains in progress. Background execution, lock-screen and
notification integration, interruption handling, and a shared playback queue
are not enabled yet.

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
