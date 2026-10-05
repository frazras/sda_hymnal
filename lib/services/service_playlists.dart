import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/service_playlist.dart';

/// Separate from favorites: no conversion or deduplication of the user's lists.
/// Publish only after a verified write; serialize operations against latest data.
class ServicePlaylists extends ChangeNotifier {
  static const storageKey = 'servicePlaylists.v1';
  static final instance = ServicePlaylists();
  List<ServicePlaylist> _playlists = const [];
  List<ServicePlaylist> get playlists => _playlists;
  bool _loaded = false;
  bool _storageError = false;
  bool get storageError => _storageError;
  Future<void> _pending = Future.value();

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  List<ServicePlaylist> _decode(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic> ||
        data['schemaVersion'] != 1 ||
        data['playlists'] is! List) {
      throw const FormatException('Unsupported service playlist data.');
    }
    final lists = (data['playlists'] as List).map((e) {
      if (e is! Map<String, dynamic>) {
        throw const FormatException('Invalid playlist.');
      }
      return ServicePlaylist.fromJson(e);
    }).toList();
    _validate(lists);
    return List.unmodifiable(lists);
  }

  void _validate(List<ServicePlaylist> lists) {
    if (lists.map((e) => e.id).toSet().length != lists.length) {
      throw const FormatException('Duplicate service playlist ID.');
    }
  }

  Future<void> load() => _serialize(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(storageKey);
          _playlists = raw == null ? const [] : _decode(raw);
          _loaded = true;
          _storageError = false;
        } catch (_) {
          _storageError = true;
        }
        notifyListeners();
      });

  Future<void> _change(
          List<ServicePlaylist> Function(List<ServicePlaylist>) edit) =>
      _serialize(() async {
        if (!_loaded || _storageError) {
          throw StateError(
              'Service playlists must load successfully before editing.');
        }
        final changed = edit(_playlists);
        _validate(changed);
        final raw = jsonEncode({
          'schemaVersion': 1,
          'playlists': changed.map((e) => e.toJson()).toList()
        });
        try {
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString(storageKey, raw)) {
            throw StateError('Save failed.');
          }
          await prefs.reload();
          if (prefs.getString(storageKey) != raw) {
            throw StateError('Save verification failed.');
          }
          _playlists = List.unmodifiable(changed);
        } catch (_) {
          _storageError = true;
          notifyListeners();
          rethrow;
        }
        notifyListeners();
      });

  Future<void> create(ServicePlaylist playlist) =>
      _change((lists) => [...lists, playlist]);

  Future<void> update(
          String id, ServicePlaylist Function(ServicePlaylist) edit) =>
      _change((lists) {
        final index = lists.indexWhere((e) => e.id == id);
        if (index < 0) throw ArgumentError('Service playlist does not exist.');
        final replacement = edit(lists[index]);
        if (replacement.id != id) {
          throw ArgumentError('Cannot change playlist identity.');
        }
        return [...lists.take(index), replacement, ...lists.skip(index + 1)];
      });

  Future<void> delete(String id) =>
      _change((lists) => lists.where((e) => e.id != id).toList());
}
