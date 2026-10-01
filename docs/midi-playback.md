# MIDI playback: fixes shared from Caribbean Choruses

## What is preserved

SDA still plays one hymn at a time through `AVMIDIPlayer` on iOS and
`audioplayers` on Android. Its melody, voicings, note gates, velocities, tempo
maps, transposition, playback-rate controls and arrangement patterns are not
being replaced by the Caribbean Choruses arranger. Original MIDI assets and
the original GeneralUser GS bank remain unchanged.

In particular, **reggae still expands a 3/4 hymn into four beats** and
**calypso still uses its existing 3/4 pattern**. A separate reggae-in-3/4 option
is possible, but is not part of this port.

## Piano soundbank: correct the cause, not the MIDI notes

Both apps started with the exact same GeneralUser GS bank:

```text
9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe
```

Caribbean Choruses' Fire Fall On Me investigation established that valid MIDI
could sound correct on a Mac while the physical iPhone dropped piano tones.
The iPhone's sampler imported disjoint piano key/velocity ranges as overlapping
sample layers. The affected notes activated 18 zones instead of one; unrelated
8-second release tails consumed voices until skanks disappeared or became
single notes. Typed notes and explicit MIDI note-on/off events produced the
same failing audio. Lower velocities, another channel, and buffer changes did
not fix it. Clearing all voices before every chop hid the symptom but cut
tails, so that workaround was not shipped.

`tool/prepare_ios_soundfont.py` creates a separate instrument for each piano
preset zone, intersecting its sample key/velocity ranges before Apple's importer
sees them. It preserves sample PCM, headers, envelopes, modulators, intentional
overlaps and other presets. Verification exhaustively compares all 16,384
key/velocity combinations and checks the unaffected tables and metadata.

The iOS target now bundles `ios/Runner/Resources/ios-compatible/GeneralUser-GS.sf2`
under the same runtime filename, `GeneralUser-GS.sf2`. Its SHA-256 is:

```text
4a51f4cb5919ed9f552d9cb2c6f6b925bf8dcefc07828323ea2f5bf17fb4bc99
```

It is byte-identical to the fixed bank whose physical-iPhone captures passed
all 32 skanks / 96 tones in Caribbean Choruses. This is evidence for the bank
fix, not a claim that every SDA hymn has been recorded on the phone.

The corrected piano lost about 12 dB of excess layering. SDA's existing iOS
reggae mix therefore changes **only piano CC7 from 41 to 82** (+12.04 dB).
Rhodes, organ, bass and percussion keep their prior corrections. The earlier
SDA diagnosis attributed the gain difference to attenuation handling; the
later layer-import finding is additional, experimentally isolated evidence.
Do not pair the new piano volume with the original bank.

The shared bank correction also affects any classic MIDI using GM grand piano;
its audio need not sound identical to the old incorrectly layered piano.
Android does not use this bank, and its generated MIDI is unchanged.

## Adapt the implementation, not just the constants

| Concern | Caribbean Choruses | SDA Hymnal |
| --- | --- | --- |
| Native player | Queued MusicPlayers sharing one synth/output graph | Existing single-hymn AVMIDIPlayer |
| Piano channel (zero-based) | 0 | 1 |
| iOS piano volume | Native in-memory 41 → 82 | iOS render uses 82, cache revision 23 |
| Solo export | Conductor plus first instrument track | Find channel 1 / program 0; optional descant shifts its track index |

SDA does not gain a new queue or singlist UI in this port. If native queueing
is added later, reuse one multitimbral synth/output graph, preload sequences,
route their tracks explicitly, and avoid global all-sound-off messages at
normal handoffs. Reserve panic/silencing for stop, disposal and final completion.

## File management and lifecycle safeguards

- `renderHymnMidi` is shared by playback and the diagnostic exporter. Portable
  and iOS mixes are explicit; no export-only musical approximation is used.
- Cache revision 23 bypasses old CC7=41 files without erasing them. Keys include
  platform/bank mix, hymnal edition, hymn, theme, transposition and forced
  program.
- Render options are captured before asynchronous file access. Concurrent
  requests for one cache key share a render; a flushed staging file is renamed
  atomically. Truncated generated cache entries are regenerated.
- Original assets are never rewritten. Solo exports retain conductor and piano
  chunks byte-for-byte, including controllers, velocities, timing and note-offs.
- Native completions carry a generation token. A delayed pause/stop/old-file
  callback cannot finish a resumed or replacement hymn. Completion is one-shot.
- Replacement players are prepared before discarding a valid player. Audio is
  activated on each start/resume; activation failures are reported instead of
  returning a misleading playback success. Rate persists across loads.

## Export the exact MIDI for comparison

Run from the repository root using the Dart SDK bundled with Flutter. For
example, `flutter pub run` uses that SDK even if a different `dart` is on PATH:

```sh
flutter pub run tool/export_midi.dart assets/midi/015.mid /tmp/hymn-015-reggae.mid
flutter pub run tool/export_midi.dart assets/midi/015.mid /tmp/hymn-015-ios.mid --ios-mix
flutter pub run tool/export_midi.dart assets/midi/015.mid /tmp/hymn-015-ios-piano.mid --ios-mix --piano-only
flutter pub run tool/export_midi.dart assets/midi/001.mid /tmp/hymn-001-calypso-3-4.mid --style=calypso
```

Options include `--style=reggae|calypso|gospel|classic` and `--transpose=N`
(-6 through +6). Piano-only mode is for generated reggae. Existing output
files are refused, including the source file. No gain normalization is applied.
When comparing recordings, keep the file, bank, rate and mix identical. Check
each expected chord tone, not just overall loudness: one remaining note can
make an incomplete chord look healthy on a level meter.

## Verify, build and install safely

```sh
./scripts/verify.sh
./scripts/test_ios_midi.sh
./scripts/build_ios.sh
```

The native script runs deterministic method-channel/lifecycle tests in the
**iPhone 16 Pro simulator**, not on the physical phone. Pass another installed
simulator name as its first argument. It also checks the bank bundled in the
built app and its license notice. These are lifecycle/resource tests, not
acoustic recordings. Python tests cover bank equivalence; Dart tests cover
all original MIDI assets, exact renders, solo exports, cache safety, existing
arrangements, meter handling and transposition.

When an iPhone update is wanted:

```sh
./scripts/install_ios.sh
```

The installer defaults to the configured iPhone, or accepts a device ID as its
first argument / `DEVICE_ID`. It builds a release, selects the configuration-
specific `Release-iphoneos/Runner.app`, and checks version, bundle ID, debug
markers, soundbank and signature before updating in place. The generic
`build/ios/iphoneos` path can hold a stale debug/test build. Never uninstall to
solve a test-runner connection problem: that erases favorites and settings.

Bank checks are read-only and run before scripted builds. To regenerate a
candidate, give `prepare_ios_soundfont.py` a new, nonexistent output path;
compare it to the committed derivative before changing the bundled resource.

## Port verification — August 27, 2026

- 233 Flutter/Dart tests passed, including byte-identical Classic playback of
  all 695 bundled MIDI assets and unchanged existing meter/arrangement tests.
- 10 SoundFont tests passed; the generated bank matches the verified derivative.
- 7 native lifecycle/resource tests passed on the iOS 18.2 simulator.
- Signed iOS release 4.1.0 (40100) built successfully. Its bundle ID, compatible
  bank, license, signature and absence of debug artifacts were verified.
- The original bank and MIDI assets have no Git changes. No physical iPhone
  installation, uninstall, or user-data reset was performed for this port.


## Optional ensemble instruments and choir practice

Settings → Musicians & Choir contains two independent switches, off by default.
“Customize ensemble instruments” opens a Settings-only editor for the selected
style's melodic roles (percussion stays unchanged). Choices persist separately
for each style. “Style default” clears a role override. The preview plays New
Hymnal 1 through the same engine as hymn playback, replacing existing audio;
it stops when the editor closes. Preview always uses the ensemble, even when
choir practice is enabled.

“Choir practice” adds a part-mixer button to the hymn player. Practice renders
the original MIDI, bypassing ensemble styles and ensemble instrument choices, while retaining
transpose, speed, and seek. The source's sounding track names are used, with common SATB spellings normalized;
unnamed tracks use their track number. Names can be edited and persist per hymn.
There is no automatic assignment of soprano/alto/tenor/bass to ambiguous tracks.
Files with fewer than two sounding tracks report that separate parts are
unavailable. Multiple voices combined within one track cannot be separated.

Mute silences a track; Solo plays only the selected tracks (multiple solos are
allowed, and mute wins). Reset restores all tracks. Mix selections reset on hymn
changes. Disabling practice restores the saved ensemble style. Re-rendering keeps
the playback position and pause state; engine reloads are serialized to prevent
rapid mix changes from loading out of order. Render cache keys include the
practice flag, muted track indices, and per-channel program overrides. Muting
replaces note events with empty sequencer metadata at identical deltas, retaining
conductor events, rests, and unmuted tracks byte-for-byte.


### Instruments in the choir mixer

Every source-track card now has an Instrument selector alongside Mute and Solo.
Choose, for example, Grand piano for Tenor and Cello for Bass. These choices are
saved by hymnal edition, hymn number, and source track index, and apply to actual
choir playback, including Play parts and the main hymn player. They do not require
the separate full-ensemble customization switch. Original instrument clears that
track's override; Reset mix clears the choir track's mute, solo, and volume choices. Switching off choir
practice restores full-ensemble playback and retains the saved track choices.

Before saving an override, the player validates that the MIDI has a melodic
channel for that track and enough free channels to isolate shared-channel tracks.
Selected programs use the GM base bank. Shared control events are copied at their
original times to isolated channels; note timing, speed, key changes, and the
other tracks' instruments are preserved. Cache keys include the saved track
programs, so a previous render cannot hide an instrument change.

## Volume and solo in ensemble customization

The full-ensemble instrument editor also exposes a compact level slider and a
Solo chip for each style role. Levels are 0–100 percent and are applied to the
role's note velocities during regular style playback; Solo temporarily silences
the other melodic roles so a listener can check one arrangement part. These
settings persist per musical style and are independent of the choir-practice
track mix. Choir practice continues to use its own per-track instrument and
volume controls and overrides the selected style.

## Instrument categories and steelpan rolls

Both instrument selectors open a category sheet, then the instruments in that
family. The 111 base-bank musical presets use 11 common categories; Steelpan is
in Percussion. The chooser stays outside the track card, preserving its compact
height. Original instrument and Style default clear the corresponding override.

After instrument assignment and mixing, steelpan (GM program 114, zero-based)
notes lasting at least 240 ms receive 6 strikes per second, with slight
velocity variation. Tempo changes determine spacing. Short notes and all other
instruments retain their existing articulation. Rolls stop within the written
note duration, preserving hymn timing and rests. Ambiguous overlapping unisons
on a shared MIDI channel and notes crossing program changes are left unchanged
to avoid cutting off another voice. Render cache version 27 refreshes old audio.

### Jamaican Gospel

`jamaican_gospel` ports Caribbean Choruses' Jamaican church gospel backing:
swung organ chords at 7/12 of each beat, quarter-note finger bass, kick-led
drums, backbeat claps, offbeat tambourine, and an eight-bar tom fill. It keeps
the hymnal melody and descants on Rhodes, the written meter, and a steady
tempo 15% faster than the hymn's dominant tempo. The original organ groove
plays one chord per swung offbeat; every part speeds up together on the shared
MIDI clock, preserving pitch, meter and rhythmic relationships. The player's
1× setting uses this faster default, and the chord display follows the same
clock. Cache version 30 refreshes previous renders.
The source organ/bass/kit CC7 levels are 84/104/127. Playback,
MIDI export, transposition, and instrument controls share the same renderer;
choir practice continues to use the original parts.

The displayed name **Jamaican Gospel** is descriptive, not a claim of an
official genre designation. It distinguishes this church-chorus arrangement
from Modern Gospel without implying the specific Jamaican Revivalist tradition.

### Musical style and practice controls

The song menu opens the same scrollable musical-style picker as Settings and
can toggle Choir practice. Choir practice uses original parts and temporarily
overrides the chosen style. Settings places Musicians & Choir after Sound.
The musical-style instrument editor previews Amazing Grace (New Hymnal 108).
All four generated styles include a Drum kit volume and solo control; percussion
participates in volume/mute operations but is never transposed or remapped to a
melodic instrument. Cache version 31 refreshes previous ensemble mixes.

### Jazz accompaniment

Jazz plans conservative melodic variations over multi-bar phrases, following
opening contour and returning to the written closing phrase. It keeps all written attacks and adds at most two spacious answer notes in
long holds or roomy gaps, separated by at least four bars. Each new note lasts
at least a beat and 400 ms; the original note keeps at least one full beat. Answers
use the same melody channel, instrument, and velocity and follow its 50% mix. New pitches must fit every detected chord throughout the note; short
phrases or uncertain harmony retain the original tune. This is a rule-based
interpretation, not a trained improvisation model.

Piano comping, acoustic walking bass, and swung ride cymbal provide the backing.
Melody defaults to 50% in the ensemble mixer. Instrument, volume and solo choices
remain available; Choir Practice uses the original tracks. Render cache v34 refreshes previously played hymns for the added answers.

### List autoplay

Settings > Sound > Autoplay video and music is off by default. Enabling it
does not start playback: press Play or Play hymn video first. A natural ending
opens and plays the next supported hymn using the same medium, in the current
list's order, wrapping at its end. Main favorites, named favorites and official
categories retain their list, including mixed editions. Missing videos are
skipped within the list. Pause, close, leaving the reader, or disabling autoplay
prevents further automatic advancement. Media loading and YouTube buffering may
add a short gap; there is no deliberate inter-song delay.

### Compound time

6/8, 9/8, and 12/8 accompaniment uses an eighth-note harmony grid with dotted-quarter pulses, preserving the source MIDI division and time signature. Each style groups its backing rhythm in threes; melody notes retain their original timing. The generated MIDI cache version is advanced so previously mistimed arrangements are rebuilt.
