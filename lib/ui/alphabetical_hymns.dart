import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/search_normalization.dart';
import 'package:sdahymnal/services/title_collation.dart';
import 'common.dart';
import 'hymnPage.dart';

String titleInitial(Hymn hymn) {
  final title = normalizeHymnSearch(hymn.title, foldLatinAccents: false);
  if (title.isEmpty) return '#';
  var initial = String.fromCharCode(title.runes.first);
  if (!(hymn.languageTag.startsWith('es') && initial == 'ñ')) {
    initial = normalizeHymnSearch(initial);
  }
  return RegExp(r'^\p{L}', unicode: true).hasMatch(initial)
      ? initial.toUpperCase()
      : '#';
}

/// A dedicated browse route keeps letter controls out of relevance-ranked search.
class AlphabeticalHymns extends StatefulWidget {
  const AlphabeticalHymns({super.key, required this.hymns});
  final List<Hymn> hymns;
  @override
  State<AlphabeticalHymns> createState() => _AlphabeticalHymnsState();
}

class _AlphabeticalHymnsState extends State<AlphabeticalHymns> {
  final _scroll = ScrollController();
  late final _languages =
      widget.hymns.map((h) => h.languageTag).toSet().toList();
  late String _language = _languages.isEmpty ? 'en' : _languages.first;
  late Future<List<Hymn>> _ordered = _load();

  Future<List<Hymn>> _load() async {
    final hymns =
        widget.hymns.where((h) => h.languageTag == _language).toList();
    final order = await TitleCollation.order(
        hymns.map((h) => h.title).toList(), _language);
    return List.unmodifiable(order.map((i) => hymns[i]));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _jump(List<Hymn> hymns, double extent) async {
    final initials = <String, int>{};
    for (var i = 0; i < hymns.length; i++) {
      initials.putIfAbsent(titleInitial(hymns[i]), () => i);
    }
    final index = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
          child: SingleChildScrollView(
              child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.appText.jumpToLetter,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in initials.entries)
              OutlinedButton(
                  onPressed: () => Navigator.pop(context, entry.value),
                  child: Text(entry.key)),
          ]),
        ]),
      ))),
    );
    if (!mounted || index == null || !_scroll.hasClients) return;
    await _scroll.animateTo(
        (index * extent).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.appText.alphabeticalBrowse)),
        body: Column(children: [
          if (_languages.length > 1)
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String>(
                  value: _language,
                  isExpanded: true,
                  items: [
                    for (final language in _languages)
                      DropdownMenuItem(
                          value: language,
                          child: Text(
                              widget.hymns
                                  .where((h) => h.languageTag == language)
                                  .map((h) => h.bookLabel)
                                  .toSet()
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (language) {
                    if (language != null) {
                      setState(() {
                        _language = language;
                        _ordered = _load();
                      });
                    }
                  },
                )),
          Expanded(
              child: FutureBuilder<List<Hymn>>(
            key: ValueKey(_language),
            future: _ordered,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton.icon(
                        onPressed: () => setState(() {
                              _ordered = _load();
                            }),
                        icon: const Icon(Icons.refresh),
                        label: Text(context.appText.retry)));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final hymns = snapshot.data!;
              final extent =
                  96.0 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 3);
              return Column(children: [
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed:
                            hymns.isEmpty ? null : () => _jump(hymns, extent),
                        icon: const Icon(Icons.sort_by_alpha),
                        label: Text(context.appText.jumpToLetter))),
                Expanded(
                    child: ListView.builder(
                        controller: _scroll,
                        itemExtent: extent,
                        itemCount: hymns.length,
                        itemBuilder: (context, index) {
                          final hymn = hymns[index];
                          return ListTile(
                              key: ValueKey(
                                  'alphabetical-${hymn.version}-${hymn.number}'),
                              leading: Text('${hymn.number}'),
                              title: Text(hymn.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(hymn.bookLabel,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              onTap: () => Navigator.push(
                                  context,
                                  slideRoute(HymnPage(
                                      hymn: hymn,
                                      hymns: hymns
                                          .where(
                                              (h) => h.version == hymn.version)
                                          .toList(),
                                      analyticsSource: 'search'))));
                        })),
              ]);
            },
          )),
        ]),
      );
}

class AlphabeticalBrowseButton extends StatelessWidget {
  const AlphabeticalBrowseButton({super.key, required this.hymns});
  final List<Hymn> hymns;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.appText.alphabeticalBrowse,
        icon: const Icon(Icons.sort_by_alpha),
        onPressed: hymns.isEmpty
            ? null
            : () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                    context, slideRoute(AlphabeticalHymns(hymns: hymns)));
              },
      );
}
