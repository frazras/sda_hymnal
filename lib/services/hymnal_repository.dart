import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_ref.dart';
import 'package:sdahymnal/models/additional_reading.dart';

class HymnalEdition {
  final String id;
  final String languageTag;
  final String displayName;
  final int? year;

  const HymnalEdition(
      {required this.id,
      required this.languageTag,
      required this.displayName,
      required this.year});

  static const englishNew = HymnalEdition(
      id: 'sda-en-1985',
      languageTag: 'en',
      displayName: 'New Hymnal',
      year: 1985);
  static const englishOld = HymnalEdition(
      id: 'sda-en-1941',
      languageTag: 'en',
      displayName: 'Old Hymnal',
      year: 1941);
}

/// Installed content, indexed by edition and item identity. The current English
/// adapter retains the original Hymn instances, markup, metadata and media.
class HymnalRepository {
  final Map<String, HymnalEdition> _editions = {};
  final Map<String, List<Hymn>> _hymns = {};
  final Map<HymnRef, Hymn> _byRef = {};
  final Map<HymnRef, AdditionalReading> _readings = {};

  HymnalRepository(
      {required Iterable<HymnalEdition> editions,
      required Iterable<Hymn> hymns,
      Iterable<AdditionalReading> readings = const []}) {
    for (final edition in editions) {
      if (edition.id != canonicalBookId(edition.id) ||
          edition.id.isEmpty ||
          _editions.containsKey(edition.id)) {
        throw const FormatException('Duplicate or noncanonical book ID.');
      }
      _editions[edition.id] = edition;
      _hymns[edition.id] = [];
    }
    for (final hymn in hymns) {
      final ref = hymn.ref;
      if (!_editions.containsKey(ref.bookId) || _byRef.containsKey(ref)) {
        throw const FormatException('Unknown book or duplicate hymn ID.');
      }
      _byRef[ref] = hymn;
      _hymns[ref.bookId]!.add(hymn);
    }
    for (final entry in _hymns.entries.toList()) {
      entry.value.sort((a, b) => a.number.compareTo(b.number));
      _hymns[entry.key] = List.unmodifiable(entry.value);
    }
    for (final reading in readings) {
      final ref = reading.ref;
      if (!_editions.containsKey(ref.bookId) || _readings.containsKey(ref)) {
        throw const FormatException('Unknown book or duplicate reading ID.');
      }
      _readings[ref] = reading;
    }
  }

  factory HymnalRepository.english(Iterable<Hymn> hymns,
          {Iterable<AdditionalReading> readings = const []}) =>
      HymnalRepository(
          editions: const [HymnalEdition.englishNew, HymnalEdition.englishOld],
          hymns: hymns,
          readings: readings);

  List<HymnalEdition> get editions => List.unmodifiable(_editions.values);
  HymnalEdition? edition(String id) => _editions[canonicalBookId(id)];
  List<Hymn> hymnsFor(String id) => _hymns[canonicalBookId(id)] ?? const [];
  List<AdditionalReading> readingsFor(String id) => List.unmodifiable(
      _readings.values.where((r) => r.ref.bookId == canonicalBookId(id)));
  Hymn? hymn(HymnRef ref) => _byRef[ref];
  AdditionalReading? reading(HymnRef ref) => _readings[ref];
}
