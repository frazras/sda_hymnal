import 'package:sdahymnal/l10n/app_text.dart';
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
              title: Text(context.appText.clearHistoryQuestion),
              content: Text(context.appText.clearHistoryHelp),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.appText.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.appText.clear)),
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
        appBar: AppBar(title: Text(context.appText.readingHistory), actions: [
          IconButton(
              tooltip: context.appText.clearHistory,
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
                  ? Center(child: Text(context.appText.noRecentHymns))
                  : ListView.builder(
                      itemCount: recents.value.length,
                      itemBuilder: (context, position) {
                        final entry = recents.value[position];
                        final hymn = index[entry];
                        return ListTile(
                          key: ValueKey('history-${entry.v}-${entry.n}'),
                          leading: Text('${entry.n}'),
                          title: Text(
                              hymn?.title ?? context.appText.hymnUnavailable),
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
