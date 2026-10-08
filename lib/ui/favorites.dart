import 'package:sdahymnal/l10n/app_text.dart';
import '../services/hymnal_repository.dart';
import 'service_playlists.dart';
import 'package:flutter/material.dart';
import 'favorite_lists.dart';
import 'favorite_order.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

/// Favorites tab — content only (the shell renders the brand header above and
/// the bottom nav below): the hymns the user hearted, most recently added
/// first. Rows mirror the Search list rows, with a trailing heart that
/// unfavorites instead of a chevron.
class FavoritesTab extends StatelessWidget {
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;
  final List<Hymn> additionalHymns;
  final HymnalRepository? serviceRepository;

  const FavoritesTab(
      {super.key,
      required this.hymnsNew,
      required this.hymnsOld,
      this.additionalHymns = const [],
      this.serviceRepository});

  /// Looks up the favorite's Hymn in the matching version list; null when it
  /// cannot be resolved (such favorites are skipped, not shown broken).
  Hymn? _resolve(({int n, String v}) e) {
    final list = switch (e.v) {
      'new' => hymnsNew,
      'old' => hymnsOld,
      _ => additionalHymns.where((h) => h.version == e.v).toList(),
    };
    for (final h in list) {
      if (h.number == e.n) return h;
    }
    return null;
  }

  void _openHymn(BuildContext context, Hymn hymn, {FavoriteSublist? category}) {
    Navigator.push(
      context,
      slideRoute(HymnPage(
        hymn: hymn,
        analyticsSource: 'favorites',
        categoryTitle: category?.name ?? context.appText.favorites,
        hymns: category == null
            ? Favorites.instance.value.map(_resolve).whereType<Hymn>().toList()
            : category.hymns.map(_resolve).whereType<Hymn>().toList(),
      )),
    );
  }

  void _reorder(BuildContext context, {String? categoryId}) => Navigator.push(
      context,
      slideRoute(FavoriteOrderPage(sublistId: categoryId, resolve: _resolve)));

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final saved = Favorites.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([saved, saved.sublists]),
      builder: (context, _) {
        final hymns = saved.value.map(_resolve).whereType<Hymn>().toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                    child: TextButton.icon(
                  key: const ValueKey('create-favorite-sublist'),
                  onPressed: () => editFavoriteSublist(context),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(context.appText.newFavoriteCategory),
                )),
                if (serviceRepository != null)
                  PopupMenuButton<String>(
                      tooltip: context.appText.moreFavoritesOptions,
                      onSelected: (_) => Navigator.push(
                          context,
                          slideRoute(ServicePlaylistsPage(
                              repository: serviceRepository!))),
                      itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'services',
                                child: Text(context.appText.servicePlaylists))
                          ]),
              ],
            ),
            for (final list in saved.sublists.value)
              ExpansionTile(
                key: PageStorageKey('favorite-sublist-${list.id}'),
                leading: Icon(Icons.folder_outlined, color: t.accent),
                title: Text(list.name),
                subtitle: Text(context.appText.hymnCount(list.hymns.length)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  PopupMenuButton<String>(
                    tooltip: context.appText.manageList(list.name),
                    onSelected: (action) async {
                      if (action == 'rename') {
                        await editFavoriteSublist(context, list: list);
                      } else if (action == 'reorder') {
                        _reorder(context, categoryId: list.id);
                      } else {
                        final remove = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                                  title: Text(context.appText
                                      .deleteListQuestion(list.name)),
                                  content:
                                      Text(context.appText.deleteCategoryHelp),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(context.appText.cancel)),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(context.appText.delete)),
                                  ],
                                ));
                        if (remove == true) await saved.deleteSublist(list.id);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'rename', child: Text(context.appText.rename)),
                      PopupMenuItem(
                          value: 'reorder',
                          child: Text(context.appText.reorderHymns)),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(context.appText.deleteCategory)),
                    ],
                  ),
                  const Icon(Icons.expand_more),
                ]),
                children: [
                  if (list.hymns.isEmpty)
                    Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(context.appText.emptyFavoriteCategory)),
                  for (final hymn in list.hymns.map(_resolve).whereType<Hymn>())
                    _buildRow(context, hymn, category: list),
                ],
              ),
            if (saved.sublists.value.isNotEmpty)
              Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(context.appText.mainFavorites,
                      style: TextStyle(fontWeight: FontWeight.bold))),
            if (hymns.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(32),
                  child: _emptyState(context, t)),
            if (saved.value.length > 1)
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      key: const ValueKey('reorder-main-favorites'),
                      onPressed: () => _reorder(context),
                      icon: const Icon(Icons.reorder),
                      label: Text(context.appText.reorderFavorites))),
            for (final hymn in hymns) _buildRow(context, hymn),
          ],
        );
      },
    );
  }

  Widget _emptyState(BuildContext context, HymnalTokens t) {
    return Center(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '${context.appText.noFavoritesYet}\n'),
          TextSpan(
            text: context.appText.addFavoritesHelp,
            style: TextStyle(fontSize: 11.5),
          ),
        ]),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 13,
          color: t.faint,
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, Hymn hymn,
      {FavoriteSublist? category}) {
    final t = context.tokens;
    return Pressable(
      onTap: () => _openHymn(context, hymn, category: category),
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : Colors.transparent,
          border: Border(bottom: BorderSide(color: t.line2)),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 28),
              alignment: Alignment.centerRight,
              child: Text(
                '${hymn.number}',
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hymn.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.12,
                  color: t.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            VersionBadge(
              isNew: hymn.version == 'new',
              label: hymn.isEnglishEdition ? null : hymn.bookLabel,
              fontSize: 7.5,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            ),
            const SizedBox(width: 12),
            Pressable.child(
              onTap: () => saveFavorite(context, hymn),
              pressedScale: 0.9,
              child: HymnalIcons.heart(t.accent, filled: true),
            ),
          ],
        ),
      ),
    );
  }
}
