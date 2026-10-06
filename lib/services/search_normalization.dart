import 'package:unorm_dart/unorm_dart.dart' as unicode;

// These Latin letters do not decompose into an ASCII base with NFD.
const _latinAlternatives = {
  'æ': 'ae',
  'œ': 'oe',
  'ø': 'o',
  'ł': 'l',
  'đ': 'd',
  'ð': 'd',
  'þ': 'th',
  'ß': 'ss',
  'ı': 'i',
};
final _latinAlternativePattern = RegExp('[æœøłđðþßı]');
// Invisible formatting in pasted titles must not split a searchable word.
final _wordFormatting = RegExp('[\u00ad\u200b\u2060\ufeff]');

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
  var normalized = text.toLowerCase().replaceAll(_wordFormatting, '');
  if (_nonAscii.hasMatch(normalized)) {
    if (foldLatinAccents) {
      normalized = unicode
          .nfd(normalized)
          .replaceAllMapped(_latinAccents, (match) => match.group(1)!)
          .replaceAllMapped(_latinAlternativePattern,
              (match) => _latinAlternatives[match.group(0)]!);
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
