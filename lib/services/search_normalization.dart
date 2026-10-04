import 'package:unorm_dart/unorm_dart.dart' as unicode;

final _nonAscii = RegExp(r'[^\x00-\x7f]');
final _latinAccents = RegExp(r'([a-zA-Z])\p{M}+', unicode: true);
final _punctuation = RegExp(r'[^\p{L}\p{N}\p{M}\s]', unicode: true);
final _spaces = RegExp(r'\s+');
final _apostrophes = RegExp("['’‘ʼ`\\\\]");

/// Search-only normalization; never changes source lyrics or their display.
/// Fold marks on Latin letters, preserving meaningful marks on other scripts
/// (for example Russian й and ё). Canonically equivalent text matches in either
/// input form. ASCII takes a fast path for the existing English catalog.
String normalizeHymnSearch(String text, {bool foldLatinAccents = true}) {
  var normalized = text.toLowerCase();
  if (_nonAscii.hasMatch(normalized)) {
    if (foldLatinAccents) {
      normalized = unicode
          .nfd(normalized)
          .replaceAllMapped(_latinAccents, (match) => match.group(1)!);
    }
    normalized = unicode.nfc(normalized);
  }
  return normalized
      .replaceAll(_apostrophes, '')
      .replaceAll(_punctuation, ' ')
      .replaceAll(_spaces, ' ')
      .trim();
}

Set<String> refrainLabelsFor(String languageTag) =>
    switch (languageTag.toLowerCase().split('-').first) {
      'es' => const {'coro', 'estribillo', 'coro final'},
      'pt' => const {'coro', 'refrao'},
      'ru' => const {'припев'},
      'fr' => const {'refrain'},
      _ => const {'chorus', 'refrain'},
    };
