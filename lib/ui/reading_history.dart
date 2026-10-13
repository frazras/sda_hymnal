import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/kit.dart';
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
      builder: (context, _) => HymnalPage(
        title: context.appText.readingHistory,
        trailing: HeaderAction(
            icon: Icons.delete_outline,
            tooltip: context.appText.clearHistory,
            onTap: recents.value.isEmpty || recents.storageError.value
                ? null
                : () => _clear(context)),
        body: Column(children: [
          const SavedHymnNotice(),
          Expanded(
              child: recents.value.isEmpty
                  ? EmptyHint(title: context.appText.noRecentHymns)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 6, bottom: 24),
                      itemCount: recents.value.length,
                      itemBuilder: (context, position) {
                        final entry = recents.value[position];
                        final hymn = index[entry];
                        return HymnRow(
                          key: ValueKey('history-${entry.v}-${entry.n}'),
                          number: '${entry.n}',
                          title: hymn?.title ?? context.appText.hymnUnavailable,
                          textDirection:
                              hymn == null ? null : hymnTextDirection(hymn),
                          subtitle: hymn?.bookLabel ?? entry.v,
                          trailing: hymn == null ? const SizedBox(width: 14) : null,
                          onTap: hymn == null
                              ? () {}
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
        ]),
      ),
    );
  }
}
