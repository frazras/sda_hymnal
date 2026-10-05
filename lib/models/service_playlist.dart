import 'hymn_ref.dart';

/// Each occurrence has its own identity: an opening hymn may also close a service.
class ServiceEntry {
  final String id;
  final HymnRef ref;

  ServiceEntry({required this.id, required this.ref}) {
    if (id.trim().isEmpty) throw const FormatException('Missing entry ID.');
  }

  factory ServiceEntry.fromJson(Map<String, dynamic> data) {
    if (data['id'] is! String || data['ref'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid service entry.');
    }
    return ServiceEntry(
        id: data['id'] as String,
        ref: HymnRef.fromJson(data['ref'] as Map<String, dynamic>));
  }

  Map<String, dynamic> toJson() => {'id': id, 'ref': ref.toJson()};
}

class ServicePlaylist {
  final String id;
  final String name;
  final List<ServiceEntry> entries;

  ServicePlaylist(
      {required this.id,
      required String name,
      Iterable<ServiceEntry> entries = const []})
      : name = name.trim(),
        entries = List.unmodifiable(entries) {
    if (id.trim().isEmpty || this.name.isEmpty || this.name.length > 60) {
      throw const FormatException(
          'Use a service name between 1 and 60 characters.');
    }
    if (this.entries.map((e) => e.id).toSet().length != this.entries.length) {
      throw const FormatException('Duplicate service entry ID.');
    }
  }

  factory ServicePlaylist.fromJson(Map<String, dynamic> data) {
    if (data['id'] is! String ||
        data['name'] is! String ||
        data['entries'] is! List) {
      throw const FormatException('Invalid service playlist.');
    }
    return ServicePlaylist(
        id: data['id'] as String,
        name: data['name'] as String,
        entries: (data['entries'] as List).map((e) {
          if (e is! Map<String, dynamic>) {
            throw const FormatException('Invalid entry.');
          }
          return ServiceEntry.fromJson(e);
        }));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  ServicePlaylist renamed(String name) =>
      ServicePlaylist(id: id, name: name, entries: entries);

  ServicePlaylist appended(ServiceEntry entry) =>
      ServicePlaylist(id: id, name: name, entries: [...entries, entry]);

  ServicePlaylist without(String entryId) => ServicePlaylist(
      id: id, name: name, entries: entries.where((e) => e.id != entryId));

  /// [to] is the final index, matching Flutter's onReorderItem contract.
  ServicePlaylist reordered(int from, int to) {
    RangeError.checkValidIndex(from, entries);
    RangeError.checkValidIndex(to, entries);
    final result = List<ServiceEntry>.of(entries);
    result.insert(to, result.removeAt(from));
    return ServicePlaylist(id: id, name: name, entries: result);
  }

  /// Service order never wraps or searches ahead past a reading/unavailable item.
  /// The reader decides whether this exact next entry supports automatic playback.
  ServiceEntry? adjacent(String occurrenceId, int direction) {
    if (direction != -1 && direction != 1) {
      throw ArgumentError.value(direction, 'direction', 'Use -1 or 1.');
    }
    final index = entries.indexWhere((e) => e.id == occurrenceId);
    final target = index + direction;
    return index < 0 || target < 0 || target >= entries.length
        ? null
        : entries[target];
  }
}
