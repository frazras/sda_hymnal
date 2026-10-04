import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/models/hymnal_pack.dart';
import 'package:sdahymnal/services/hymn_search.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';

class HymnalSelector extends StatelessWidget {
  final List<HymnalPack> packs;
  final String value;
  final ValueChanged<String> onChanged;
  const HymnalSelector(
      {super.key,
      required this.packs,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DropdownButton<String>(
          key: const ValueKey('hymnal-selector'),
          value: value,
          isExpanded: true,
          hint: const Text('Choose hymnal'),
          items: [
            const DropdownMenuItem(
                value: 'english',
                child: Text('English · Old & New Hymnal',
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            for (final pack in packs)
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

/// Shared offline browsing for the imported editions. The English keypad keeps
/// its established dual-book workflow; each imported edition has its own list.
class HymnalBrowser extends StatefulWidget {
  final HymnalPack pack;
  final bool numbersOnly;
  final bool keyboardOpen;
  const HymnalBrowser(
      {super.key,
      required this.pack,
      this.numbersOnly = false,
      this.keyboardOpen = false});

  @override
  State<HymnalBrowser> createState() => _HymnalBrowserState();
}

class _HymnalBrowserState extends State<HymnalBrowser> {
  final _query = TextEditingController();
  HymnalTopic? _topic;

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
              title: const Text('Topics'),
              trailing: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))),
          Expanded(
              child: ListView(children: [
            ListTile(
                title: const Text('All hymns'),
                onTap: () => Navigator.pop(context, 'all')),
            for (final group in widget.pack.topics.map((t) => t.group).toSet())
              ExpansionTile(title: Text(group), children: [
                for (final topic
                    in widget.pack.topics.where((t) => t.group == group))
                  ListTile(
                      title: Text(topic.title),
                      subtitle: Text('${topic.hymns.length} hymns'),
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
            labelText:
                widget.numbersOnly ? 'Hymn number' : 'Title, lyrics or number',
            prefixIcon: Icon(widget.numbersOnly ? Icons.numbers : Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
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
          Expanded(
              child: Text('${results.length} hymns · Offline',
                  style: TextStyle(color: t.muted))),
          if (widget.keyboardOpen ||
              MediaQuery.viewInsetsOf(context).bottom > 0)
            TextButton(
                onPressed: () => FocusScope.of(context).unfocus(),
                child: const Text('Done')),
          Flexible(
              child: TextButton.icon(
                  onPressed: _chooseTopic,
                  icon: const Icon(Icons.list_alt),
                  label: Text(_topic?.title ?? 'Topics',
                      maxLines: 2, overflow: TextOverflow.ellipsis))),
        ]),
      ),
      Expanded(
          child: results.isEmpty
              ? const Center(child: Text('No hymn found in this edition.'))
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
