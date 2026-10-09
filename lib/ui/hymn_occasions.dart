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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: context.appText.hymnsByOccasion),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(context.appText.topicsHeading,
                      style: TextStyle(
                          fontFamily: kSerif, fontSize: 26, color: t.ink)),
                  const SizedBox(height: 8),
                  Text(context.appText.topicsIntro,
                      style: TextStyle(
                          fontFamily: kSans, height: 1.5, color: t.muted)),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.appText.searchTopicsOccasions,
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!hymnOccasions.any(_matches))
                    Text(context.appText.noMatchingTopics),
                  for (final occasion in hymnOccasions.where(_matches))
                    Card(
                      color: t.surface,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: t.line2),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        title: Text(occasion.title,
                            style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 20,
                                color: t.ink)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(occasion.description,
                              style: TextStyle(
                                  fontFamily: kSans,
                                  height: 1.4,
                                  color: t.muted)),
                        ),
                        trailing: Icon(Icons.chevron_right, color: t.accent),
                        onTap: () => Navigator.push(
                            context,
                            slideRoute(OccasionHymnsPage(
                                occasion: occasion, hymns: widget.hymns))),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubPageHeader(title: widget.occasion.title),
            Expanded(
              child: ListView(
                key: ValueKey('${widget.occasion.id}-$_version'),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(widget.occasion.description,
                      style: TextStyle(
                          fontFamily: kSerif,
                          fontSize: 20,
                          height: 1.5,
                          color: t.ink)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      for (final version in ['new', 'old'])
                        ChoiceChip(
                          label: Text(version == 'new'
                              ? context.appText.newHymnal
                              : context.appText.oldHymnal),
                          selected: _version == version,
                          onSelected: (_) => setState(() => _version = version),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                      '${context.appText.hymnCount(suggestions.length)} • $readingCount${suggestions.isNotEmpty && _popularity.isNotEmpty ? ' • ${context.appText.hymnsPopularityRanked}' : ''}',
                      style: TextStyle(fontFamily: kSans, color: t.muted)),
                  const SizedBox(height: 8),
                  if (suggestions.isEmpty && !hasReadingRefs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(context.appText.occasionNoSelections,
                          style: TextStyle(color: t.muted)),
                    ),
                  for (final hymn in suggestions) ...[
                    ListTile(
                      key: ValueKey('occasion-${hymn.version}-${hymn.number}'),
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 46,
                        child: Text('${hymn.number}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 20,
                                color: t.accent)),
                      ),
                      title: Text(hymn.title.trim(),
                          style: TextStyle(
                              fontFamily: kSerif, fontSize: 19, color: t.ink)),
                      trailing: Icon(Icons.chevron_right, color: t.faint),
                      onTap: () => Navigator.push(
                          context,
                          slideRoute(HymnPage(
                            hymn: hymn,
                            hymns: List.unmodifiable(suggestions),
                            categoryTitle: widget.occasion.title,
                          ))),
                    ),
                    Divider(height: 1, color: t.line2),
                  ],
                  if (hasReadingRefs && _readings == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _readingsFailed
                          ? TextButton(
                              onPressed: _loadReadings,
                              child: Text(context.appText.readingsLoadRetry))
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  if (readings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(context.appText.scriptureReadings,
                        style: TextStyle(
                            fontFamily: kSerif, fontSize: 22, color: t.ink)),
                    for (final reading in readings)
                      ListTile(
                        key: ValueKey('occasion-reading-${reading.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                            width: 46,
                            child: Text('${reading.number}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: kSerif,
                                    fontSize: 20,
                                    color: t.accent))),
                        title: Text(reading.title,
                            style: TextStyle(
                                fontFamily: kSerif,
                                fontSize: 19,
                                color: t.ink)),
                        subtitle: Text(
                            '${context.appText.reading}${reading.scriptureReference == null ? '' : ' • ${reading.scriptureReference}'}'),
                        trailing: Icon(Icons.chevron_right, color: t.faint),
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
            ),
          ],
        ),
      ),
    );
  }
}
