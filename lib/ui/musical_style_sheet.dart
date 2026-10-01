import 'package:flutter/material.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'common.dart';

/// Instrument picker sheet (same pattern as the hymn page's speed sheet):
/// one row per theme, tap applies and closes.
void showMusicalStyleSheet(BuildContext context) {
  final t = context.tokens;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        decoration: BoxDecoration(
          color: t.isDark ? const Color(0xFF171E1A) : t.surface,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('MUSICAL STYLE'),
            const SizedBox(height: 6),
            Flexible(
              child: Scrollbar(
                child: SingleChildScrollView(
                  key: const ValueKey('musical-style-list'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, theme) in InstrumentTheme.themes.indexed)
                        _instrumentRow(
                          t,
                          theme,
                          sheetContext,
                          divider: i < InstrumentTheme.themes.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _instrumentRow(
  HymnalTokens t,
  (String, String, int?) theme,
  BuildContext sheetContext, {
  required bool divider,
}) {
  final selected = InstrumentTheme.instance.value == theme.$1;
  return Pressable(
    onTap: () {
      InstrumentTheme.instance.set(theme.$1);
      Navigator.pop(sheetContext);
    },
    pressedScale: 1.0,
    builder: (context, pressed) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
      decoration: BoxDecoration(
        color: pressed ? t.surface2 : Colors.transparent,
        border: divider ? Border(bottom: BorderSide(color: t.line2)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              theme.$2,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: selected ? t.accent : t.ink,
              ),
            ),
          ),
          if (selected)
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: t.accent, shape: BoxShape.circle),
            ),
        ],
      ),
    ),
  );
}
