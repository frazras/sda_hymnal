import 'dart:io';

import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/midi_render.dart';

/// Export uses the same renderer as playback. Default: portable reggae.
/// --ios-mix selects the app's compatible-bank mix; --piano-only keeps the
/// conductor and actual skank track verbatim (even when a descant is present).
void main(List<String> args) {
  try {
    exportMidi(args);
  } catch (error) {
    stderr.writeln(error);
    stderr.writeln('Usage: dart run tool/export_midi.dart input.mid output.mid '
        '[--style=reggae|calypso|gospel|jamaican_gospel|jazz|classic] [--transpose=N] '
        '[--ios-mix] [--piano-only]');
    exitCode = 1;
  }
}

void exportMidi(List<String> args) {
  var theme = 'reggae';
  var semitones = 0;
  var apple = false;
  var pianoOnly = false;
  final paths = <String>[];
  for (final arg in args) {
    if (arg.startsWith('--style=')) {
      theme = arg.substring('--style='.length);
    } else if (arg.startsWith('--transpose=')) {
      semitones = int.parse(arg.substring('--transpose='.length));
    } else if (arg == '--ios-mix') {
      apple = true;
    } else if (arg == '--piano-only') {
      pianoOnly = true;
    } else if (arg.startsWith('--')) {
      throw ArgumentError('Unknown option: $arg');
    } else {
      paths.add(arg);
    }
  }
  if (paths.length != 2 ||
      !{'classic', ...arrangedMidiThemes.keys}.contains(theme) ||
      semitones < -6 ||
      semitones > 6 ||
      (pianoOnly && theme != 'reggae')) {
    throw ArgumentError('Invalid paths, style, transposition, or solo option');
  }
  final output = File(paths[1]);
  if (output.existsSync()) {
    throw FileSystemException(
        'Refusing to overwrite an existing file', output.path);
  }
  final source = File(paths[0]).readAsBytesSync();
  final full = renderHymnMidi(source,
      theme: theme, semitones: semitones, forAppleSynth: apple);
  final bytes = pianoOnly ? reggaePianoOnlyMidi(full) : full;
  midiTrackChunks(bytes);
  output.parent.createSync(recursive: true);
  output.createSync(exclusive: true);
  output.writeAsBytesSync(bytes, flush: true);
  stdout.writeln('${output.path}: ${bytes.length} bytes, $theme, '
      '${apple ? 'iOS compatible-bank mix' : 'portable mix'}'
      '${pianoOnly ? ', piano only' : ''}');
}
