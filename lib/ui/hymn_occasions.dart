import 'dart:convert';
import '../l10n/app_text.dart';
import '../services/search_normalization.dart';

import 'package:flutter/services.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/ui/additional_readings.dart';
import 'package:flutter/material.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymn_occasion.dart';
import 'package:sdahymnal/services/trends.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/kit.dart';

class HymnOccasionsPage extends StatefulWidget {
  final List<Hymn> hymns;

  const HymnOccasionsPage({super.key, required this.hymns});

  @override
  State<HymnOccasionsPage> createState() => _HymnOccasionsPageState();
}

class _HymnOccasionsPageState extends State<HymnOccasionsPage> {
  String _query = '';

  bool _matches(HymnOccasion topic) {
    final query = normalizeHymnSearch(_query);
    final original = curatedHymnOccasions.where((o) => o.id == topic.id);
    final aliases = topicalCrossReferences.entries
        .where((entry) => entry.value.contains(topic.title))
        .map((entry) => entry.key)
        .join(' ');
    return normalizeHymnSearch(
            '$aliases ${topic.title} ${topic.description} ${original.map((o) => o.title).join(' ')}')
        .contains(query);
  }

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final occasions = hymnOccasions.where(_matches).toList();
    return HymnalPage(
      title: context.appText.hymnsByOccasion,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(context.appText.topicsIntro,
                style: TextStyle(
                    fontFamily: kSans, fontSize: 13, height: 1.4, color: t.muted)),
          ),
          HymnSearchField(
            controller: _search,
            hint: context.appText.searchTopicsOccasions,
            clearTooltip: context.appText.clearSearch,
            onChanged: (value) => setState(() => _query = value),
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          ),
          if (occasions.isEmpty)
            EmptyHint(title: context.appText.noMatchingTopics)
          else
            HymnalCard(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(children: [
                for (final (i, occasion) in occasions.indexed)
                  Pressable(
                    key: ValueKey('occasion-${occasion.id}'),
                    onTap: () => Navigator.push(
                        context,
                        slideRoute(OccasionHymnsPage(
                            occasion: occasion, hymns: widget.hymns))),
                    pressedScale: 1.0,
                    builder: (context, pressed) => Container(
                      padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
                      decoration: BoxDecoration(
                        color: pressed ? t.surface2 : Colors.transparent,
                        border: i < occasions.length - 1
                            ? Border(bottom: BorderSide(color: t.line2))
                            : null,
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(occasion.title,
                                    style: TextStyle(
                                        fontFamily: kSerif,
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w500,
                                        color: t.ink)),
                                const SizedBox(height: 3),
                                Text(occasion.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontFamily: kSans,
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: t.muted)),
                              ]),
                        ),
                        const SizedBox(width: 12),
                        HymnalIcons.rowChevron(t.faint, size: 15),
                      ]),
                    ),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

class OccasionHymnsPage extends StatefulWidget {
  final HymnOccasion occasion;
  final List<Hymn> hymns;
  final AdditionalReadingCatalog? readingCatalog;

  const OccasionHymnsPage(
      {super.key,
      required this.occasion,
      required this.hymns,
      this.readingCatalog});

  @override
  State<OccasionHymnsPage> createState() => _OccasionHymnsPageState();
}

class _OccasionHymnsPageState extends State<OccasionHymnsPage> {
  String _version = 'new';
  AdditionalReadingCatalog? _readings;
  bool _readingsFailed = false;
  Map<String, int> _popularity = researchedPopularity;

  @override
  void initState() {
    super.initState();
    _loadPopularity();
    _readings = widget.readingCatalog;
    if (_readings == null && widget.occasion.newReadingNumbers.isNotEmpty) {
      _loadReadings();
    }
  }

  Future<void> _loadReadings() async {
    setState(() => _readingsFailed = false);
    try {
      // loadString caches failed futures; a retry must request the asset again.
      final data = await rootBundle
          .loadString('assets/additional_readings.json', cache: false);
      final catalog = AdditionalReadingCatalog.fromJson(
          jsonDecode(data) as Map<String, dynamic>);
      if (mounted) setState(() => _readings = catalog);
    } catch (_) {
      if (mounted) setState(() => _readingsFailed = true);
    }
  }

  Future<void> _loadPopularity() async {
    try {
      final snapshot = await TrendsRepository().load();
      final scores = <String, int>{};
      // Blend the available community windows. A hymn that is consistently
      // popular outranks a one-week spike, while the 1-week window keeps the
      // list responsive to current listening.
      for (final period in snapshot.periods.values) {
        for (final song in period.songs) {
          final key = '${song.edition}:${song.hymn}';
          scores[key] = (scores[key] ?? 0) + song.count;
        }
      }
      if (mounted) {
        setState(() => _popularity = {...researchedPopularity, ...scores});
      }
    } catch (_) {
      // Suggestions remain fully usable offline in curated order.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final suggestions = widget.occasion
        .hymnsFor(widget.hymns, _version, popularity: _popularity);
    final readings = widget.occasion
        .readingsFor(_readings ?? const AdditionalReadingCatalog([]), _version);
    final hasReadingRefs =
        _version == 'new' && widget.occasion.newReadingNumbers.isNotEmpty;
    final readingCount = hasReadingRefs && _readings == null
        ? (_readingsFailed
            ? context.appText.topicReadingsUnavailable
            : context.appText.topicReadingsLoading)
        : context.appText.topicReadingCount(readings.length);
    return HymnalPage(
      title: widget.occasion.title,
      body: ListView(
        key: ValueKey('${widget.occasion.id}-$_version'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Text(widget.occasion.description,
                style: TextStyle(
                    fontFamily: kSerif, fontSize: 17, height: 1.45, color: t.ink)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final version in ['new', 'old'])
                  FilterPill(
                    key: ValueKey('occasion-edition-$version'),
                    label: version == 'new'
                        ? context.appText.newHymnal
                        : context.appText.oldHymnal,
                    selected: _version == version,
                    onTap: () => setState(() => _version = version),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
            child: Text(
                '${context.appText.hymnCount(suggestions.length)} • $readingCount${suggestions.isNotEmpty && _popularity.isNotEmpty ? ' • ${context.appText.hymnsPopularityRanked}' : ''}',
                style: TextStyle(fontFamily: kSans, fontSize: 12, color: t.muted)),
          ),
          if (suggestions.isEmpty && !hasReadingRefs)
            EmptyHint(title: context.appText.occasionNoSelections),
          for (final hymn in suggestions)
            HymnRow(
              key: ValueKey('occasion-${hymn.version}-${hymn.number}'),
              number: '${hymn.number}',
              title: hymn.title.trim(),
              textDirection: hymnTextDirection(hymn),
              onTap: () => Navigator.push(
                  context,
                  slideRoute(HymnPage(
                    hymn: hymn,
                    hymns: List.unmodifiable(suggestions),
                    categoryTitle: widget.occasion.title,
                  ))),
            ),
          if (hasReadingRefs && _readings == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _readingsFailed
                  ? Center(
                      child: TextButton(
                          onPressed: _loadReadings,
                          child: Text(context.appText.readingsLoadRetry)))
                  : const Center(child: CircularProgressIndicator()),
            ),
          if (readings.isNotEmpty) ...[
            SectionLabel(context.appText.scriptureReadings.toUpperCase(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 6)),
            for (final reading in readings)
              HymnRow(
                key: ValueKey('occasion-reading-${reading.id}'),
                number: '${reading.number}',
                title: reading.title,
                subtitle:
                    '${context.appText.reading}${reading.scriptureReference == null ? '' : ' • ${reading.scriptureReference}'}',
                onTap: () => Navigator.push(
                    context,
                    slideRoute(AdditionalReadingPage(
                      reading: reading,
                      readings: readings,
                      categoryTitle: widget.occasion.title,
                    ))),
              ),
          ],
        ],
      ),
    );
  }
}
