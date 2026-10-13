import 'package:sdahymnal/l10n/app_text.dart';
import 'dart:async';
import 'alphabetical_hymns.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/analytics.dart';
import 'package:sdahymnal/services/hymn_search.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_book.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/classic.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/hymn_occasions.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:sdahymnal/ui/kit.dart';

/// Search tab, shared by every language (content-only: the shell renders the
/// brand header above and the bottom nav below). Paired books offer
/// All / New / Old pills; single books search their one edition; the
/// all-languages scope labels every result with its book.
class HymnList extends StatefulWidget {
  final List<Hymn> hymns;
  final List<Hymn> hymnsNew;
  final List<Hymn> hymnsOld;
  final bool active;
  final bool english;

  /// Search every installed book; results carry a language badge.
  final bool allLanguages;

  /// The shell's Scaffold hides the keyboard inset from its body, so it
  /// reports an open keyboard explicitly.
  final bool keyboardOpen;

  /// Edition pill labels for paired books (book's own names).
  final String? newLabel;
  final String? oldLabel;
  final VoidCallback? onTopics;
  final AdditionalReadingCatalog additionalReadings;

  const HymnList(
      {super.key,
      this.active = true,
      this.english = true,
      this.allLanguages = false,
      this.keyboardOpen = false,
      this.newLabel,
      this.oldLabel,
      this.onTopics,
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

  bool get _paired => widget.hymnsOld.isNotEmpty && widget.hymnsNew.isNotEmpty;

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
      if (!_paired) _filter = 'ALL';
      _applyFilter();
    }
  }

  List<Hymn> get _currentHymns => !_paired
      ? widget.hymns
      : (_filter == 'OLD')
          ? widget.hymnsOld
          : (_filter == 'NEW')
              ? widget.hymnsNew
              : widget.hymns;

  void _applyFilter() {
    _filteredHymns = searchHymns(_currentHymns, _query);
  }

  String get _countText => _query.trim().isEmpty
      ? context.appText.hymnCount(_filteredHymns.length)
      : context.appText.matchCount(_filteredHymns.length);

  void _openHymn(Hymn hymn) {
    FocusScope.of(context).unfocus();
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
        hymns: widget.hymns.where((h) => h.version == hymn.version).toList(),
      )),
    );
  }

  String _editionLabel(bool isNew) => widget.english
      ? (isNew ? context.appText.newHymnal : context.appText.oldHymnal)
      : (isNew
          ? (widget.newLabel ?? context.appText.newEdition)
          : (widget.oldLabel ?? context.appText.oldEdition));

  Widget _chipsRow(HymnalTokens t) {
    if (!_paired && _query.trim().isEmpty) return const SizedBox(height: 4);
    void select(String key) => setState(() {
          _filter = key;
          AppAnalytics.instance.event('search_filter', variant: key);
          _applyFilter();
        });
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 7,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_paired) ...[
            FilterPill(
                label: context.appText.all,
                selected: _filter == 'ALL',
                onTap: () => select('ALL')),
            FilterPill(
                label: _editionLabel(true),
                selected: _filter == 'NEW',
                onTap: () => select('NEW')),
            FilterPill(
                label: _editionLabel(false),
                selected: _filter == 'OLD',
                onTap: () => select('OLD')),
          ],
          if (_query.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: _paired ? 2 : 0, top: 4),
              child: Text(
                _countText,
                style:
                    TextStyle(fontFamily: kSans, fontSize: 12, color: t.faint),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _badge(Hymn hymn) {
    if (widget.allLanguages) {
      return _ScopeBadge(crossLanguageBadge(hymn));
    }
    if (!_paired) return null;
    final label = pairedBadgeLabel(hymn.version);
    if (label == null) return null;
    return VersionBadge(
      isNew: widget.hymnsNew.isNotEmpty &&
          hymn.version == widget.hymnsNew.first.version,
      label: label,
      fontSize: 7.5,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final t = context.tokens;
    final hymn = _filteredHymns[index];

    if (t.isClassic) {
      return KeyedSubtree(
          key: ValueKey('search-hymn-${hymn.version}-${hymn.number}'),
          child: ClassicSearchRow(hymn: hymn, onTap: () => _openHymn(hymn)));
    }
    return ValueListenableBuilder<List<({int n, String v})>>(
      valueListenable: Favorites.instance,
      builder: (context, _, __) => HymnRow(
        key: ValueKey('search-hymn-${hymn.version}-${hymn.number}'),
        number: '${hymn.number}',
        title: hymn.title,
        textDirection: hymnTextDirection(hymn),
        badge: _badge(hymn),
        favorite: Favorites.instance.contains(hymn.number, hymn.version),
        onTap: () => _openHymn(hymn),
      ),
    );
  }

  Widget _browseRow() {
    final keyboard =
        widget.keyboardOpen || MediaQuery.viewInsetsOf(context).bottom > 0;
    final browse = _query.trim().isEmpty && !keyboard;
    final topics = widget.english
        ? (widget.hymns.isEmpty
            ? null
            : () {
                FocusScope.of(context).unfocus();
                Navigator.push(context,
                    slideRoute(HymnOccasionsPage(hymns: widget.hymns)));
              })
        : widget.onTopics;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          if (browse)
            LinkAction(
              icon: Icons.sort_by_alpha,
              label: context.appText.alphabeticalShort,
              onTap: _currentHymns.isEmpty
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      Navigator.push(context,
                          slideRoute(AlphabeticalHymns(hymns: _currentHymns)));
                    },
            ),
          if (!widget.allLanguages && (widget.english || topics != null))
            Flexible(
              child: LinkAction(
                icon: Icons.library_music_outlined,
                label: widget.english
                    ? context.appText.hymnsByOccasion
                    : context.appText.topics,
                onTap: topics,
              ),
            ),
          if (widget.english)
            Flexible(
              child: LinkAction(
                icon: Icons.menu_book_outlined,
                label: context.appText.additionalReadings,
                onTap: widget.additionalReadings.readings.isEmpty
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                          context,
                          slideRoute(AdditionalReadingsPage(
                              catalog: widget.additionalReadings)),
                        );
                      },
              ),
            ),
          if (keyboard) ...[
            const Spacer(),
            TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                child: Text(context.appText.done)),
          ],
        ],
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
              showFilter: _paired,
              // Classic keeps the original short NEW / OLD wording.
              filterLabel: switch (_filter) {
                'NEW' => (widget.english
                        ? context.appText.newEdition
                        : _editionLabel(true))
                    .toUpperCase(),
                'OLD' => (widget.english
                        ? context.appText.oldEdition
                        : _editionLabel(false))
                    .toUpperCase(),
                _ => context.appText.all.toUpperCase(),
              },
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
          HymnSearchField(
            key: const ValueKey('search-query'),
            controller: _searchController,
            hint: widget.allLanguages
                ? context.appText.searchAllLanguages
                : context.appText.searchByTitleLyricsNumber,
            clearTooltip: context.appText.clearSearch,
            onChanged: _setQuery,
            onSubmitted: (_) {
              if (_filteredHymns.length == 1) _openHymn(_filteredHymns.single);
            },
          ),
          _chipsRow(t),
        ],
        _browseRow(),
        const SizedBox(height: 4),
        Expanded(
          child: _filteredHymns.isEmpty
              ? EmptyHint(
                  title: context.appText.noMatchingHymns,
                  message: widget.allLanguages
                      ? null
                      : context.appText.searchOtherLanguagesHint)
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.zero,
                  itemCount: _filteredHymns.length,
                  itemBuilder: _buildRow,
                ),
        ),
      ],
    );
  }
}

/// One-line language/edition badge for all-language results.
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: t.muted,
        ),
      ),
    );
  }
}
