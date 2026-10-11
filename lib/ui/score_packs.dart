import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_text.dart';
import '../services/installed_score_packs.dart';
import '../services/language_pack_store.dart';
import '../services/score_download_catalog.dart';
import '../services/score_pack_store.dart';

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
    return Scaffold(
        appBar: AppBar(title: Text(text.sheetMusic)),
        body: _downloads == null
            ? Center(
                child: _failed
                    ? TextButton(onPressed: _load, child: Text(text.retry))
                    : const CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text(text.scorePacksHelp),
                const SizedBox(height: 16),
                for (final download in _downloads!)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_names[download.bookId] ?? download.bookId,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(text.scorePackDetails(
                                    download.pages.length,
                                    (download.bytes / (1024 * 1024))
                                        .toStringAsFixed(1))),
                                if (_bundled.contains(download.bookId))
                                  Text(text.packBundled),
                                if (_installed.contains(download.bookId))
                                  Text(text.packInstalled),
                                if (_busy == download.bookId) ...[
                                  LinearProgressIndicator(value: _progress),
                                  if (_cancel != null)
                                    TextButton(
                                        onPressed: () => _cancel?.cancel(),
                                        child: Text(text.cancel)),
                                ] else ...[
                                  if (_updates.contains(download.bookId))
                                    FilledButton(
                                        onPressed: _busy == null
                                            ? () =>
                                                _change(download, remove: false)
                                            : null,
                                        child: Text(text.packUpdate)),
                                  if (_installed.contains(download.bookId))
                                    TextButton(
                                        onPressed: _busy == null
                                            ? () =>
                                                _change(download, remove: true)
                                            : null,
                                        child: Text(text.remove))
                                  else if (!_bundled.contains(download.bookId))
                                    FilledButton(
                                        onPressed: _busy == null
                                            ? () =>
                                                _change(download, remove: false)
                                            : null,
                                        child: Text(text.packDownload)),
                                ],
                              ]))),
              ]));
  }
}
