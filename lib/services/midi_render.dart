import 'dart:typed_data';

import 'midi_transform.dart';
import 'style_arranger.dart';

/// Arrangement and plain-instrument fallback used by both playback and export.
const arrangedMidiThemes = <String, (ArrangeStyle, int)>{
  'jazz': (ArrangeStyle.jazz, 0),
  'gospel': (ArrangeStyle.gospel, 4),
  'jamaican_gospel': (ArrangeStyle.jamaicanGospel, 16),
  'reggae': (ArrangeStyle.reggae, 16),
  'calypso': (ArrangeStyle.calypso, 114),
};

/// The app's render pipeline, independent of Flutter, storage and playback.
/// The iOS mix must be paired with the bundled range-scoped piano soundbank.
/// Portable exports and Android keep the original arrangement mix.
Uint8List renderHymnMidi(
  Uint8List source, {
  String theme = 'classic',
  int semitones = 0,
  int? forceProgram,
  bool forAppleSynth = false,
  Map<int, int> channelPrograms = const {},
  Set<int> mutedTracks = const {},
  bool choirPractice = false,
  Map<int, int> trackPrograms = const {},
  Map<int, int> trackVolumes = const {},
  Map<int, int> channelVolumes = const {},
  Set<int> mutedChannels = const {},
}) {
  if (choirPractice) {
    return steelpanRolls(transformMidi(
        mixMidiParts(
            volumeMidiParts(
                instrumentMidiParts(source, trackPrograms), trackVolumes),
            mutedTracks),
        semitones: semitones));
  }
  final arrangement = arrangedMidiThemes[theme];
  if (arrangement == null) {
    return steelpanRolls(transformMidi(source,
        semitones: semitones,
        forceProgram: channelPrograms[0] ?? forceProgram,
        channelVolumes: channelVolumes,
        mutedChannels: mutedChannels));
  }
  final (style, fallback) = arrangement;
  Uint8List arranged;
  try {
    arranged = arrangeStyle(source, style,
        channelVolumes: forAppleSynth && style == ArrangeStyle.reggae
            ? reggaeVolumesForAppleSynth
            : const {});
  } on FormatException {
    arranged = transformMidi(source, forceProgram: fallback);
  }
  return steelpanRolls(transformMidi(arranged,
      semitones: semitones,
      channelPrograms: channelPrograms,
      channelVolumes: {if (theme == 'jazz') 0: 50, ...channelVolumes},
      mutedChannels: mutedChannels));
}
