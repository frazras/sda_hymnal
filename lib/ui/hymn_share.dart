import 'common.dart';
import 'kit.dart';
import 'package:sdahymnal/theme.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/services/hymn_text_export.dart';

class HymnSharePage extends StatefulWidget {
  final Hymn hymn;
  const HymnSharePage({super.key, required this.hymn});
  @override
  State<HymnSharePage> createState() => _HymnSharePageState();
}

class _HymnSharePageState extends State<HymnSharePage> {
  late final _export = HymnTextExport(widget.hymn);
  int _selection = -1;
  bool _sharing = false;
  String get _text => _export.text(section: _selection < 0 ? null : _selection);

  String _sectionLabel(int index) {
    final section = _export.sections[index];
    if (section.verseNumber != null) {
      return context.appText.lyricVerse(section.verseNumber!);
    }
    return section.generatedLabel
        ? context.appText.lyricSection(index + 1)
        : section.label;
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _text));
      if (mounted) _notice(context.appText.lyricsCopied);
    } catch (_) {
      if (mounted) _notice(context.appText.copyLyricsFailed);
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _share(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(ShareParams(
          text: _text,
          subject: '${widget.hymn.number} · ${widget.hymn.title}',
          sharePositionOrigin: origin));
    } catch (_) {
      if (mounted) {
        _notice(context.appText.shareLyricsFailed);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return HymnalPage(
      title: context.appText.copyOrShareLyrics,
      body: Column(children: [
        SingleChildScrollView(
          key: const ValueKey('share-lyric-section'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(children: [
            for (var i = -1; i < _export.sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: FilterPill(
                  label: i < 0 ? context.appText.fullHymn : _sectionLabel(i),
                  selected: _selection == i,
                  onTap: () => setState(() => _selection = i),
                ),
              ),
          ]),
        ),
        Expanded(
          child: HymnalCard(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(_text,
                    textDirection: hymnTextDirection(widget.hymn),
                    textAlign: TextAlign.start,
                    key: const ValueKey('share-lyric-preview'),
                    style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 16,
                        height: 1.55,
                        color: t.ink)),
              ),
            ),
          ),
        ),
      ]),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(context.appText.copyControl)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Builder(
                builder: (buttonContext) => FilledButton.icon(
                    onPressed: _sharing ? null : () => _share(buttonContext),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(context.appText.shareControl))),
          ),
        ]),
      ),
    );
  }
}
