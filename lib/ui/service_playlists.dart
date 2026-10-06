import 'dart:math';
import 'package:flutter/material.dart';
import '../models/hymn_ref.dart';
import '../models/service_playlist.dart';
import '../services/hymnal_repository.dart';
import '../services/search_normalization.dart';
import '../services/service_playlists.dart';
import 'service_reader.dart';

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
      MaterialPageRoute<void>(
          builder: (_) => _ServiceEditor(
              id: playlist.id, store: store, repository: widget.repository)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Service playlists')),
        body: FutureBuilder<void>(
            future: loaded,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return AnimatedBuilder(
                  animation: store,
                  builder: (context, _) => Column(children: [
                        if (store.storageError) _StorageNotice(store: store),
                        Expanded(
                            child: store.playlists.isEmpty
                                ? const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                            'Arrange hymns and readings for a service. You can use a hymn more than once.',
                                            textAlign: TextAlign.center)))
                                : ListView(children: [
                                    for (final list in store.playlists)
                                      ListTile(
                                          title: Text(list.name),
                                          subtitle: Text(
                                              '${list.entries.length} items'),
                                          onTap: () => _open(list),
                                          trailing: PopupMenuButton<String>(
                                              enabled: !store.storageError,
                                              onSelected: (action) async {
                                                if (action == 'rename') {
                                                  await _name(playlist: list);
                                                  return;
                                                }
                                                final confirmed = await showDialog<
                                                        bool>(
                                                    context: context,
                                                    builder: (context) =>
                                                        AlertDialog(
                                                            title: Text(
                                                                'Delete “${list.name}”?'),
                                                            content: const Text(
                                                                'Your hymns and favorites will stay saved.'),
                                                            actions: [
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context,
                                                                          false),
                                                                  child: const Text(
                                                                      'Cancel')),
                                                              TextButton(
                                                                  onPressed: () =>
                                                                      Navigator.pop(
                                                                          context,
                                                                          true),
                                                                  child: const Text(
                                                                      'Delete'))
                                                            ]));
                                                if (confirmed == true) {
                                                  try {
                                                    await store.delete(list.id);
                                                  } catch (_) {
                                                    if (context.mounted) {
                                                      _error(context);
                                                    }
                                                  }
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                    PopupMenuItem(
                                                        value: 'rename',
                                                        child: Text('Rename')),
                                                    PopupMenuItem(
                                                        value: 'delete',
                                                        child: Text('Delete'))
                                                  ]))
                                  ])),
                        SafeArea(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: FilledButton.icon(
                                    onPressed: store.storageError
                                        ? null
                                        : () => _name(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('New service')))),
                      ]));
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
      setState(() => error = 'Use 1–60 characters.');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.name == null ? 'New service' : 'Rename service'),
          content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                  labelText: 'Service name',
                  hintText: 'Sabbath worship',
                  errorText: error),
              onSubmitted: (_) => save()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            TextButton(onPressed: save, child: const Text('Save'))
          ]);
}

void _error(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('The service could not be saved. Please try again.')));

class _StorageNotice extends StatelessWidget {
  final ServicePlaylists store;
  const _StorageNotice({required this.store});
  @override
  Widget build(BuildContext context) => ListTile(
      title: const Text('Saved services could not be read or updated.'),
      subtitle: const Text('Editing is paused to protect your saved data.'),
      trailing: TextButton(onPressed: store.load, child: const Text('Retry')));
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
          return Scaffold(
              appBar: AppBar(title: const Text('Service unavailable')));
        }
        final list = matches.first;
        return Scaffold(
            appBar: AppBar(title: Text(list.name)),
            body: Column(children: [
              if (store.storageError) _StorageNotice(store: store),
              Expanded(
                  child: list.entries.isEmpty
                      ? const Center(
                          child:
                              Text('Add hymns and readings in service order.'))
                      : ReorderableListView.builder(
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
                                'Unavailable item';
                            final book = repository
                                    .edition(entry.ref.bookId)
                                    ?.displayName ??
                                entry.ref.bookId;
                            return ListTile(
                                key: ValueKey(entry.id),
                                leading: Text('${index + 1}'),
                                title: Text(title),
                                subtitle: Text(
                                    '$book · ${hymn?.number ?? reading?.number ?? entry.ref.itemId}'),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => ServiceReader(
                                                playlist: list,
                                                repository: repository)
                                            .page(index)!)),
                                trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PopupMenuButton<String>(
                                          enabled: !store.storageError,
                                          onSelected: (action) => _edit(
                                              context,
                                              (s) => action == 'repeat'
                                                  ? s.appended(ServiceEntry(
                                                      id: _id(),
                                                      ref: entry.ref))
                                                  : s.without(entry.id)),
                                          itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                    value: 'repeat',
                                                    child:
                                                        Text('Repeat at end')),
                                                PopupMenuItem(
                                                    value: 'remove',
                                                    child: Text('Remove'))
                                              ]),
                                      if (!store.storageError)
                                        ReorderableDragStartListener(
                                            index: index,
                                            child: const Padding(
                                                padding: EdgeInsets.all(8),
                                                child:
                                                    Icon(Icons.drag_handle))),
                                    ]));
                          })),
              SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                          onPressed: store.storageError
                              ? null
                              : () async {
                                  final ref = await Navigator.push<HymnRef>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => _ServicePicker(
                                              repository: repository)));
                                  if (ref != null && context.mounted) {
                                    await _edit(
                                        context,
                                        (s) => s.appended(
                                            ServiceEntry(id: _id(), ref: ref)));
                                  }
                                },
                          icon: const Icon(Icons.add),
                          label: const Text('Add hymn or reading')))),
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
  late final items = [
    for (final edition in widget.repository.editions) ...[
      for (final hymn in widget.repository.hymnsFor(edition.id))
        (
          ref: hymn.ref,
          title: hymn.title,
          number: hymn.number,
          book: edition.displayName
        ),
      for (final reading in widget.repository.readingsFor(edition.id))
        (
          ref: reading.ref,
          title: reading.title,
          number: reading.number,
          book: edition.displayName
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
    return Scaffold(
        appBar: AppBar(title: const Text('Add hymn or reading')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Number or title',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (text) => setState(() => query = text))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                  isExpanded: true,
                  value: bookId ?? '',
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('All hymnals')),
                    for (final edition in widget.repository.editions)
                      DropdownMenuItem(
                          value: edition.id, child: Text(edition.displayName))
                  ],
                  onChanged: (value) =>
                      setState(() => bookId = value == '' ? null : value))),
          Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No matching hymns or readings'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return ListTile(
                            title: Text('${item.number}  ${item.title}'),
                            subtitle: Text(
                                '${item.book}${item.ref.kind == HymnalItemKind.reading ? ' · Reading' : ''}'),
                            onTap: () => Navigator.pop(context, item.ref));
                      })),
        ]));
  }
}
