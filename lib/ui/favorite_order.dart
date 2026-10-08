import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/saved_hymn_notice.dart';

class FavoriteOrderPage extends StatelessWidget {
  final String? sublistId;
  final Hymn? Function(({int n, String v})) resolve;
  const FavoriteOrderPage({super.key, this.sublistId, required this.resolve});

  @override
  Widget build(BuildContext context) {
    final saved = Favorites.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([saved, saved.sublists, saved.storageError]),
      builder: (context, _) {
        final category = sublistId == null
            ? null
            : saved.sublists.value
                .where((list) => list.id == sublistId)
                .firstOrNull;
        final entries = sublistId == null ? saved.value : category?.hymns ?? [];
        return Scaffold(
          appBar: AppBar(
              title: Text(context.appText
                  .reorderList(category?.name ?? context.appText.favorites))),
          body: SafeArea(
            child: ReorderableListView.builder(
              header: Column(children: [
                const SavedHymnNotice(),
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(context.appText.reorderHelp)),
              ]),
              buildDefaultDragHandles: false,
              itemCount: entries.length,
              onReorderItem: (from, to) =>
                  saved.reorderHymns(from, to, sublistId: sublistId),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final hymn = resolve(entry);
                return ListTile(
                  key: ValueKey('order-${entry.v}-${entry.n}'),
                  leading: Text('${entry.n}'),
                  title: Text(hymn?.title ?? context.appText.hymnUnavailable),
                  subtitle: Text(hymn?.bookLabel ?? entry.v),
                  trailing: saved.storageError.value
                      ? null
                      : ReorderableDragStartListener(
                          index: index,
                          child: Semantics(
                              label: context.appText
                                  .moveHymn(hymn?.title ?? entry.n.toString()),
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.drag_handle))),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
