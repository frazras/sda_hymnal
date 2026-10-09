import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/app_language.dart';

const interfaceLanguageNames = {
  'en': 'English',
  'es': 'Español',
  'pt': 'Português',
  'ru': 'Русский',
};

Future<void> showAppLanguagePicker(BuildContext context) async {
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
        child: ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
      child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(context.appText.interfaceLanguage,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(context.appText.interfaceLanguageHelp),
            const SizedBox(height: 8),
            for (final entry in interfaceLanguageNames.entries)
              ListTile(
                  key: ValueKey('interface-language-${entry.key}'),
                  title: Text(entry.value),
                  selected:
                      AppLanguage.instance.value.languageCode == entry.key,
                  trailing: AppLanguage.instance.value.languageCode == entry.key
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, entry.key)),
          ]),
    )),
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
