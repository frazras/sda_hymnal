import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/app_language.dart';
import '../theme.dart';
import 'kit.dart';

const interfaceLanguageNames = {
  'en': 'English',
  'es': 'Español',
  'pt': 'Português',
  'ru': 'Русский',
};

Future<void> showAppLanguagePicker(BuildContext context) async {
  final current = AppLanguage.instance.value.languageCode;
  final selected = await showHymnalSheet<String>(
    context,
    title: context.appText.interfaceLanguage,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(sheet.appText.interfaceLanguageHelp,
              style: TextStyle(
                  fontFamily: kSans, fontSize: 13, color: sheet.tokens.muted)),
        ),
        for (final (i, entry) in interfaceLanguageNames.entries.indexed)
          SheetOption(
            key: ValueKey('interface-language-${entry.key}'),
            leading: CodeTile(entry.key.toUpperCase(),
                selected: current == entry.key),
            title: entry.value,
            selected: current == entry.key,
            divider: i < interfaceLanguageNames.length - 1,
            onTap: () => Navigator.pop(sheet, entry.key),
          ),
      ],
    ),
  );
  if (selected == null) return;
  try {
    await AppLanguage.instance.set(selected);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.appText.languageSaveFailed)));
    }
  }
}
