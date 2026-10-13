import 'dart:math';
import '../l10n/app_text.dart';
import 'package:flutter/material.dart';
import '../models/hymn_ref.dart';
import '../models/service_playlist.dart';
import '../services/hymnal_repository.dart';
import '../services/search_normalization.dart';
import '../services/service_playlists.dart';
import 'service_reader.dart';
import 'service_presentation.dart';
import '../services/service_presentation.dart';
import '../models/hymnal_book.dart';
import '../theme.dart';
import 'common.dart';
import 'kit.dart';

String _id() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

class ServicePlaylistsPage extends StatefulWidget {
  final HymnalRepository repository;
  final ServicePlaylists? store;
  const ServicePlaylistsPage({super.key, required this.repository, this.store});
  @override
  State<ServicePlaylistsPage> createState() => _ServicePlaylistsPageState();
}

class _ServicePlaylistsPageState extends State<ServicePlaylistsPage> {
  late final store = widget.store ?? ServicePlaylists.instance;
  late final Future<void> loaded = store.load();

  Future<void> _name({ServicePlaylist? playlist}) async {
    final name = await showDialog<String>(
        context: context, builder: (_) => _NameDialog(name: playlist?.name));
    if (name == null) return;
    try {
      if (playlist == null) {
        final created = ServicePlaylist(id: _id(), name: name);
        await store.create(created);
        if (mounted) _open(created);
      } else {
        await store.update(playlist.id, (s) => s.renamed(name));
      }
    } catch (_) {
      if (mounted) _error(context);
    }
  }

  void _open(ServicePlaylist playlist) => Navigator.push(
      context,
      slideRoute(_ServiceEditor(
          id: playlist.id, store: store, repository: widget.repository)));

  Future<void> _delete(ServicePlaylist list) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.appText.deleteListQuestion(list.name)),
                content: Text(context.appText.serviceDeleteHelp),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.appText.cancel)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.appText.delete))
                ]));
    if (confirmed == true) {
      try {
        await store.delete(list.id);
      } catch (_) {
        if (mounted) _error(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) => HymnalPage(
        title: context.appText.servicePlaylists,
        bottom: AnimatedBuilder(
          animation: store,
          builder: (context, _) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: store.storageError ? null : () => _name(),
                    icon: const Icon(Icons.add),
                    label: Text(context.appText.newService)),
              )),
        ),
        body: FutureBuilder<void>(
            future: loaded,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return AnimatedBuilder(
                  animation: store,
                  builder: (context, _) => ListView(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                        children: [
                          if (store.storageError) _StorageNotice(store: store),
                          if (store.playlists.isEmpty)
                            EmptyHint(
                                title: context.appText.servicePlaylists,
                                message: context.appText.serviceArrangementHelp)
                          else
                            HymnalCard(
                              child: Column(children: [
                                for (final (i, list) in store.playlists.indexed)
                                  SettingsRow(
                                    key: ValueKey('service-${list.id}'),
                                    leading: const RowIcon(
                                        Icons.queue_music_outlined),
                                    title: list.name,
                                    subtitle: context.appText
                                        .serviceItemCount(list.entries.length),
                                    divider: i < store.playlists.length - 1,
                                    chevron: false,
                                    onTap: () => _open(list),
                                    trailing: PopupMenuButton<String>(
                                        enabled: !store.storageError,
                                        onSelected: (action) async {
                                          if (action == 'rename') {
                                            await _name(playlist: list);
                                          } else {
                                            await _delete(list);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                              PopupMenuItem(
                                                  value: 'rename',
                                                  child: Text(
                                                      context.appText.rename)),
                                              PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text(
                                                      context.appText.delete))
                                            ]),
                                  ),
                              ]),
                            ),
                        ],
                      ));
            }),
      );
}

class _NameDialog extends StatefulWidget {
  final String? name;
  const _NameDialog({this.name});
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final controller = TextEditingController(text: widget.name);
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    final name = controller.text.trim();
    if (name.isEmpty || name.length > 60) {
      setState(() => error = context.appText.serviceNameInvalid);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.name == null
              ? context.appText.newService
              : context.appText.renameService),
          content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                  labelText: context.appText.serviceName,
                  hintText: context.appText.serviceNameHint,
                  errorText: error),
              onSubmitted: (_) => save()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.appText.cancel)),
            TextButton(onPressed: save, child: Text(context.appText.save))
          ]);
}

void _error(BuildContext context) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(context.appText.serviceSaveFailed)));

class _StorageNotice extends StatelessWidget {
  final ServicePlaylists store;
  const _StorageNotice({required this.store});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.appText.serviceStorageFailed),
        const SizedBox(height: 6),
        Text(context.appText.serviceEditingPaused),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: store.load,
                child: Text(context.appText.retryLoading))),
      ]));
}

class _ServiceEditor extends StatelessWidget {
  final String id;
  final ServicePlaylists store;
  final HymnalRepository repository;
  const _ServiceEditor(
      {required this.id, required this.store, required this.repository});

  Future<void> _edit(BuildContext context,
      ServicePlaylist Function(ServicePlaylist) change) async {
    try {
      await store.update(id, change);
    } catch (_) {
      if (context.mounted) _error(context);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final matches = store.playlists.where((e) => e.id == id);
        if (matches.isEmpty) {
          return HymnalPage(
              title: context.appText.serviceUnavailable,
              body: const SizedBox.shrink());
        }
        final list = matches.first;
        return HymnalPage(
            title: list.name,
            trailing: HeaderAction(
                icon: Icons.slideshow_outlined,
                tooltip: context.appText.previewPresentation,
                onTap: list.entries.isEmpty
                    ? null
                    : () {
                        try {
                          final presentation =
                              ServicePresentation.build(list, repository);
                          Navigator.push(
                              context,
                              slideRoute(ServicePresentationPage(
                                  presentation: presentation)));
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  context.appText.presentationExportFailed)));
                        }
                      }),
            bottom: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      onPressed: store.storageError
                          ? null
                          : () async {
                              final ref = await Navigator.push<HymnRef>(
                                  context,
                                  slideRoute(
                                      _ServicePicker(repository: repository)));
                              if (ref != null && context.mounted) {
                                await _edit(
                                    context,
                                    (s) => s.appended(
                                        ServiceEntry(id: _id(), ref: ref)));
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: Text(context.appText.addHymnOrReading)),
                )),
            body: Column(children: [
              if (store.storageError) _StorageNotice(store: store),
              Expanded(
                  child: list.entries.isEmpty
                      ? EmptyHint(title: context.appText.serviceOrderHelp)
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.only(top: 6, bottom: 12),
                          buildDefaultDragHandles: false,
                          itemCount: list.entries.length,
                          onReorderItem: (from, to) =>
                              _edit(context, (s) => s.reordered(from, to)),
                          itemBuilder: (context, index) {
                            final entry = list.entries[index];
                            final hymn = repository.hymn(entry.ref);
                            final reading = repository.reading(entry.ref);
                            final title = hymn?.title ??
                                reading?.title ??
                                context.appText.unavailableItem;
                            final edition =
                                repository.edition(entry.ref.bookId);
                            final book = edition == null
                                ? entry.ref.bookId
                                : editionShortLabel(
                                    edition.id, edition.displayName);
                            return Material(
                              key: ValueKey(entry.id),
                              color: context.tokens.bg,
                              child: HymnRow(
                                  number: '${index + 1}',
                                  title: title,
                                  subtitle:
                                      '$book · ${reading == null ? '#' : '${context.appText.reading} '}${hymn?.number ?? reading?.number ?? entry.ref.itemId}',
                                  onTap: () => Navigator.push(
                                      context,
                                      slideRoute(ServiceReader(
                                              playlist: list,
                                              repository: repository)
                                          .page(index)!)),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PopupMenuButton<String>(
                                            enabled: !store.storageError,
                                            icon: Icon(Icons.more_vert,
                                                size: 20,
                                                color: context.tokens.faint),
                                            onSelected: (action) => _edit(
                                                context,
                                                (s) => action == 'repeat'
                                                    ? s.appended(ServiceEntry(
                                                        id: _id(),
                                                        ref: entry.ref))
                                                    : s.without(entry.id)),
                                            itemBuilder: (_) => [
                                                  PopupMenuItem(
                                                      value: 'repeat',
                                                      child: Text(context
                                                          .appText
                                                          .repeatAtEnd)),
                                                  PopupMenuItem(
                                                      value: 'remove',
                                                      child: Text(context
                                                          .appText.remove))
                                                ]),
                                        if (!store.storageError)
                                          ReorderableDragStartListener(
                                              index: index,
                                              child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  child: Icon(Icons.drag_handle,
                                                      color: context
                                                          .tokens.faint))),
                                      ])),
                            );
                          })),
            ]));
      });
}

class _ServicePicker extends StatefulWidget {
  final HymnalRepository repository;
  const _ServicePicker({required this.repository});
  @override
  State<_ServicePicker> createState() => _ServicePickerState();
}

class _ServicePickerState extends State<_ServicePicker> {
  String query = '';
  String? bookId;
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  late final items = [
    for (final edition in widget.repository.editions) ...[
      for (final hymn in widget.repository.hymnsFor(edition.id))
        (
          ref: hymn.ref,
          title: hymn.title,
          number: hymn.number,
          book: editionShortLabel(edition.id, edition.displayName)
        ),
      for (final reading in widget.repository.readingsFor(edition.id))
        (
          ref: reading.ref,
          title: reading.title,
          number: reading.number,
          book: editionShortLabel(edition.id, edition.displayName)
        ),
    ]
  ];
  @override
  Widget build(BuildContext context) {
    final normalized = normalizeHymnSearch(query);
    final matches = items
        .where((e) =>
            (bookId == null || e.ref.bookId == bookId) &&
            (normalized.isEmpty ||
                normalizeHymnSearch('${e.number} ${e.title} ${e.book}')
                    .contains(normalized)))
        .toList();
    final number = int.tryParse(query.trim());
    final results = number == null
        ? matches
        : [
            ...matches.where((item) => item.number == number),
            ...matches.where((item) => item.number != number),
          ];
    return HymnalPage(
        title: context.appText.addHymnOrReading,
        body: Column(children: [
          HymnSearchField(
              controller: _query,
              autofocus: true,
              hint: context.appText.numberOrTitle,
              clearTooltip: context.appText.clearSearch,
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              onChanged: (text) => setState(() => query = text)),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Row(children: [
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: FilterPill(
                      label: context.appText.allHymnals,
                      selected: bookId == null,
                      onTap: () => setState(() => bookId = null)),
                ),
                for (final edition in widget.repository.editions)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterPill(
                        key: ValueKey('service-book-${edition.id}'),
                        label:
                            editionShortLabel(edition.id, edition.displayName),
                        selected: bookId == edition.id,
                        onTap: () => setState(() => bookId = edition.id)),
                  ),
              ])),
          Expanded(
              child: results.isEmpty
                  ? EmptyHint(title: context.appText.noMatchingServiceItems)
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return HymnRow(
                            number: '${item.number}',
                            title: item.title,
                            subtitle:
                                '${item.book}${item.ref.kind == HymnalItemKind.reading ? ' · ${context.appText.reading}' : ''}',
                            onTap: () => Navigator.pop(context, item.ref));
                      })),
        ]));
  }
}
