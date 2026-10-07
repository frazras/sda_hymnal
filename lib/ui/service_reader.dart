import 'package:flutter/material.dart';
import '../models/hymn_ref.dart';
import '../models/service_playlist.dart';
import '../services/hymnal_repository.dart';
import '../services/midi_player.dart';
import 'additional_readings.dart';
import 'hymnPage.dart';
import 'reader_sequence.dart';

/// A fixed snapshot: edits in the list never silently move an active reader.
class ServiceReader {
  final ServicePlaylist playlist;
  final HymnalRepository repository;

  const ServiceReader({required this.playlist, required this.repository});

  Widget? page(int index,
      {bool previewOnly = false,
      HymnContinuation? continuation,
      bool showSheetMusic = false}) {
    if (index < 0 || index >= playlist.entries.length) return null;
    final entry = playlist.entries[index];
    final hymn = repository.hymn(entry.ref);
    final reading = repository.reading(entry.ref);
    if (continuation != null) {
      if (entry.ref.kind != HymnalItemKind.hymn || hymn == null) return null;
      if (continuation == HymnContinuation.midi && !MidiPlayer.hasMusic(hymn)) {
        return null;
      }
      if (continuation == HymnContinuation.video && hymn.video == null) {
        return null;
      }
    }
    final sequence = ReaderSequence(
      label:
          'Service: ${playlist.name} · ${index + 1} of ${playlist.entries.length}',
      canMove: (direction) => playlist.adjacent(entry.id, direction) != null,
      page: (direction,
          {previewOnly = false, continuation, showSheetMusic = false}) {
        if (playlist.adjacent(entry.id, direction) == null) return null;
        return page(index + direction,
            previewOnly: previewOnly,
            continuation: continuation,
            showSheetMusic: showSheetMusic);
      },
    );
    if (hymn != null) {
      return HymnPage(
          key: ValueKey('service-${entry.id}'),
          hymn: hymn,
          hymns: const [],
          sequence: sequence,
          previewOnly: previewOnly,
          continuation: continuation,
          showSheetMusic: showSheetMusic,
          analyticsSource: 'service');
    }
    if (reading != null) {
      return AdditionalReadingPage(
          key: ValueKey('service-${entry.id}'),
          reading: reading,
          sequence: sequence,
          previewOnly: previewOnly);
    }
    return _UnavailableEntry(entry: entry, sequence: sequence);
  }
}

class _UnavailableEntry extends StatelessWidget {
  final ServiceEntry entry;
  final ReaderSequence sequence;
  const _UnavailableEntry({required this.entry, required this.sequence});

  void _move(BuildContext context, int direction) {
    final target = sequence.page(direction);
    if (target != null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute<void>(builder: (_) => target));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Unavailable item')),
        body: Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sequence.label),
              const SizedBox(height: 24),
              const Text(
                  'This item is not installed. It remains in your service.'),
              const SizedBox(height: 12),
              Text('${entry.ref.bookId} · ${entry.ref.itemId}'),
            ])),
        bottomNavigationBar: SafeArea(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              TextButton.icon(
                  onPressed:
                      sequence.canMove(-1) ? () => _move(context, -1) : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous')),
              TextButton.icon(
                  onPressed:
                      sequence.canMove(1) ? () => _move(context, 1) : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next')),
            ])),
      );
}
