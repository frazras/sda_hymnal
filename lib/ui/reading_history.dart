import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/hymnPage.dart';
import 'package:sdahymnal/ui/saved_hymn_notice.dart';

class ReadingHistoryPage extends StatelessWidget {
  final List<Hymn> hymns;
  const ReadingHistoryPage({super.key, required this.hymns});

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Clear reading history?'),
              content: const Text(
                  'This removes recently opened hymns. Your favorites and categories will stay.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Clear')),
              ],
            ));
    if (confirmed == true) await Recents.instance.clear();
  }

  @override
  Widget build(BuildContext context) {
    final index = {
      for (final hymn in hymns) (n: hymn.number, v: hymn.version): hymn
    };
    final recents = Recents.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([recents, recents.storageError]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Reading history'), actions: [
          IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: recents.value.isEmpty || recents.storageError.value
                  ? null
                  : () => _clear(context)),
        ]),
        body: SafeArea(
            child: Column(children: [
          const SavedHymnNotice(),
          Expanded(
              child: recents.value.isEmpty
                  ? const Center(child: Text('No recently opened hymns'))
                  : ListView.builder(
                      itemCount: recents.value.length,
                      itemBuilder: (context, position) {
                        final entry = recents.value[position];
                        final hymn = index[entry];
                        return ListTile(
                          key: ValueKey('history-${entry.v}-${entry.n}'),
                          leading: Text('${entry.n}'),
                          title: Text(hymn?.title ?? 'Hymn unavailable'),
                          subtitle: Text(hymn?.bookLabel ?? entry.v),
                          trailing: hymn == null
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: hymn == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  slideRoute(HymnPage(
                                      hymn: hymn,
                                      analyticsSource: 'history',
                                      hymns: hymns
                                          .where(
                                              (h) => h.version == hymn.version)
                                          .toList()))),
                        );
                      },
                    )),
        ])),
      ),
    );
  }
}
