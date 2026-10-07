import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/audit_spanish_midi.dart' as audit;

void main() {
  test('candidate audit separates HTML and missing files from MIDI renders',
      () {
    final dir = Directory.systemTemp.createTempSync('spanish-midi-audit-');
    try {
      File('assets/midi/es-2009-303.mid').copySync('${dir.path}/E001.mid');
      File('${dir.path}/E002.mid').writeAsStringSync('<html>challenge</html>');
      final report = File('${dir.path}/report.json');
      audit.main([dir.path, report.path]);
      final data = jsonDecode(report.readAsStringSync()) as Map;
      expect(data['counts'], {
        'structurallyPlayable': 1,
        'invalidDownload': 1,
        'notDownloaded': 525
      });
      final first = (data['items'] as List).first as Map;
      expect(first['renders'].length, 12);
      expect(first['durationMs'], 116418);
      expect(first['parts'], isNotEmpty);
      expect(data['scope'], contains('require review before runtime use'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });
}
