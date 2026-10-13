import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/search_normalization.dart';
import 'package:sdahymnal/services/title_collation.dart';
import 'common.dart';
import 'hymnPage.dart';
import 'kit.dart';
import 'package:sdahymnal/theme.dart';

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
    final index = await showHymnalSheet<int>(
      context,
      title: context.appText.jumpToLetter,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in initials.entries)
            _LetterKey(
                letter: entry.key,
                onTap: () => Navigator.pop(sheet, entry.value)),
        ]),
      ),
    );
    if (!mounted || index == null || !_scroll.hasClients) return;
    await _scroll.animateTo(
        (index * extent).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  String _languageLabel(String language) => widget.hymns
      .where((h) => h.languageTag == language)
      .map((h) => h.bookLabel)
      .toSet()
      .join(' · ');

  @override
  Widget build(BuildContext context) => HymnalPage(
        title: context.appText.alphabeticalBrowse,
        body: Column(children: [
          if (_languages.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(children: [
                for (final language in _languages)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterPill(
                      key: ValueKey('alphabet-language-$language'),
                      label: _languageLabel(language),
                      selected: language == _language,
                      onTap: () => setState(() {
                        _language = language;
                        _ordered = _load();
                      }),
                    ),
                  ),
              ]),
            ),
          Expanded(
              child: FutureBuilder<List<Hymn>>(
            key: ValueKey(_language),
            future: _ordered,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return EmptyHint(
                    title: context.appText.noMatchingHymns,
                    action: TextButton.icon(
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
              final extent = 76.0 *
                  MediaQuery.textScalerOf(context)
                      .scale(1)
                      .clamp(1, double.infinity);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(context.appText.hymnCount(hymns.length),
                            style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 12,
                                color: context.tokens.faint)),
                      ),
                    ),
                    Flexible(
                      child: LinkAction(
                          icon: Icons.sort_by_alpha,
                          label: context.appText.jumpToLetter,
                          onTap: hymns.isEmpty
                              ? null
                              : () => _jump(hymns, extent)),
                    ),
                  ]),
                ),
                Expanded(
                    child: ListView.builder(
                        controller: _scroll,
                        itemExtent: extent,
                        itemCount: hymns.length,
                        itemBuilder: (context, index) {
                          final hymn = hymns[index];
                          return HymnRow(
                              key: ValueKey(
                                  'alphabetical-${hymn.version}-${hymn.number}'),
                              number: '${hymn.number}',
                              title: hymn.title,
                              textDirection: hymnTextDirection(hymn),
                              subtitle: hymn.bookLabel,
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

class _LetterKey extends StatelessWidget {
  const _LetterKey({required this.letter, required this.onTap});
  final String letter;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: Pressable(
        onTap: onTap,
        builder: (context, pressed) => Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pressed ? t.tint : t.surface,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(t.isClassic ? 4 : 12),
          ),
          child: Text(letter,
              style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: t.accent)),
        ),
      ),
    );
  }
}
