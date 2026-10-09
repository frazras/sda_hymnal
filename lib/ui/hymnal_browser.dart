import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'alphabetical_hymns.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/hymn_search.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

class HymnalTopicsPage extends StatelessWidget {
  final List<HymnalPack> packs;
  const HymnalTopicsPage({super.key, required this.packs});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.appText.topics)),
        body: ListView(children: [
          for (final pack in packs) ...[
            if (packs.length > 1)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(pack.edition.displayName)),
            for (final group in pack.topics.map((t) => t.group).toSet())
              ExpansionTile(title: Text(group), children: [
                for (final topic in pack.topics.where((t) => t.group == group))
                  ListTile(
                      title: Text(topic.title),
                      subtitle:
                          Text(context.appText.hymnCount(topic.hymns.length)),
                      onTap: () => Navigator.push(
                          context,
                          slideRoute(Scaffold(
                            appBar: AppBar(title: Text(topic.title)),
                            body:
                                HymnalBrowser(pack: pack, initialTopic: topic),
                          )))),
              ]),
          ],
        ]),
      );
}

class HymnalSelector extends StatelessWidget {
  final List<HymnalPack> packs;
  final String value;
  final ValueChanged<String> onChanged;
  final bool allowAll;
  const HymnalSelector(
      {super.key,
      required this.packs,
      required this.value,
      required this.onChanged,
      this.allowAll = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DropdownButton<String>(
          key: const ValueKey('hymnal-selector'),
          value: value,
          isExpanded: true,
          hint: Text(context.appText.chooseHymnal),
          items: [
            if (allowAll)
              DropdownMenuItem(
                  value: 'all', child: Text(context.appText.allLanguages)),
            const DropdownMenuItem(
                value: 'english',
                child: Text('English · Old & New Hymnal',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (packs.any((p) => p.edition.id == 'sda-es-2009'))
              const DropdownMenuItem(
                  value: 'spanish', child: Text('Español · Nuevo y Antiguo')),
            for (final pack in packs)
              if (pack.edition.languageTag != 'es')
                DropdownMenuItem(
                    value: pack.edition.id,
                    child: Text(pack.edition.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      );
}

/// Search all installed books while retaining each result's own book queue.
class AllHymnalsSearch extends StatefulWidget {
  final List<Hymn> hymns;
  final bool keyboardOpen;
  const AllHymnalsSearch(
      {super.key, required this.hymns, this.keyboardOpen = false});

  @override
  State<AllHymnalsSearch> createState() => _AllHymnalsSearchState();
}

class _AllHymnalsSearchState extends State<AllHymnalsSearch> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchHymns(widget.hymns, _query.text);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
        child: TextField(
          key: const ValueKey('all-books-query'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText: context.appText.searchAllLanguages,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                  tooltip: context.appText.clearSearch,
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(_query.clear))),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          AlphabeticalBrowseButton(hymns: widget.hymns),
          Expanded(
              child: Text(context.appText.hymnCountScope(
                  results.length, context.appText.allLanguages))),
          if (widget.keyboardOpen)
            TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                child: Text(context.appText.done)),
        ]),
      ),
      Expanded(
          child: results.isEmpty
              ? Center(child: Text(context.appText.noMatchingHymns))
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final hymn = results[index];
                    return ListTile(
                      key: ValueKey('all-book-${hymn.version}-${hymn.number}'),
                      leading: Text('${hymn.number}'),
                      title: Text(hymn.title),
                      subtitle: Text(hymn.bookLabel),
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                            context,
                            slideRoute(HymnPage(
                              hymn: hymn,
                              hymns: widget.hymns
                                  .where((h) => h.version == hymn.version)
                                  .toList(),
                              analyticsSource: 'search',
                            )));
                      },
                    );
                  },
                )),
    ]);
  }
}

/// Offline text and topic browsing; Numbers uses the shared number pad.
class HymnalBrowser extends StatefulWidget {
  final HymnalPack pack;
  final bool numbersOnly;
  final bool keyboardOpen;
  final HymnalTopic? initialTopic;
  const HymnalBrowser(
      {super.key,
      required this.pack,
      this.numbersOnly = false,
      this.initialTopic,
      this.keyboardOpen = false});

  @override
  State<HymnalBrowser> createState() => _HymnalBrowserState();
}

class _HymnalBrowserState extends State<HymnalBrowser> {
  final _query = TextEditingController();
  late HymnalTopic? _topic = widget.initialTopic;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Hymn> get _queue => _topic?.hymns ?? widget.pack.hymns;

  void _open(Hymn hymn) {
    FocusScope.of(context).unfocus();
    Navigator.push(
        context,
        slideRoute(HymnPage(
          hymn: hymn,
          hymns: _queue,
          categoryTitle: _topic?.title,
          analyticsSource: 'search',
        )));
  }

  Future<void> _chooseTopic() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
          child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(children: [
          ListTile(
              title: Text(context.appText.topics),
              trailing: IconButton(
                  tooltip: context.appText.close,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))),
          Expanded(
              child: ListView(children: [
            ListTile(
                title: Text(context.appText.allHymns),
                onTap: () => Navigator.pop(context, 'all')),
            for (final group in widget.pack.topics.map((t) => t.group).toSet())
              ExpansionTile(title: Text(group), children: [
                for (final topic
                    in widget.pack.topics.where((t) => t.group == group))
                  ListTile(
                      title: Text(topic.title),
                      subtitle:
                          Text(context.appText.hymnCount(topic.hymns.length)),
                      onTap: () => Navigator.pop(context, topic.id)),
              ]),
          ])),
        ]),
      )),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _topic = selected == 'all'
          ? null
          : widget.pack.topics.firstWhere((t) => t.id == selected);
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final query = _query.text.trim();
    final results = widget.numbersOnly && query.isNotEmpty
        ? _queue.where((h) => '${h.number}' == query).toList()
        : searchHymns(_queue, query);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        child: TextField(
          key: const ValueKey('book-query'),
          controller: _query,
          keyboardType:
              widget.numbersOnly ? TextInputType.number : TextInputType.text,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: widget.numbersOnly
                ? context.appText.hymnNumber
                : context.appText.titleLyricsNumber,
            prefixIcon: Icon(widget.numbersOnly ? Icons.numbers : Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: context.appText.clearSearch,
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_query.clear)),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (results.length == 1) _open(results.single);
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          AlphabeticalBrowseButton(hymns: _queue),
          Expanded(
              child: Text(
                  context.appText
                      .hymnCountScope(results.length, context.appText.offline),
                  style: TextStyle(color: t.muted))),
          if (widget.keyboardOpen ||
              MediaQuery.viewInsetsOf(context).bottom > 0)
            TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                child: Text(context.appText.done)),
          if (widget.pack.topics.isNotEmpty)
            Flexible(
                child: TextButton.icon(
                    onPressed: _chooseTopic,
                    icon: const Icon(Icons.list_alt),
                    label: Text(_topic?.title ?? context.appText.topics,
                        maxLines: 2, overflow: TextOverflow.ellipsis))),
        ]),
      ),
      Expanded(
          child: results.isEmpty
              ? Center(child: Text(context.appText.noHymnInEdition))
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final hymn = results[index];
                    return ListTile(
                      key: ValueKey('book-hymn-${hymn.number}'),
                      leading: Text('${hymn.number}',
                          style: TextStyle(
                              fontSize: 20,
                              color: t.accent,
                              fontWeight: FontWeight.bold)),
                      title: Text(hymn.title, style: TextStyle(color: t.ink)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(hymn),
                    );
                  },
                )),
    ]);
  }
}
