import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/saved_hymn_notice.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/kit.dart';

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
        return HymnalPage(
          title: context.appText
              .reorderList(category?.name ?? context.appText.favorites),
          body: ReorderableListView.builder(
            header: Column(children: [
              const SavedHymnNotice(),
              Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
                  child: Text(context.appText.reorderHelp,
                      style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          height: 1.4,
                          color: context.tokens.muted))),
            ]),
            buildDefaultDragHandles: false,
            itemCount: entries.length,
            onReorderItem: (from, to) =>
                saved.reorderHymns(from, to, sublistId: sublistId),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final hymn = resolve(entry);
              return Material(
                key: ValueKey('order-${entry.v}-${entry.n}'),
                color: context.tokens.bg,
                child: HymnRow(
                  number: '${entry.n}',
                  title: hymn?.title ?? context.appText.hymnUnavailable,
                  subtitle: hymn?.bookLabel ?? entry.v,
                  onTap: () {},
                  trailing: saved.storageError.value
                      ? const SizedBox(width: 14)
                      : ReorderableDragStartListener(
                          index: index,
                          child: Semantics(
                              label: context.appText
                                  .moveHymn(hymn?.title ?? entry.n.toString()),
                              child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle,
                                      color: context.tokens.faint))),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
