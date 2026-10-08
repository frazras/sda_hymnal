import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../services/prefs.dart';
import 'saved_hymn_notice.dart';

/// Keep the one-tap heart when there are no lists. Once lists exist, save a
/// new favorite immediately, then let the user adjust all memberships.
void saveFavorite(BuildContext context, Hymn hymn) {
  final favorites = Favorites.instance;
  if (favorites.sublists.value.isEmpty) {
    favorites.toggle(hymn);
    return;
  }
  if (!favorites.containsAnywhere(hymn.number, hymn.version)) {
    favorites.toggle(hymn);
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [favorites, favorites.sublists, favorites.storageError]),
          builder: (context, _) => ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const SavedHymnNotice(),
              ListTile(
                title: Text(context.appText.saveToFavorites,
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(hymn.title.trim()),
                trailing: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.appText.done)),
              ),
              CheckboxListTile(
                key: const ValueKey('favorite-parent-checkbox'),
                title: Text(context.appText.favorites),
                subtitle: Text(context.appText.mainFavoritesList),
                value: favorites.contains(hymn.number, hymn.version),
                onChanged: favorites.storageError.value
                    ? null
                    : (_) => favorites.toggle(hymn),
              ),
              for (final list in favorites.sublists.value)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: CheckboxListTile(
                    key: ValueKey('favorite-sublist-checkbox-${list.id}'),
                    title: Text(list.name),
                    value:
                        list.hymns.contains((n: hymn.number, v: hymn.version)),
                    onChanged: favorites.storageError.value
                        ? null
                        : (selected) => favorites.setSublistHymn(
                            list.id, hymn, selected ?? false),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> editFavoriteSublist(BuildContext context,
        {FavoriteSublist? list}) =>
    showDialog<void>(
        context: context, builder: (_) => _SublistNameDialog(list: list));

class _SublistNameDialog extends StatefulWidget {
  const _SublistNameDialog({this.list});
  final FavoriteSublist? list;
  @override
  State<_SublistNameDialog> createState() => _SublistNameDialogState();
}

class _SublistNameDialogState extends State<_SublistNameDialog> {
  late final _controller = TextEditingController(text: widget.list?.name ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final favorites = Favorites.instance;
      if (widget.list == null) {
        await favorites.createSublist(_controller.text);
      } else {
        await favorites.renameSublist(widget.list!.id, _controller.text);
      }
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.message.toString()) {
            'Use a name between 1 and 60 characters.' =>
              context.appText.listNameLengthError,
            'Choose a different list name.' =>
              context.appText.listNameDuplicateError,
            _ => e.message.toString(),
          };
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.list == null
            ? context.appText.newFavoriteCategory
            : context.appText.renameFavoriteCategory),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              labelText: context.appText.categoryName,
              hintText: context.appText.categoryNameExample,
              errorText: _error),
          onSubmitted: (_) => _save(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.appText.cancel)),
          TextButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.list == null
                  ? context.appText.create
                  : context.appText.save)),
        ],
      );
}
