import 'package:flutter/services.dart';

/// Native locale-aware order. Returns source indices, preserving book identities.
class TitleCollation {
  static const _channel = MethodChannel('sdahymnal/collation');

  static Future<List<int>> order(List<String> titles, String language) async {
    if (language.trim().isEmpty) {
      throw ArgumentError.value(language, 'language');
    }
    if (titles.isEmpty) return const [];
    final result = await _channel.invokeListMethod<int>(
        'sort', {'titles': titles, 'language': language});
    if (result == null ||
        result.length != titles.length ||
        result.toSet().length != titles.length ||
        result.any((i) => i < 0 || i >= titles.length)) {
      throw const FormatException('Invalid title collation permutation');
    }
    return List.unmodifiable(result);
  }
}
