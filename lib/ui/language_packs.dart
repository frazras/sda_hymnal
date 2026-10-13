import 'dart:convert';
import 'score_packs.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../l10n/app_text.dart';
import '../models/hymnal_pack.dart';
import '../services/installed_language_packs.dart';
import '../services/language_pack_download.dart';
import '../services/language_pack_store.dart';
import '../services/search_normalization.dart';
import '../models/hymnal_book.dart';
import '../theme.dart';
import 'common.dart';
import 'kit.dart';

typedef PackFetch = Future<Uint8List> Function(LanguagePackDownload descriptor,
    {LanguagePackCancellation? cancellation,
    void Function(int received, int total)? onProgress});

class LanguagePacksPage extends StatefulWidget {
  const LanguagePacksPage(
      {super.key,
      required this.onChanged,
      this.onOpen,
      this.store,
      this.fetch = downloadLanguagePack});
  final Future<void> Function() onChanged;

  /// Switches the app to a book. When set, a finished download offers
  /// Open, which closes this page and shows the new book.
  final ValueChanged<String>? onOpen;
  final LanguagePackStore? store;
  final PackFetch fetch;

  @override
  State<LanguagePacksPage> createState() => _LanguagePacksPageState();
}

class _LanguagePacksPageState extends State<LanguagePacksPage> {
  List<LanguagePackDownload>? _downloads;
  final _names = <String, String>{};
  final _tags = <String, String>{};
  final _partial = <String>{};
  final _bundled = <String>{};
  final _installed = <String>{};
  // Rows keep the group they opened in, so a download never moves its row
  // out of view; the groups refresh when the page is next opened.
  final _grouped = <String>{};
  bool _groupedOnce = false;
  // Notices belong to this page and close with it.
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _updates = <String>{};
  LanguagePackStore? _store;
  LanguagePackCancellation? _cancel;
  String? _busy;
  bool _removing = false;
  double? _progress;
  bool _failed = false;
  bool _started = false;
  final _search = TextEditingController();
  String _query = '';

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
        _tags.clear();
        _partial.clear();
        for (final book in metadata['books'] as List) {
          final id = book['bookId'] as String;
          _names[id] = book['displayName'] as String;
          _tags[id] = book['languageTag'] as String? ?? '';
          final coverage = book['coverage'];
          if (coverage is Map && coverage['structurallyComplete'] == false) {
            _partial.add(id);
          }
        }
        _bundled
          ..clear()
          ..addAll(bundled.map((p) => p.edition.id));
        _installed
          ..clear()
          ..addAll(installed);
        if (!_groupedOnce) {
          _groupedOnce = true;
          _grouped.addAll(installed);
        }
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
    final id = descriptor.bookId;
    final added = !remove && !_installed.contains(id);
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
      if (added && mounted) _announceReady(id);
    } on LanguagePackCancelled {
      // Cancellation leaves the previous active copy unchanged.
    } catch (_) {
      if (mounted) {
        _messenger.currentState?.showSnackBar(
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

  /// Confirms a new book and, where the caller can switch books, opens it.
  void _announceReady(String id) {
    final text = context.appText;
    final open = widget.onOpen;
    _messenger.currentState?.showSnackBar(SnackBar(
      key: const ValueKey('pack-ready'),
      content: Text(text.packReady(_names[id] ?? id)),
      action: open == null
          ? null
          : SnackBarAction(
              key: const ValueKey('pack-open'),
              label: text.openAction,
              onPressed: () {
                Navigator.of(context).maybePop();
                open(id);
              }),
    ));
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Every query word must start a word of the book's native language name,
  /// title, language code or English language name.
  bool _matches(LanguagePackDownload download) {
    final words = normalizeHymnSearch(_query).split(' ');
    if (words.first.isEmpty) return true;
    final id = download.bookId;
    final tag = _tags[id] ?? '';
    final name = _names[id] ?? id;
    final language = tag.split('-').first.toLowerCase();
    final known = normalizeHymnSearch([
      name,
      languageNameFor(tag, name),
      language,
      languageSearchAliases[language] ?? '',
    ].join(' '))
        .split(' ');
    return words.every((word) => known.any((k) => k.startsWith(word)));
  }

  @override
  Widget build(BuildContext context) =>
      ScaffoldMessenger(key: _messenger, child: _page(context));

  Widget _page(BuildContext context) {
    final text = context.appText;
    final t = context.tokens;
    final downloads = _downloads;
    if (downloads == null) {
      return HymnalPage(
        title: text.languagePacks,
        body: _failed
            ? EmptyHint(
                title: text.packDownloadFailed,
                action: TextButton(onPressed: _load, child: Text(text.retry)))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final searching = _query.trim().isNotEmpty;
    final shown = downloads.where(_matches).toList();
    final optional = shown.where((d) => !_bundled.contains(d.bookId)).toList();
    final installed =
        optional.where((d) => _grouped.contains(d.bookId)).toList();
    final available =
        optional.where((d) => !_grouped.contains(d.bookId)).toList();
    final included = shown.where((d) => _bundled.contains(d.bookId)).toList();
    Widget group(String label, List<LanguagePackDownload> books) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionLabel(label.toUpperCase(), padding: sectionPadding()),
            HymnalCard(
              child: Column(children: [
                for (final (i, book) in books.indexed)
                  _row(book, divider: i < books.length - 1),
              ]),
            ),
          ],
        );
    return HymnalPage(
      title: text.languagePacks,
      body: ListView(
        key: const ValueKey('language-packs'),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Text(text.languagePacksHelp,
                style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: 1.4,
                    color: t.muted)),
          ),
          HymnSearchField(
            key: const ValueKey('language-packs-search'),
            controller: _search,
            hint: text.searchLanguages,
            clearTooltip: text.clearSearch,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (!searching)
            HymnalCard(
              child: SettingsRow(
                key: const ValueKey('score-packs-link'),
                leading: const RowIcon(Icons.library_music_outlined),
                title: text.sheetMusic,
                subtitle: text.scorePacksHelp,
                onTap: () =>
                    Navigator.push(context, slideRoute(const ScorePacksPage())),
              ),
            ),
          if (installed.isNotEmpty) group(text.packInstalled, installed),
          if (available.isNotEmpty) group(text.packAvailableSection, available),
          if (included.isNotEmpty) group(text.packBundled, included),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyHint(
                  key: const ValueKey('language-packs-empty'),
                  title: text.noResults),
            ),
        ],
      ),
    );
  }

  Widget _row(LanguagePackDownload download, {required bool divider}) {
    final text = context.appText;
    final t = context.tokens;
    final id = download.bookId;
    final name = _names[id] ?? id;
    final bundled = _bundled.contains(id);
    final installed = _installed.contains(id);
    final busy = _busy == id;
    final details = [
      editionShortLabel(id, name),
      text.packDetails(
          download.hymnCount,
          megabytesLabel(
              download.bytes, Localizations.localeOf(context).toString())),
      if (_partial.contains(id)) text.packPartial,
      if (!bundled) text.packWordsOnly,
    ].join(' · ');
    Widget trailing;
    if (busy) {
      trailing = BusyAction(
          key: ValueKey('pack-cancel-$id'),
          progress: _progress,
          cancelTooltip: text.cancel,
          onCancel: _removing ? null : () => _cancel?.cancel());
    } else if (_updates.contains(id)) {
      trailing = PillAction(
          key: ValueKey('pack-update-$id'),
          label: text.packUpdate,
          onTap: _busy == null ? () => _change(download, remove: false) : null);
    } else if (installed) {
      trailing = TextButton(
          key: ValueKey('pack-remove-$id'),
          onPressed:
              _busy == null ? () => _change(download, remove: true) : null,
          child: Text(text.remove));
    } else if (bundled) {
      trailing = Icon(Icons.check_circle, size: 20, color: t.accent);
    } else {
      trailing = PillAction(
          key: ValueKey('pack-download-$id'),
          label: text.packDownload,
          icon: Icons.download_rounded,
          onTap: _busy == null ? () => _change(download, remove: false) : null);
    }
    return DownloadRow(
      key: ValueKey('pack-$id'),
      code: id.split('-')[1].toUpperCase(),
      title: languageNameFor(_tags[id] ?? '', name),
      details: details,
      active: installed || bundled,
      progress: _progress,
      showProgress: busy && !_removing && _progress != null,
      divider: divider,
      trailing: trailing,
    );
  }
}
