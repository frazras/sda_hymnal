import 'dart:convert';

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
    final query = _query.trim().toLowerCase();
    final original = curatedHymnOccasions.where((o) => o.id == topic.id);
    final aliases = topicalCrossReferences.entries
        .where((entry) => entry.value.contains(topic.title))
        .map((entry) => entry.key)
        .join(' ');
    return '$aliases ${topic.title} ${topic.description} ${original.map((o) => o.title).join(' ')}'
        .toLowerCase()
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
            const SubPageHeader(title: 'Hymns by occasion'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Hymns and readings by topic',
                      style: TextStyle(
                          fontFamily: kSerif, fontSize: 26, color: t.ink)),
                  const SizedBox(height: 8),
                  Text(
                      'Explore the hymnal’s topical index alongside our existing occasion selections.',
                      style: TextStyle(
                          fontFamily: kSans, height: 1.5, color: t.muted)),
                  const SizedBox(height: 20),
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      hintText: 'Search topics and occasions',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!hymnOccasions.any(_matches))
                    const Text('No matching topics.'),
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
      final data =
          await rootBundle.loadString('assets/additional_readings.json');
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
                          label: Text(
                              version == 'new' ? 'New Hymnal' : 'Old Hymnal'),
                          selected: _version == version,
                          onSelected: (_) => setState(() => _version = version),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                      '${suggestions.length} hymns • ${readings.length} readings${suggestions.isNotEmpty && _popularity.isNotEmpty ? ' • Hymns popularity ranked' : ''}',
                      style: TextStyle(fontFamily: kSans, color: t.muted)),
                  const SizedBox(height: 8),
                  if (suggestions.isEmpty && !hasReadingRefs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                          'No selections are available in this hymnal yet.',
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
                            hymns: widget.hymns
                                .where((h) => h.version == hymn.version)
                                .toList(),
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
                              child:
                                  const Text('Could not load readings. Retry'))
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  if (readings.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Scripture readings',
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
                            'Reading${reading.scriptureReference == null ? '' : ' • ${reading.scriptureReference}'}'),
                        trailing: Icon(Icons.chevron_right, color: t.faint),
                        onTap: () => Navigator.push(
                            context,
                            slideRoute(AdditionalReadingPage(
                              reading: reading,
                              readings: readings,
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
