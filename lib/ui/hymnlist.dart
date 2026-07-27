import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

/// Search tab (content-only: the shell renders the brand header above and
/// the bottom nav below). Mockup: Search v2.dc.html.
class HymnList extends StatefulWidget {
  final List<Hymn> hymns;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;

  const HymnList(
      {super.key,
      required this.hymns,
      required this.hymnsOld,
      required this.hymnsNew});

  @override
  State<HymnList> createState() => _HymnListState();
}

class _HymnListState extends State<HymnList> {
  late List<Hymn> _filteredHymns;
  String _filter = 'ALL';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filteredHymns = widget.hymns;
  }

  @override
  void didUpdateWidget(HymnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hymns != widget.hymns) {
      _applyFilter();
    }
  }

  List<Hymn> get _currentHymns => (_filter == 'OLD')
      ? widget.hymnsOld
      : (_filter == 'NEW')
          ? widget.hymnsNew
          : widget.hymns;

  /// Same predicate as the old app / mockup: title contains q, OR
  /// punctuation-stripped body contains q, OR number-as-string contains q
  /// (substring, not exact). Query is trimmed + lowercased; only the body
  /// is punctuation-stripped.
  void _applyFilter() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredHymns = _currentHymns;
      return;
    }
    _filteredHymns = _currentHymns
        .where((h) =>
            h.title.toLowerCase().contains(q) ||
            h.body
                .toLowerCase()
                .replaceAll(RegExp(r'[^\w\s]+'), '')
                .contains(q) ||
            h.number.toString().contains(q))
        .toList();
  }

  /// toLocaleString()-style thousands separator ("1,398").
  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String get _countText {
    final count = _filteredHymns.length;
    if (_query.trim().isEmpty) return '${_thousands(count)} hymns';
    return '${_thousands(count)} ${count == 1 ? 'match' : 'matches'}';
  }

  void _openHymn(Hymn hymn) {
    Navigator.push(
      context,
      slideRoute(HymnPage(
        hymn: hymn,
        hymns: hymn.version == 'new' ? widget.hymnsNew : widget.hymnsOld,
      )),
    );
  }

  Widget _searchField(HymnalTokens t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.cardShadow,
      ),
      child: Row(
        children: [
          HymnalIcons.magnifier(t.faint, size: 18, stroke: 1.8),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (q) {
                setState(() {
                  _query = q;
                  _applyFilter();
                });
              },
              cursorColor: t.accentHi,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 15.5,
                color: t.ink,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search by title, lyrics or number',
                hintStyle: TextStyle(
                  fontFamily: kSans,
                  fontSize: 15.5,
                  color: t.faint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(HymnalTokens t, String key, String label) {
    final selected = _filter == key;
    return Pressable(
      onTap: () {
        setState(() {
          _filter = key;
          _applyFilter();
        });
      },
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.accent : Colors.transparent,
          border: Border.all(color: selected ? t.accent : t.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? t.onAccent : t.muted,
          ),
        ),
      ),
    );
  }

  Widget _chipsRow(HymnalTokens t) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _chip(t, 'ALL', 'All'),
          const SizedBox(width: 7),
          _chip(t, 'NEW', 'New Hymnal'),
          const SizedBox(width: 7),
          _chip(t, 'OLD', 'Old Hymnal'),
          const Spacer(),
          Text(
            _countText,
            style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.faint),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final t = context.tokens;
    final hymn = _filteredHymns[index];

    return Pressable(
      onTap: () => _openHymn(hymn),
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
            // Static favorited indicator (the heart is toggled elsewhere).
            ValueListenableBuilder<List<({int n, String v})>>(
              valueListenable: Favorites.instance,
              builder: (context, _, __) =>
                  Favorites.instance.contains(hymn.number, hymn.version)
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: HymnalIcons.heart(t.accent, size: 13),
                        )
                      : const SizedBox.shrink(),
            ),
            const SizedBox(width: 12),
            HymnalIcons.rowChevron(t.faint, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        _searchField(t),
        _chipsRow(t),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _filteredHymns.length,
            itemBuilder: _buildRow,
          ),
        ),
      ],
    );
  }
}
