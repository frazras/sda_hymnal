import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../l10n/app_text.dart';
import '../models/hymnal_pack.dart';
import '../services/installed_language_packs.dart';
import '../services/language_pack_download.dart';
import '../services/language_pack_store.dart';

typedef PackFetch = Future<Uint8List> Function(LanguagePackDownload descriptor,
    {LanguagePackCancellation? cancellation,
    void Function(int received, int total)? onProgress});

class LanguagePacksPage extends StatefulWidget {
  const LanguagePacksPage(
      {super.key,
      required this.onChanged,
      this.store,
      this.fetch = downloadLanguagePack});
  final Future<void> Function() onChanged;
  final LanguagePackStore? store;
  final PackFetch fetch;

  @override
  State<LanguagePacksPage> createState() => _LanguagePacksPageState();
}

class _LanguagePacksPageState extends State<LanguagePacksPage> {
  List<LanguagePackDownload>? _downloads;
  final _names = <String, String>{};
  final _bundled = <String>{};
  final _installed = <String>{};
  final _updates = <String>{};
  LanguagePackStore? _store;
  LanguagePackCancellation? _cancel;
  String? _busy;
  bool _removing = false;
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
      final downloads = await loadLanguagePackDownloads(bundle);
      final metadata =
          jsonDecode(await bundle.loadString('assets/hymnals/downloads.json'))
              as Map<String, dynamic>;
      final bundled = await loadHymnalPacks(bundle);
      final store = widget.store ?? await languagePackStore;
      final installed = <String>{};
      final updates = <String>{};
      for (final descriptor in downloads) {
        final active = await store.installedDescriptor(descriptor.bookId);
        if (active != null) {
          installed.add(descriptor.bookId);
          if (active.checksum != descriptor.checksum) {
            updates.add(descriptor.bookId);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _downloads = downloads;
        _store = store;
        _names.clear();
        for (final book in metadata['books'] as List) {
          _names[book['bookId'] as String] = book['displayName'] as String;
        }
        _bundled
          ..clear()
          ..addAll(bundled.map((p) => p.edition.id));
        _installed
          ..clear()
          ..addAll(installed);
        _updates
          ..clear()
          ..addAll(updates);
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(LanguagePackDownload descriptor,
      {required bool remove}) async {
    if (_busy != null) return;
    final cancellation = LanguagePackCancellation();
    setState(() {
      _busy = descriptor.bookId;
      _removing = remove;
      _cancel = cancellation;
      _progress = null;
    });
    try {
      if (remove) {
        await _store!.remove(descriptor.bookId);
      } else {
        await _store!.install(descriptor,
            cancellation: cancellation,
            fetch: (download) => widget.fetch(download,
                    cancellation: cancellation, onProgress: (received, total) {
                  if (mounted) setState(() => _progress = received / total);
                }));
      }
      await widget.onChanged();
      if (mounted) await _load();
    } on LanguagePackCancelled {
      // Cancellation leaves the previous active copy unchanged.
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
      appBar: AppBar(title: Text(text.languagePacks)),
      body: _downloads == null
          ? Center(
              child: _failed
                  ? TextButton(onPressed: _load, child: Text(text.retry))
                  : const CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(text.languagePacksHelp),
              const SizedBox(height: 16),
              for (final download in _downloads!)
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_names[download.bookId] ?? download.bookId,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(text.packDetails(
                                  download.hymnCount,
                                  (download.bytes / (1024 * 1024))
                                      .toStringAsFixed(1))),
                              if (_bundled.contains(download.bookId))
                                Text(text.packBundled)
                              else ...[
                                Text(text.packNoMusic),
                                Text(text.packReviewPending),
                              ],
                              if (_installed.contains(download.bookId))
                                Text(text.packInstalled),
                              if (_updates.contains(download.bookId) &&
                                  _busy != download.bookId)
                                FilledButton(
                                    onPressed: _busy == null
                                        ? () => _change(download, remove: false)
                                        : null,
                                    child: Text(text.packUpdate)),
                              if (_busy == download.bookId) ...[
                                LinearProgressIndicator(value: _progress),
                                TextButton(
                                    onPressed: _removing
                                        ? null
                                        : () => _cancel?.cancel(),
                                    child: Text(text.cancel)),
                              ] else if (_installed.contains(download.bookId))
                                TextButton(
                                    onPressed: _busy == null
                                        ? () => _change(download, remove: true)
                                        : null,
                                    child: Text(text.remove))
                              else if (!_bundled.contains(download.bookId))
                                FilledButton(
                                    onPressed: _busy == null
                                        ? () => _change(download, remove: false)
                                        : null,
                                    child: Text(text.packDownload)),
                            ]))),
            ]),
    );
  }
}
