import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../services/analytics.dart';
import '../services/trends.dart';
import '../theme.dart';
import 'common.dart';
import 'hymnPage.dart';

String statisticNumber(int value) => '$value'
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String statisticDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.hymns, this.load});
  final List<Hymn> hymns;
  final Future<TrendsSnapshot> Function(bool force)? load;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  TrendsSnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  String _period = '4';
  String? _country;
  final _repository = TrendsRepository();

  @override
  void initState() {
    super.initState();
    AppAnalytics.instance.screen('statistics');
    _load(false);
  }

  @override
  void dispose() {
    AppAnalytics.instance.screen('settings');
    super.dispose();
  }

  Future<void> _load(bool force) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final value =
          await (widget.load?.call(force) ?? _repository.load(force: force));
      if (mounted) {
        setState(() {
          _snapshot = value;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open(SongStatistic song) async {
    final matches = widget.hymns
        .where((h) => h.version == song.edition && h.number == song.hymn);
    if (matches.isEmpty) return;
    await Navigator.push(
        context,
        slideRoute(HymnPage(
            hymn: matches.first,
            hymns:
                widget.hymns.where((h) => h.version == song.edition).toList(),
            analyticsSource: 'statistics')));
    // The hymn page records its own reading time; return to this screen.
    if (mounted) AppAnalytics.instance.screen('statistics');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final snapshot = _snapshot;
    final period = snapshot?.periods[_period];
    final country = period?.countries.containsKey(_country) == true
        ? _country
        : (period?.countries.keys.firstOrNull);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
          child: Column(children: [
        SubPageHeader(
            title: 'Statistics',
            trailing: IconButton(
                tooltip: 'Refresh statistics',
                onPressed: _loading ? null : () => _load(true),
                icon: const Icon(Icons.refresh))),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: RefreshIndicator(
          onRefresh: () => _load(true),
          child: ListView(
              key: const ValueKey('statistics-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              children: [
                Text('A community in song',
                    style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
                const SizedBox(height: 8),
                Text(
                    'Discover the hymns our community opens, returns to, and adds to favorites.',
                    style: TextStyle(color: t.muted, height: 1.5)),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final value in ['1', '4', '8'])
                    ChoiceChip(
                        label:
                            Text(value == '1' ? 'Last week' : '$value weeks'),
                        selected: _period == value,
                        onSelected: (_) => setState(() => _period = value))
                ]),
                const SizedBox(height: 16),
                if (snapshot != null && period != null) ...[
                  Text(
                      '${statisticDate(period.start)} – ${statisticDate(period.end)}',
                      style:
                          TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      '${snapshot.offline ? 'Offline · Saved report' : 'Report updated'} ${statisticDate(snapshot.generated.toLocal())}. '
                      'Completed weeks only; weekly uploads can arrive later.',
                      style:
                          TextStyle(fontSize: 12, color: t.muted, height: 1.5)),
                  if (snapshot.offline ||
                      DateTime.now().difference(snapshot.generated) >
                          const Duration(days: 2))
                    _notice(
                        'You’re viewing a saved or older report. Refresh when connected for the latest available statistics.'),
                  _rankings(
                      'Most-opened hymns',
                      'A place to begin your next time of worship.',
                      period.songs,
                      'opens'),
                  _rankings(
                      'Hymns we return to',
                      'Additional opens of the same hymn on one installation within a calendar week. This does not measure complete performances.',
                      period.repeats,
                      'repeat opens'),
                  _rankings(
                      'Added to favorites',
                      'Hymns people saved during this period. These are additions, not everyone’s current favorites.',
                      period.favorites,
                      'additions'),
                  _card(
                      'When we open the hymnal',
                      'Times are local to each device when the hymn was opened.',
                      StatisticBars(values: period.times, labels: const {
                        'night': 'Night · 12–6 am',
                        'morning': 'Morning · 6 am–12 pm',
                        'afternoon': 'Afternoon · 12–6 pm',
                        'evening': 'Evening · 6 pm–12 am'
                      })),
                  _card(
                      'Days filled with song',
                      'Hymn opens by the local day of the week.',
                      StatisticBars(values: period.weekdays, labels: const {
                        '1': 'Monday',
                        '2': 'Tuesday',
                        '3': 'Wednesday',
                        '4': 'Thursday',
                        '5': 'Friday',
                        '6': 'Saturday',
                        '7': 'Sunday'
                      })),
                  _card(
                      'Around the world',
                      'Popular hymns by upload country. Travel and network routing can affect country estimates.',
                      country == null
                          ? _empty()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  DropdownButtonFormField<String>(
                                      key:
                                          ValueKey('country-$_period-$country'),
                                      initialValue: country,
                                      decoration: const InputDecoration(
                                          labelText: 'Country (ISO code)',
                                          border: OutlineInputBorder()),
                                      items: [
                                        for (final code
                                            in period.countries.keys)
                                          DropdownMenuItem(
                                              value: code,
                                              child: Text(_countryLabel(code)))
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _country = value)),
                                  const SizedBox(height: 12),
                                  _songList(
                                      period.countries[country]!, 'opens'),
                                ])),
                  _notice(
                      'About these numbers\n\nThese are shared activity counts, not unique people or the number of times a hymn was sung. '
                      'Each published weekly group needs at least 20 participating installations. Small groups and some related totals are withheld, so charts may be incomplete. '
                      'New measurements need time to gather enough contributions.\n\nEveryone sees the same community report. You can view it even when sharing is off in Settings.'),
                ] else if (_failed) ...[
                  _notice(
                      'Community statistics are unavailable right now. Connect to the internet and try again. After your first successful download, the saved report will be available offline.'),
                  OutlinedButton.icon(
                      onPressed: () => _load(true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again')),
                ] else if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Loading community statistics…')),
              ]),
        )),
      ])),
    );
  }

  Widget _notice(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(text,
          style: TextStyle(
              color: context.tokens.muted, fontSize: 12, height: 1.6)));

  Widget _empty() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
          'Community insights are growing. Results appear here when enough people have contributed.',
          style: TextStyle(color: context.tokens.muted, height: 1.5)));

  Widget _card(String title, String subtitle, Widget child) {
    final t = context.tokens;
    return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(t.isClassic ? 4 : 18)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: t.ink)),
          const SizedBox(height: 7),
          Text(subtitle,
              style: TextStyle(fontSize: 12, height: 1.5, color: t.muted)),
          const SizedBox(height: 16),
          child,
        ]));
  }

  Widget _rankings(String title, String subtitle, List<SongStatistic> songs,
          String unit) =>
      _card(title, subtitle, songs.isEmpty ? _empty() : _songList(songs, unit));

  Widget _songList(List<SongStatistic> songs, String unit) {
    final t = context.tokens;
    final max = songs.fold<int>(
        1, (value, song) => song.count > value ? song.count : value);
    return Column(children: [
      for (final (index, song) in songs.take(10).indexed)
        Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: widget.hymns.any((h) =>
                        h.number == song.hymn && h.version == song.edition)
                    ? () => _open(song)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 30,
                              child: Text('${index + 1}',
                                  style: TextStyle(
                                      fontSize: 19,
                                      color: t.accent,
                                      fontFamily: kSerif))),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Text(song.title,
                                    style: TextStyle(
                                        color: t.ink,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                    '${song.edition == 'new' ? 'New' : 'Old'} ${song.hymn} · ${statisticNumber(song.count)} $unit',
                                    style: TextStyle(
                                        fontSize: 12, color: t.muted)),
                                const SizedBox(height: 8),
                                ExcludeSemantics(
                                    child: LinearProgressIndicator(
                                        value: song.count / max,
                                        minHeight: 4,
                                        color: t.accent,
                                        backgroundColor: t.tint,
                                        borderRadius:
                                            BorderRadius.circular(8))),
                              ])),
                        ]))))
    ]);
  }

  String _countryLabel(String code) {
    const names = {
      'JM': 'Jamaica',
      'US': 'United States',
      'GB': 'United Kingdom',
      'CA': 'Canada',
      'TT': 'Trinidad and Tobago',
      'GY': 'Guyana',
      'BB': 'Barbados',
      'BS': 'Bahamas',
      'ZA': 'South Africa',
      'KE': 'Kenya',
      'NG': 'Nigeria',
      'GH': 'Ghana',
      'PH': 'Philippines',
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'IN': 'India',
      'ZW': 'Zimbabwe'
    };
    return names.containsKey(code) ? '${names[code]} ($code)' : code;
  }
}

class StatisticBars extends StatelessWidget {
  const StatisticBars({super.key, required this.values, required this.labels});
  final Map<String, int> values;
  final Map<String, String> labels;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final max = values.values.fold<int>(1, (a, b) => b > a ? b : a);
    return Column(children: [
      for (final entry in labels.entries)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      '${entry.value} · ${values.containsKey(entry.key) ? '${statisticNumber(values[entry.key]!)} opens' : 'Not enough published data'}',
                      style: TextStyle(color: t.ink, fontSize: 12)),
                  const SizedBox(height: 7),
                  ExcludeSemantics(
                      child: LinearProgressIndicator(
                          value: (values[entry.key] ?? 0) / max,
                          minHeight: 9,
                          color: t.accent,
                          backgroundColor: t.tint,
                          borderRadius: BorderRadius.circular(8))),
                ]))
    ]);
  }
}
