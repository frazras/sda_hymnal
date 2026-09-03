import 'dart:typed_data';

import 'midi_transform.dart';
import 'style_arranger.dart';

/// Arrangement and plain-instrument fallback used by both playback and export.
const arrangedMidiThemes = <String, (ArrangeStyle, int)>{
  'gospel': (ArrangeStyle.gospel, 4),
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
}) {
  final arrangement = arrangedMidiThemes[theme];
  if (arrangement == null) {
    return transformMidi(source,
        semitones: semitones, forceProgram: forceProgram);
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
  return semitones == 0
      ? arranged
      : transformMidi(arranged, semitones: semitones);
}
