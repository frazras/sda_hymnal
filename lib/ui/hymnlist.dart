import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:sdahymnal/services/hymn_search.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_occasions.dart';
import 'package:sdahymnal/ui/additional_readings.dart';

/// Search tab (content-only: the shell renders the brand header above and
/// the bottom nav below). Mockup: Search v2.dc.html.
class HymnList extends StatefulWidget {
  final List<Hymn> hymns;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;
  final bool active;
  final AdditionalReadingCatalog additionalReadings;

  const HymnList(
      {super.key,
      this.active = true,
      this.additionalReadings = const AdditionalReadingCatalog([]),
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
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  final Stopwatch _searchWatch = Stopwatch();
  bool _pendingSearch = false;

  void _recordSearch() {
    _searchTimer?.cancel();
    if (!widget.active || _query.trim().isEmpty) return;
    final count = _filteredHymns.length;
    AppAnalytics.instance.event('search_results',
        variant: count == 0
            ? 'zero'
            : count <= 5
                ? '1_5'
                : count <= 20
                    ? '6_20'
                    : '21_plus');
  }

  void _abandonSearch() {
    _searchTimer?.cancel();
    if (_pendingSearch) AppAnalytics.instance.event('search_abandon');
    _pendingSearch = false;
    _searchWatch.stop();
  }

  @override
  void dispose() {
    _abandonSearch();
    _searchController.dispose();
    super.dispose();
  }

  void _setQuery(String query) {
    if (!_searchWatch.isRunning && query.trim().isNotEmpty) {
      _searchWatch
        ..reset()
        ..start();
    }
    if (_pendingSearch && !(_searchTimer?.isActive ?? false)) {
      AppAnalytics.instance.event('search_refine');
    }
    _pendingSearch = query.trim().isNotEmpty;
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 700), _recordSearch);
    setState(() {
      _query = query;
      _applyFilter();
    });
  }

  @override
  void initState() {
    super.initState();
    _filteredHymns = widget.hymns;
  }

  @override
  void didUpdateWidget(HymnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) _abandonSearch();
    if (oldWidget.hymns != widget.hymns) {
      _applyFilter();
    }
  }

  List<Hymn> get _currentHymns => (_filter == 'OLD')
      ? widget.hymnsOld
      : (_filter == 'NEW')
          ? widget.hymnsNew
          : widget.hymns;

  void _applyFilter() {
    _filteredHymns = searchHymns(_currentHymns, _query);
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
    if (_searchTimer?.isActive ?? false) _recordSearch();
    if (_query.trim().isNotEmpty) {
      final rank = _filteredHymns.indexOf(hymn) + 1;
      AppAnalytics.instance.event('search_select',
          variant: rank == 1
              ? '1'
              : rank <= 5
                  ? '2_5'
                  : '6_plus');
      if (_searchWatch.isRunning) {
        AppAnalytics.instance.event('search_select_ms',
            total: _searchWatch.elapsedMilliseconds.clamp(0, 3600000));
      }
    }
    _pendingSearch = false;
    _searchWatch.stop();
    Navigator.push(
      context,
      slideRoute(HymnPage(
        hymn: hymn,
        analyticsSource: 'search',
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
              controller: _searchController,
              onChanged: _setQuery,
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
          AppAnalytics.instance.event('search_filter', variant: key);
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

    if (t.isClassic) {
      return ClassicSearchRow(hymn: hymn, onTap: () => _openHymn(hymn));
    }

    return Pressable(
      onTap: () => _openHymn(hymn),
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
            const SizedBox(width: 10),
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
              fontSize: 7.5,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
        if (t.isClassic)
          ClassicSearchControls(
              controller: _searchController,
              filter: _filter,
              onQuery: _setQuery,
              onFilter: () => setState(() {
                    _filter = switch (_filter) {
                      'ALL' => 'OLD',
                      'OLD' => 'NEW',
                      _ => 'ALL'
                    };
                    _applyFilter();
                  }))
        else ...[
          _searchField(t),
          _chipsRow(t),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.hymns.isEmpty
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                              context,
                              slideRoute(
                                  HymnOccasionsPage(hymns: widget.hymns)));
                        },
                  icon: const Icon(Icons.library_music_outlined, size: 18),
                  label: const Text('Hymns by occasion',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: widget.additionalReadings.readings.isEmpty
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                            context,
                            slideRoute(AdditionalReadingsPage(
                                catalog: widget.additionalReadings)),
                          );
                        },
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Additional readings',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
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
