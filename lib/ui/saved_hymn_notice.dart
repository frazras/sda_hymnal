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
              ? 'Favorites and recent hymns'
              : favorites
                  ? 'Favorites'
                  : 'Recent hymns';
          return Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Expanded(
                    child: Text(
                        '$name could not be loaded or saved. '
                        'Changes are paused to protect your saved lists.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer))),
                TextButton(
                    onPressed: () async {
                      if (favorites) await Favorites.instance.load();
                      if (recents) await Recents.instance.load();
                    },
                    child: const Text('Retry')),
              ]),
            ),
          );
        },
      );
}
