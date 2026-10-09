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
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(context.appText.copyOrShareLyrics)),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DropdownButtonFormField<int>(
              key: const ValueKey('share-lyric-section'),
              initialValue: -1,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: context.appText.includeLyrics),
              items: [
                DropdownMenuItem(
                    value: -1, child: Text(context.appText.fullHymn)),
                for (var i = 0; i < _export.sections.length; i++)
                  DropdownMenuItem(
                      value: i,
                      child: Text(_sectionLabel(i),
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _selection = value ?? -1),
            ),
          ),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(_text,
                    key: const ValueKey('share-lyric-preview'),
                    style: Theme.of(context).textTheme.bodyLarge)),
          )),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy),
                    label: Text(context.appText.copyControl)),
                Builder(
                    builder: (buttonContext) => FilledButton.icon(
                        onPressed:
                            _sharing ? null : () => _share(buttonContext),
                        icon: const Icon(Icons.share_outlined),
                        label: Text(context.appText.shareControl))),
              ],
            )),
      ));
}
