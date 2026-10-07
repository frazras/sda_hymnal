import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sdahymnal/services/midi_file.dart';
import 'package:sdahymnal/services/midi_render.dart';
import 'package:sdahymnal/services/midi_transform.dart';

/// Audits downloaded Spanish Old candidates without enabling playback mappings.
/// A successful render is structural evidence, not musical/form certification.
void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
        'Usage: dart tool/audit_spanish_midi.dart INPUT_DIR REPORT.json');
    exitCode = 64;
    return;
  }
  final items = <Map<String, Object?>>[];
  for (var n = 1; n <= 527; n++) {
    final name = 'E${n.toString().padLeft(3, '0')}.mid';
    final file = File('${args[0]}/$name');
    final item = <String, Object?>{
      'itemId': '$n',
      'sourceUrl': 'https://4eange.org/espagnol/CAN/ESP/MID/$name'
    };
    if (!file.existsSync()) {
      item['status'] = 'notDownloaded';
    } else {
      final bytes = file.readAsBytesSync();
      item['bytes'] = bytes.length;
      item['sha256'] = sha256.convert(bytes).toString();
      try {
        midiTrackChunks(bytes);
        final original = readMidiDuration(bytes);
        if (original <= Duration.zero) {
          throw const FormatException('No positive duration');
        }
        item['durationMs'] = original.inMilliseconds;
        item['key'] = readKeySignature(bytes)?.label;
        item['parts'] = [
          for (final p in midiParts(bytes)) {'index': p.index, 'name': p.name}
        ];
        final renders = <String, Object?>{};
        for (final style in ['classic', ...arrangedMidiThemes.keys]) {
          for (final apple in [false, true]) {
            final key = '$style/${apple ? 'ios' : 'portable'}';
            try {
              final rendered =
                  renderHymnMidi(bytes, theme: style, forAppleSynth: apple);
              midiTrackChunks(rendered);
              final duration = readMidiDuration(rendered);
              if (duration <= Duration.zero) {
                throw const FormatException('No positive rendered duration');
              }
              renders[key] = {
                'durationMs': duration.inMilliseconds,
                'bytes': rendered.length
              };
            } catch (error) {
              renders[key] = {'error': '$error'};
            }
          }
        }
        item['renders'] = renders;
        item['status'] =
            renders.values.any((v) => (v as Map).containsKey('error'))
                ? 'renderFailure'
                : 'structurallyPlayable';
      } catch (error) {
        item['status'] = 'invalidDownload';
        item['error'] = '$error';
      }
    }
    items.add(item);
  }
  final counts = <String, int>{};
  for (final item in items) {
    final status = item['status'] as String;
    counts[status] = (counts[status] ?? 0) + 1;
  }
  final report = {
    'schemaVersion': 1,
    'bookId': 'sda-es-1962',
    'scope':
        'Staged candidates only; melody, meter and complete verse form require review before runtime use.',
    'counts': counts,
    'items': items
  };
  final destination = File(args[1]);
  destination.parent.createSync(recursive: true);
  destination.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n');
  stdout.writeln(jsonEncode(counts));
}
