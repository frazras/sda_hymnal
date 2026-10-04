import 'package:flutter/material.dart';
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

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _text));
      if (mounted) _notice('Lyrics copied');
    } catch (_) {
      if (mounted) _notice('Could not copy lyrics. Please try again.');
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
        _notice('Could not open sharing. You can copy the lyrics instead.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Copy or share lyrics')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DropdownButtonFormField<int>(
              key: const ValueKey('share-lyric-section'),
              initialValue: -1,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Include'),
              items: [
                const DropdownMenuItem(value: -1, child: Text('Full hymn')),
                for (var i = 0; i < _export.sections.length; i++)
                  DropdownMenuItem(
                      value: i,
                      child: Text(_export.sections[i].label,
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
                    label: const Text('Copy')),
                Builder(
                    builder: (buttonContext) => FilledButton.icon(
                        onPressed:
                            _sharing ? null : () => _share(buttonContext),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'))),
              ],
            )),
      ));
}
