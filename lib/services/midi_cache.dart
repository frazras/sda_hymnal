import 'dart:io';
import 'dart:typed_data';

import 'midi_file.dart';

/// Generated files only; source assets and user preferences are never changed.
class MidiRenderCache {
  MidiRenderCache(this.directory);

  // v22's Apple piano CC7=41 belongs to the original bank. Bypass it rather
  // than deleting old caches, which another running player may still use.
  static const renderVersion = 23;
  final Directory directory;
  final _pending = <String, Future<File>>{};

  static String filename(
      {required String hymnal,
      required int hymn,
      required int semitones,
      required String theme,
      required bool forAppleSynth,
      int? forceProgram}) {
    if (hymnal != 'new' && hymnal != 'old') {
      throw ArgumentError.value(hymnal, 'hymnal', 'Unsupported hymnal');
    }
    final engine = forAppleSynth ? 'apple-scoped' : 'portable';
    final program = forceProgram == null ? '' : '_p$forceProgram';
    final edition = hymnal == 'old' ? 'old_' : '';
    return '$edition${hymn.toString().padLeft(3, '0')}_t${semitones}_$theme'
        '${program}_${engine}_v$renderVersion.mid';
  }

  Future<File> getOrCreate(String name, Future<Uint8List> Function() render) {
    if (!RegExp(r'^[A-Za-z0-9_-]+\.mid$').hasMatch(name)) {
      return Future.error(
          ArgumentError.value(name, 'name', 'Invalid cache key'));
    }
    return _pending.putIfAbsent(name, () async {
      try {
        return await _materialize(name, render);
      } finally {
        _pending.remove(name);
      }
    });
  }

  Future<File> _materialize(
      String name, Future<Uint8List> Function() render) async {
    final destination = File('${directory.path}/$name');
    if (await destination.exists()) {
      try {
        midiTrackChunks(await destination.readAsBytes());
        return destination;
      } on FormatException {
        // Interrupted/invalid generated cache entry: replace atomically below.
      }
    }
    final bytes = await render();
    midiTrackChunks(bytes);
    await directory.create(recursive: true);
    final staging = await directory.createTemp('.$name.');
    try {
      final staged = File('${staging.path}/render.mid');
      await staged.writeAsBytes(bytes, flush: true);
      // Same filesystem: readers see a complete old or complete new file.
      await staged.rename(destination.path);
      return destination;
    } finally {
      await staging.delete(recursive: true);
    }
  }
}
