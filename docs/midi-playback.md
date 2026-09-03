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
