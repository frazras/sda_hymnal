import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_book.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/search_normalization.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/kit.dart';

/// A book's own topical index, in the same layout as "Hymns by occasion".
/// Paired books (Spanish) switch editions with pills, like the occasion page.
class BookTopicsPage extends StatefulWidget {
  const BookTopicsPage({super.key, required this.packs});

  /// Packs of the selected language that carry topics, newest first.
  final List<HymnalPack> packs;

  @override
  State<BookTopicsPage> createState() => _BookTopicsPageState();
}

class _BookTopicsPageState extends State<BookTopicsPage> {
  final _query = TextEditingController();
  late final List<HymnalPack> _packs =
      widget.packs.where((p) => p.topics.isNotEmpty).toList();
  late HymnalPack? _pack = _packs.isEmpty ? null : _packs.first;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(HymnalTopic topic) {
    final query = normalizeHymnSearch(_query.text);
    return query.isEmpty ||
        normalizeHymnSearch('${topic.group} ${topic.title}').contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pack = _pack;
    final topics = pack?.topics.where(_matches).toList() ?? const [];
    final groups = <String>[];
    for (final topic in topics) {
      if (!groups.contains(topic.group)) groups.add(topic.group);
    }
    return HymnalPage(
      title: context.appText.topics,
      body: ListView(
        key: const ValueKey('book-topics'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          HymnSearchField(
            controller: _query,
            hint: context.appText.searchTopicsOccasions,
            clearTooltip: context.appText.clearSearch,
            onChanged: (_) => setState(() {}),
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          ),
          if (_packs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Wrap(spacing: 7, runSpacing: 6, children: [
                for (final option in _packs)
                  FilterPill(
                    key: ValueKey('topic-edition-${option.edition.id}'),
                    label: editionShortLabel(
                        option.edition.id, option.edition.displayName),
                    selected: option == _pack,
                    onTap: () => setState(() => _pack = option),
                  ),
              ]),
            ),
          if (topics.isEmpty)
            EmptyHint(title: context.appText.noMatchingTopics)
          else
            for (final group in groups) ...[
              SectionLabel(group.toUpperCase(), padding: sectionPadding()),
              HymnalCard(
                child: Column(children: [
                  for (final (i, topic)
                      in topics.where((x) => x.group == group).indexed)
                    SettingsRow(
                      key: ValueKey('topic-${topic.id}'),
                      title: topic.title,
                      trailing: RowValue('${topic.hymns.length}'),
                      divider: i <
                          topics.where((x) => x.group == group).length - 1,
                      onTap: () => Navigator.push(
                          context,
                          slideRoute(
                              TopicHymnsPage(topic: topic, pack: pack!))),
                    ),
                ]),
              ),
            ],
          if (topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                pack!.edition.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: kSans, fontSize: 11.5, color: t.faint),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hymns in one topic. Swiping in the reader stays inside the topic.
class TopicHymnsPage extends StatelessWidget {
  const TopicHymnsPage({super.key, required this.topic, required this.pack});
  final HymnalTopic topic;
  final HymnalPack pack;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hymns = topic.hymns;
    return HymnalPage(
      title: topic.title,
      body: ListView(
        key: ValueKey('topic-hymns-${topic.id}'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              '${topic.group} · ${context.appText.hymnCount(hymns.length)}',
              style: TextStyle(fontFamily: kSans, fontSize: 12.5, color: t.muted),
            ),
          ),
          for (final Hymn hymn in hymns)
            HymnRow(
              key: ValueKey('topic-hymn-${hymn.version}-${hymn.number}'),
              number: '${hymn.number}',
              title: hymn.title,
              textDirection: hymnTextDirection(hymn),
              onTap: () => Navigator.push(
                  context,
                  slideRoute(HymnPage(
                    hymn: hymn,
                    hymns: List.unmodifiable(hymns),
                    categoryTitle: topic.title,
                    analyticsSource: 'topic',
                  ))),
            ),
        ],
      ),
    );
  }
}
