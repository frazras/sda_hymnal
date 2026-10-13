import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/hymnal_book.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/kit.dart';

/// Picker result that opens hymnal downloads instead of choosing a book.
const morePicksId = '__more__';

/// Compact header control naming the selected hymnal ("EN", "ES"...).
/// One tap opens [showHymnalPicker]; it replaces the full-width dropdown.
class BookPill extends StatelessWidget {
  const BookPill({
    super.key,
    required this.book,
    required this.onTap,
    this.allLanguages = false,
  });

  final HymnalBook book;
  final bool allLanguages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = t.isClassic ? t.ink : t.accent;
    // A two-letter code needs no extra room at large text sizes; clamping
    // keeps the header from crowding the wordmark.
    return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Semantics(
          button: true,
          label:
              '${context.appText.chooseHymnal}: ${allLanguages ? context.appText.allLanguages : '${book.languageName}, ${book.title}'}',
          excludeSemantics: true,
          child: Pressable(
            key: const ValueKey('hymnal-selector'),
            onTap: onTap,
            pressedScale: 0.94,
            builder: (context, pressed) => Container(
              height: 32,
              padding: const EdgeInsets.only(left: 9, right: 6),
              decoration: BoxDecoration(
                color: t.isClassic
                    ? Colors.transparent
                    : (pressed ? t.tint : t.surface),
                border: Border.all(color: t.isClassic ? t.ink : t.line),
                borderRadius: BorderRadius.circular(t.isClassic ? 4 : 999),
                boxShadow: t.isClassic ? const [] : t.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language, size: 15, color: color),
                  const SizedBox(width: 5),
                  Text(
                    allLanguages
                        ? context.appText.all.toUpperCase()
                        : book.code,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: color,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 17, color: color),
                ],
              ),
            ),
          ),
        ));
  }
}

/// Lists every installed hymnal by native language name. Returns the chosen
/// book ID, 'all' (when [allowAll]) or [morePicksId] for downloads.
Future<String?> showHymnalPicker(
  BuildContext context, {
  required List<HymnalBook> books,
  required String selected,
  bool allowAll = false,
  bool offerMore = true,
}) {
  return showHymnalSheet<String>(
    context,
    title: context.appText.chooseHymnal,
    builder: (sheet) => Column(
      key: const ValueKey('hymnal-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allowAll)
          SheetOption(
            key: const ValueKey('hymnal-option-all'),
            leading: const _GlobeTile(),
            title: sheet.appText.allLanguages,
            subtitle: sheet.appText.searchEveryHymnal,
            selected: selected == 'all',
            onTap: () => Navigator.pop(sheet, 'all'),
          ),
        for (final book in books)
          SheetOption(
            key: ValueKey('hymnal-option-${book.id}'),
            leading: CodeTile(book.code, selected: book.id == selected),
            title: book.languageName,
            subtitle: book.title,
            selected: book.id == selected,
            onTap: () => Navigator.pop(sheet, book.id),
          ),
        if (offerMore)
          SheetOption(
            key: const ValueKey('hymnal-option-more'),
            divider: false,
            leading: SizedBox(
              width: 38,
              child: Icon(Icons.add_circle_outline,
                  size: 22, color: sheet.tokens.accent),
            ),
            title: sheet.appText.moreLanguages,
            subtitle: sheet.appText.moreLanguagesHelp,
            onTap: () => Navigator.pop(sheet, morePicksId),
          ),
      ],
    ),
  );
}

class _GlobeTile extends StatelessWidget {
  const _GlobeTile();
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 38,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.tint,
        borderRadius: BorderRadius.circular(t.isClassic ? 3 : 9),
      ),
      child: Icon(Icons.language, size: 17, color: t.accent),
    );
  }
}
