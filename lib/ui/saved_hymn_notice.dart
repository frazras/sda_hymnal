import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/prefs.dart';

/// An unreadable/unsaved collection stays protected, rather than being silently
/// replaced by an empty list. Retrying reloads it without deleting any key.
class SavedHymnNotice extends StatelessWidget {
  const SavedHymnNotice({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([
          Favorites.instance.storageError,
          Recents.instance.storageError,
        ]),
        builder: (context, _) {
          final favorites = Favorites.instance.storageError.value;
          final recents = Recents.instance.storageError.value;
          if (!favorites && !recents) return const SizedBox.shrink();
          final name = favorites && recents
              ? context.appText.favoritesAndRecents
              : favorites
                  ? context.appText.favorites
                  : context.appText.recentHymns;
          return Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.appText.savedListError(name),
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        if (favorites) await Favorites.instance.load();
                        if (recents) await Recents.instance.load();
                      },
                      child: Text(context.appText.retryLoading),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
