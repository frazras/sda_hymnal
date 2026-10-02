/// Permanent book identities. Aliases exist only for the English UI/media
/// adapters; an unrecognized book must never resolve to an English edition.
String canonicalBookId(String id) => switch (id) {
      'new' => 'sda-en-1985',
      'old' => 'sda-en-1941',
      _ => id,
    };

String legacyBookAlias(String id) => switch (id) {
      'sda-en-1985' => 'new',
      'sda-en-1941' => 'old',
      _ => id,
    };

enum HymnalItemKind { hymn, reading }

/// Identity is independent of title, list position, language, and media.
class HymnRef {
  final String bookId;
  final String itemId;
  final HymnalItemKind kind;

  HymnRef({
    required String bookId,
    required this.itemId,
    this.kind = HymnalItemKind.hymn,
  }) : bookId = canonicalBookId(bookId) {
    if (this.bookId.trim().isEmpty || itemId.trim().isEmpty) {
      throw const FormatException('A saved item needs a book and item ID.');
    }
  }

  factory HymnRef.fromJson(Map<String, dynamic> data) {
    final book = data['bookId'];
    final item = data['itemId'];
    final kind = data['kind'];
    if (book is! String ||
        item is! String ||
        !HymnalItemKind.values.any((value) => value.name == kind)) {
      throw const FormatException('Invalid saved hymn reference.');
    }
    return HymnRef(
        bookId: book,
        itemId: item,
        kind: HymnalItemKind.values.byName(kind as String));
  }

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'itemId': itemId,
        'kind': kind.name,
      };

  @override
  bool operator ==(Object other) =>
      other is HymnRef &&
      other.bookId == bookId &&
      other.itemId == itemId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(bookId, itemId, kind);
}
