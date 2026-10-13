import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/installed_score_packs.dart';
import '../services/language_pack_store.dart';
import '../services/score_download_catalog.dart';
import '../services/score_pack_store.dart';
import '../theme.dart';
import 'kit.dart';

class ScorePacksPage extends StatefulWidget {
  const ScorePacksPage({super.key, this.store});
  final ScorePackStore? store;
  @override
  State<ScorePacksPage> createState() => _ScorePacksPageState();
}

class _ScorePacksPageState extends State<ScorePacksPage> {
  List<ScorePackDownload>? _downloads;
  final _names = <String, String>{};
  final _bundled = <String>{};
  final _installed = <String>{};
  final _updates = <String>{};
  ScorePackStore? _store;
  LanguagePackCancellation? _cancel;
  String? _busy;
  double? _progress;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bundle = DefaultAssetBundle.of(context);
      final downloads = await loadScorePackDownloads(bundle);
      final metadata = jsonDecode(
              await bundle.loadString('assets/sheet_music/downloads.json'))
          as Map<String, dynamic>;
      final store = widget.store ?? await scorePackStore;
      final installed = <String>{}, updates = <String>{};
      for (final descriptor in downloads) {
        final active = await store.load(descriptor.bookId);
        if (active != null) {
          installed.add(descriptor.bookId);
          if (jsonEncode(active.download.metadata['catalog']) !=
              jsonEncode(descriptor.metadata['catalog'])) {
            updates.add(descriptor.bookId);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _downloads = downloads;
        _store = store;
        _failed = false;
        _names.clear();
        _bundled.clear();
        for (final entry in metadata['books'] as List) {
          _names[entry['bookId'] as String] = entry['displayName'] as String;
          if (entry['bundled'] == true) _bundled.add(entry['bookId'] as String);
        }
        _installed
          ..clear()
          ..addAll(installed);
        _updates
          ..clear()
          ..addAll(updates);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(ScorePackDownload descriptor,
      {required bool remove}) async {
    if (_busy != null) return;
    final cancellation = LanguagePackCancellation();
    setState(() {
      _busy = descriptor.bookId;
      _cancel = remove ? null : cancellation;
      _progress = null;
    });
    try {
      if (remove) {
        await _store!.remove(descriptor.bookId);
      } else {
        await _store!.install(descriptor, cancellation: cancellation,
            onProgress: (received, total) {
          if (mounted) setState(() => _progress = received / total);
        });
      }
      if (mounted) await _load();
    } on LanguagePackCancelled {
      // Atomic activation preserves the previous collection.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.appText.packDownloadFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = null;
          _cancel = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.appText;
    final t = context.tokens;
    final downloads = _downloads;
    if (downloads == null) {
      return HymnalPage(
        title: text.sheetMusic,
        body: _failed
            ? EmptyHint(
                title: text.packDownloadFailed,
                action: TextButton(onPressed: _load, child: Text(text.retry)))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return HymnalPage(
      title: text.sheetMusic,
      body: ListView(
        key: const ValueKey('score-packs'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Text(text.scorePacksHelp,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: 1.4,
                    color: t.muted)),
          ),
          HymnalCard(
            child: Column(children: [
              for (final (i, download) in downloads.indexed)
                _row(download, divider: i < downloads.length - 1),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _row(ScorePackDownload download, {required bool divider}) {
    final text = context.appText;
    final t = context.tokens;
    final id = download.bookId;
    final name = _names[id] ?? id;
    final bundled = _bundled.contains(id);
    final installed = _installed.contains(id);
    final busy = _busy == id;
    Widget trailing;
    if (busy) {
      trailing = BusyAction(
          progress: _progress,
          cancelTooltip: text.cancel,
          onCancel: _cancel == null ? null : () => _cancel?.cancel());
    } else if (_updates.contains(id)) {
      trailing = PillAction(
          label: text.packUpdate,
          onTap: _busy == null ? () => _change(download, remove: false) : null);
    } else if (installed) {
      trailing = TextButton(
          onPressed:
              _busy == null ? () => _change(download, remove: true) : null,
          child: Text(text.remove));
    } else if (bundled) {
      trailing = Icon(Icons.check_circle, size: 20, color: t.accent);
    } else {
      trailing = PillAction(
          label: text.packDownload,
          icon: Icons.download_rounded,
          onTap: _busy == null ? () => _change(download, remove: false) : null);
    }
    return DownloadRow(
      key: ValueKey('score-pack-$id'),
      code: id.split('-')[1].toUpperCase(),
      title: name,
      details: [
        text.scorePackDetails(
            download.pages.length,
            megabytesLabel(
                download.bytes, Localizations.localeOf(context).toString())),
        if (bundled) text.packBundled,
      ].join(' · '),
      active: installed || bundled,
      progress: _progress,
      showProgress: busy && _progress != null,
      divider: divider,
      trailing: trailing,
    );
  }
}
