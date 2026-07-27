import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

/// Favorites sub-page (full-screen, pushed with slideRoute): the hymns the
/// user hearted, most recently added first. Rows mirror the Search list rows,
/// with a trailing heart that unfavorites instead of a chevron.
class FavoritesPage extends StatelessWidget {
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  const FavoritesPage(
      {super.key, required this.hymnsNew, required this.hymnsOld});

  /// Looks up the favorite's Hymn in the matching version list; null when it
  /// cannot be resolved (such favorites are skipped, not shown broken).
  Hymn? _resolve(({int n, String v}) e) {
    final list = e.v == 'new' ? hymnsNew : hymnsOld;
    for (final h in list) {
      if (h.number == e.n) return h;
    }
    return null;
  }

  void _openHymn(BuildContext context, Hymn hymn) {
    Navigator.push(
      context,
      slideRoute(HymnPage(
        hymn: hymn,
        hymns: hymn.version == 'new' ? hymnsNew : hymnsOld,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Favorites'),
            Expanded(
              child: ValueListenableBuilder<List<({int n, String v})>>(
                valueListenable: Favorites.instance,
                builder: (context, favorites, _) {
                  final hymns =
                      favorites.map(_resolve).whereType<Hymn>().toList();
                  if (hymns.isEmpty) return _emptyState(t);
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: hymns.length,
                    itemBuilder: (context, index) =>
                        _buildRow(context, hymns[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(HymnalTokens t) {
    return Center(
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'No favorites yet\n'),
          const TextSpan(
            text: 'Tap the heart on any hymn to save it here',
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

  Widget _buildRow(BuildContext context, Hymn hymn) {
    final t = context.tokens;
    return Pressable(
      onTap: () => _openHymn(context, hymn),
      pressedScale: 1.0,
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: pressed ? t.surface2 : Colors.transparent,
          border: Border(bottom: BorderSide(color: t.line2)),
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 34),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: t.ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            VersionBadge(
              isNew: hymn.version == 'new',
              fontSize: 9,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            ),
            const SizedBox(width: 12),
            Pressable.child(
              onTap: () => Favorites.instance.toggle(hymn),
              pressedScale: 0.9,
              child: HymnalIcons.heart(t.accent, filled: true),
            ),
          ],
        ),
      ),
    );
  }
}
