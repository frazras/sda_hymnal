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
import 'package:sdahymnal/ui/kit.dart';
import 'package:sdahymnal/models/hymnal_book.dart';

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

  Future<void> _manage(BuildContext context, FavoriteSublist list,
      String action) async {
    final saved = Favorites.instance;
    if (action == 'rename') {
      await editFavoriteSublist(context, list: list);
    } else if (action == 'reorder') {
      _reorder(context, categoryId: list.id);
    } else {
      final remove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(context.appText.deleteListQuestion(list.name)),
                content: Text(context.appText.deleteCategoryHelp),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.appText.cancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.appText.delete)),
                ],
              ));
      if (remove == true) await saved.deleteSublist(list.id);
    }
  }

  Widget _sectionHeader(BuildContext context, String label, Widget? action) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 12, 4),
        child: Row(children: [
          Expanded(child: SectionLabel(label.toUpperCase())),
          if (action != null) Flexible(child: action),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final saved = Favorites.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([saved, saved.sublists]),
      builder: (context, _) {
        final hymns = saved.value.map(_resolve).whereType<Hymn>().toList();
        final categories = saved.sublists.value;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (serviceRepository != null)
              HymnalCard(
                margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: SettingsRow(
                  key: const ValueKey('open-service-playlists'),
                  leading: RowIcon(Icons.queue_music_outlined, color: t.accent),
                  title: context.appText.servicePlaylists,
                  subtitle: context.appText.servicePlaylistsHelp,
                  onTap: () => Navigator.push(
                      context,
                      slideRoute(
                          ServicePlaylistsPage(repository: serviceRepository!))),
                ),
              ),
            _sectionHeader(
              context,
              context.appText.favoriteCategories,
              LinkAction(
                key: const ValueKey('create-favorite-sublist'),
                icon: Icons.add,
                label: context.appText.newCategoryShort,
                onTap: () => editFavoriteSublist(context),
              ),
            ),
            if (categories.isNotEmpty)
              HymnalCard(
                child: Column(children: [
                  for (final (i, list) in categories.indexed)
                    Container(
                      decoration: BoxDecoration(
                          border: i < categories.length - 1
                              ? Border(bottom: BorderSide(color: t.line2))
                              : null),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: PageStorageKey('favorite-sublist-${list.id}'),
                          tilePadding: const EdgeInsets.only(left: 16, right: 4),
                          leading:
                              Icon(Icons.folder_outlined, color: t.accent, size: 22),
                          title: Text(list.name,
                              style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: t.ink)),
                          subtitle: Text(
                              context.appText.hymnCount(list.hymns.length),
                              style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 12.5,
                                  color: t.muted)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            PopupMenuButton<String>(
                              tooltip: context.appText.manageList(list.name),
                              icon: Icon(Icons.more_vert,
                                  size: 20, color: t.faint),
                              onSelected: (action) =>
                                  _manage(context, list, action),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'rename',
                                    child: Text(context.appText.rename)),
                                PopupMenuItem(
                                    value: 'reorder',
                                    child: Text(context.appText.reorderHymns)),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.appText.deleteCategory)),
                              ],
                            ),
                            Icon(Icons.expand_more, color: t.faint),
                          ]),
                          children: [
                            if (list.hymns.isEmpty)
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  child: Text(
                                      context.appText.emptyFavoriteCategory,
                                      style: TextStyle(
                                          fontFamily: kSans,
                                          fontSize: 12.5,
                                          color: t.muted))),
                            for (final hymn
                                in list.hymns.map(_resolve).whereType<Hymn>())
                              _buildRow(context, hymn, category: list),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
            _sectionHeader(
              context,
              categories.isNotEmpty
                  ? context.appText.mainFavorites
                  : context.appText.favorites,
              saved.value.length > 1
                  ? LinkAction(
                      key: const ValueKey('reorder-main-favorites'),
                      icon: Icons.swap_vert,
                      label: context.appText.reorderShort,
                      onTap: () => _reorder(context))
                  : null,
            ),
            if (hymns.isEmpty)
              EmptyHint(
                  title: context.appText.noFavoritesYet,
                  message: context.appText.addFavoritesHelp),
            for (final hymn in hymns) _buildRow(context, hymn),
          ],
        );
      },
    );
  }

  Widget _buildRow(BuildContext context, Hymn hymn,
      {FavoriteSublist? category}) {
    final t = context.tokens;
    final badge = hymn.isEnglishEdition
        ? VersionBadge(
            isNew: hymn.version == 'new',
            fontSize: 7.5,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3))
        : VersionBadge(
            isNew: true,
            label: crossLanguageBadge(hymn),
            fontSize: 7.5,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3));
    return HymnRow(
      key: ValueKey(
          'favorite-${category?.id ?? 'main'}-${hymn.version}-${hymn.number}'),
      number: '${hymn.number}',
      title: hymn.title,
      textDirection: hymnTextDirection(hymn),
      badge: badge,
      onTap: () => _openHymn(context, hymn, category: category),
      trailing: Pressable.child(
        onTap: () => saveFavorite(context, hymn),
        pressedScale: 0.9,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: HymnalIcons.heart(t.accent, filled: true),
        ),
      ),
    );
  }
}
