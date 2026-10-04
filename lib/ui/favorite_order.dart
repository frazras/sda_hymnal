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
          appBar:
              AppBar(title: Text('Reorder ${category?.name ?? 'Favorites'}')),
          body: SafeArea(
              child: Column(children: [
            const SavedHymnNotice(),
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'Drag a handle to change the order. Changes are saved automatically.')),
            Expanded(
                child: ReorderableListView.builder(
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
                  title: Text(hymn?.title ?? 'Hymn unavailable'),
                  subtitle: Text(hymn?.bookLabel ?? entry.v),
                  trailing: saved.storageError.value
                      ? null
                      : ReorderableDragStartListener(
                          index: index,
                          child: Semantics(
                              label: 'Move ${hymn?.title ?? entry.n}',
                              child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.drag_handle))),
                        ),
                );
              },
            )),
          ])),
        );
      },
    );
  }
}
