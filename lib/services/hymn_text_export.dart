import 'package:html/parser.dart' show parseFragment;
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/search_normalization.dart';

class HymnTextSection {
  final String label;
  final String text;
  const HymnTextSection(this.label, this.text);
}

/// Export source order, without the reader's automatically repeated choruses.
class HymnTextExport {
  final Hymn hymn;
  late final String lyrics = _plainText(hymn.body);
  late final List<HymnTextSection> sections = _sections();
  HymnTextExport(this.hymn);

  String text({int? section}) =>
      '${hymn.number} · ${hymn.title}\n${hymn.bookLabel}\n\n'
      '${section == null ? lyrics : sections[section].text}';

  List<HymnTextSection> _sections() {
    final result = <HymnTextSection>[];
    final buffer = <String>[];
    String? label;
    void flush() {
      final text = buffer.join('\n').trim();
      if (text.isNotEmpty) {
        result.add(
            HymnTextSection(label ?? 'Section ${result.length + 1}', text));
      }
      buffer.clear();
      label = null;
    }

    final refrains = refrainLabelsFor(hymn.languageTag);
    for (final line in lyrics.split('\n')) {
      final normalized = normalizeHymnSearch(line);
      final numbered = RegExp(r'^\d+[.)]?$').hasMatch(line);
      final refrain = refrains.contains(normalized);
      if (numbered || refrain) {
        flush();
        label = numbered ? 'Verse $line' : line;
      } else if (line.isEmpty && buffer.isNotEmpty) {
        // A standalone label remains attached to its following lyric block.
        if (buffer.length > 1 || label == null) flush();
        continue;
      }
      buffer.add(line);
    }
    flush();
    return result;
  }

  static String _plainText(String body) {
    // HTML breaks already carry line structure in English source files; the
    // adjacent source newlines are indentation, not additional blank lines.
    final source = body.replaceAll(r'\n', '\n').replaceAllMapped(
        RegExp(r'<br\s*/?>\s*', caseSensitive: false), (_) => '\n');
    final html = source.replaceAll(
        RegExp(r'</?p\b[^>]*>', caseSensitive: false), '\n\n');
    final fragment = parseFragment(html);
    for (final node in fragment.querySelectorAll('script, style')) {
      node.remove();
    }
    return (fragment.text ?? '')
        .replaceAll('\u00a0', ' ')
        .split('\n')
        .map((line) => line.trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
