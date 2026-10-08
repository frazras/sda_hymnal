import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../l10n/app_text.dart';

import '../models/hymn.dart';
import '../services/analytics.dart';
import '../services/trends.dart';
import '../theme.dart';
import 'common.dart';
import 'hymnPage.dart';

String statisticNumber(int value, [String locale = 'en']) =>
    NumberFormat.decimalPattern(locale).format(value);

String statisticDate(DateTime date, [String locale = 'en']) =>
    DateFormat('d MMM y', locale).format(date);

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
      // Also support standalone English previews without application delegates.
      await initializeDateFormatting();
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
    final text = context.appText;
    final locale = text.localeName;
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
            title: context.appText.statisticsTitle,
            trailing: IconButton(
                tooltip: context.appText.refreshStatistics,
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
                Text(context.appText.communityInSong,
                    style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
                const SizedBox(height: 8),
                Text(context.appText.communityInSongHelp,
                    style: TextStyle(color: t.muted, height: 1.5)),
                const SizedBox(height: 20),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final value in ['1', '4', '8'])
                    ChoiceChip(
                        label: Text(value == '1'
                            ? text.lastWeek
                            : text.statisticsWeeks(int.parse(value))),
                        selected: _period == value,
                        onSelected: (_) => setState(() => _period = value))
                ]),
                const SizedBox(height: 16),
                if (snapshot != null && period != null) ...[
                  Text(
                      '${statisticDate(period.start, locale)} – ${statisticDate(period.end, locale)}',
                      style:
                          TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                      text.reportDateHelp(
                          snapshot.offline
                              ? text.savedReport
                              : text.reportUpdated,
                          statisticDate(snapshot.generated.toLocal(), locale)),
                      style:
                          TextStyle(fontSize: 12, color: t.muted, height: 1.5)),
                  if (snapshot.offline ||
                      DateTime.now().difference(snapshot.generated) >
                          const Duration(days: 2))
                    _notice(context.appText.olderReportHelp),
                  _rankings(
                      context.appText.mostOpenedHymns,
                      context.appText.mostOpenedHelp,
                      period.songs,
                      text.statisticsOpens),
                  _rankings(
                      context.appText.returningHymns,
                      context.appText.returningHymnsHelp,
                      period.repeats,
                      text.statisticsRepeatOpens),
                  _rankings(
                      context.appText.addedToFavorites,
                      context.appText.addedToFavoritesHelp,
                      period.favorites,
                      text.statisticsAdditions),
                  _card(
                      context.appText.whenHymnalOpened,
                      context.appText.whenHymnalOpenedHelp,
                      StatisticBars(values: period.times, labels: {
                        'night': context.appText.statisticsNight,
                        'morning': context.appText.statisticsMorning,
                        'afternoon': context.appText.statisticsAfternoon,
                        'evening': context.appText.statisticsEvening
                      })),
                  _card(
                      context.appText.daysFilledWithSong,
                      context.appText.daysFilledWithSongHelp,
                      StatisticBars(values: period.weekdays, labels: {
                        '1': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 1)),
                        '2': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 2)),
                        '3': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 3)),
                        '4': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 4)),
                        '5': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 5)),
                        '6': DateFormat.EEEE(locale)
                            .format(DateTime(2024, 1, 6)),
                        '7':
                            DateFormat.EEEE(locale).format(DateTime(2024, 1, 7))
                      })),
                  _card(
                      context.appText.aroundTheWorld,
                      context.appText.aroundTheWorldHelp,
                      country == null
                          ? _empty()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  DropdownButtonFormField<String>(
                                      key:
                                          ValueKey('country-$_period-$country'),
                                      initialValue: country,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: text.countryIsoCode,
                                          border: OutlineInputBorder()),
                                      items: [
                                        for (final code
                                            in period.countries.keys)
                                          DropdownMenuItem(
                                              value: code,
                                              child: Text(_countryLabel(code),
                                                  maxLines: 2))
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _country = value)),
                                  const SizedBox(height: 12),
                                  _songList(period.countries[country]!,
                                      text.statisticsOpens),
                                ])),
                  _notice(text.statisticsExplanation),
                ] else if (_failed) ...[
                  _notice(context.appText.communityStatisticsFailed),
                  OutlinedButton.icon(
                      onPressed: () => _load(true),
                      icon: const Icon(Icons.refresh),
                      label: Text(text.retry)),
                ] else if (_loading)
                  Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(context.appText.loadingCommunityStatistics)),
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
      child: Text(context.appText.communityInsightsGrowing,
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
          String Function(int) unit) =>
      _card(title, subtitle, songs.isEmpty ? _empty() : _songList(songs, unit));

  Widget _songList(List<SongStatistic> songs, String Function(int) unit) {
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
                                    '${song.edition == 'new' ? context.appText.statisticsNewEdition : context.appText.statisticsOldEdition} ${song.hymn} · ${unit(song.count)}',
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
    final text = context.appText;
    final names = {
      'JM': text.jamaica,
      'US': text.countryUS,
      'GB': text.countryGB,
      'CA': text.countryCA,
      'TT': text.countryTT,
      'GY': text.countryGY,
      'BB': text.countryBB,
      'BS': text.countryBS,
      'ZA': text.countryZA,
      'KE': text.countryKE,
      'NG': text.countryNG,
      'GH': text.countryGH,
      'PH': text.countryPH,
      'AU': text.countryAU,
      'NZ': text.countryNZ,
      'IN': text.countryIN,
      'ZW': text.countryZW,
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
                      '${entry.value} · ${values.containsKey(entry.key) ? context.appText.statisticsOpens(values[entry.key]!) : context.appText.notEnoughPublishedData}',
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
