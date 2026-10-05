import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sdahymnal/models/hymn.dart';
import 'package:sdahymnal/theme.dart';

/// Visuals recovered from the pre-redesign screens (6a860f7 / 212e3aa).
/// Callbacks belong to the shared screens: no legacy data lookup or player.
class ClassicHeader extends StatelessWidget {
  const ClassicHeader(
      {super.key,
      required this.active,
      required this.onSelect,
      required this.onFavorites});

  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      key: const ValueKey('classic-header'),
      children: [
        // The historical SVG is black/green; keep its white background even
        // when the rest of Classic follows the user's dark-mode preference.
        ColoredBox(
          color: Colors.white,
          child: Row(children: [
            const SizedBox(width: 48),
            Expanded(
                child: InkWell(
              onTap: () => onSelect(0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SvgPicture.asset('assets/logo.svg',
                    height: 72,
                    fit: BoxFit.contain,
                    semanticsLabel: 'Hymnal home'),
              ),
            )),
            IconButton(
                tooltip: 'Favorites',
                onPressed: onFavorites,
                icon: const Icon(Icons.favorite_border, color: Colors.black)),
          ]),
        ),
        Row(children: [
          for (final item in const [
            (0, 'Numbers', Icons.keyboard),
            (1, 'Search', Icons.search),
            (3, 'Settings', Icons.settings),
          ])
            Expanded(
                child: Semantics(
              selected: active == item.$1,
              child: InkWell(
                onTap: () => onSelect(item.$1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                    color: active == item.$1 ? t.ink : Colors.transparent,
                    width: 3,
                  ))),
                  child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        Icon(item.$3, color: t.ink, size: 20),
                        Text(item.$2, style: TextStyle(color: t.ink))
                      ]),
                ),
              ),
            )),
        ]),
        Divider(height: 1, color: t.line2),
      ],
    );
  }
}

class ClassicNumberPad extends StatelessWidget {
  const ClassicNumberPad(
      {super.key,
      required this.display,
      required this.oldTitle,
      required this.newTitle,
      this.readingTitle = '',
      this.readingCategory = '',
      this.newLabel = 'New Hymnal',
      this.oldLabel = 'Old Hymnal',
      this.showOld = true,
      this.hasReadings = true,
      this.occasionsLabel = 'Hymns by occasion',
      required this.fontSize,
      required this.onDigit,
      required this.onClear,
      required this.onBackspace,
      required this.onOld,
      required this.onNew,
      this.onReading,
      this.onOccasions,
      this.onReadings,
      this.discoveryRows});

  final String display, oldTitle, newTitle, readingTitle, readingCategory;
  final String newLabel, oldLabel, occasionsLabel;
  final bool showOld, hasReadings;
  final double fontSize;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear, onBackspace;
  final VoidCallback? onOld, onNew;
  final VoidCallback? onReading;
  final VoidCallback? onOccasions;
  final VoidCallback? onReadings;
  final Widget? discoveryRows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget button(Widget child, VoidCallback? tap, {String? label}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: OutlinedButton(
              onPressed: tap,
              style: OutlinedButton.styleFrom(
                foregroundColor: t.ink,
                disabledForegroundColor: t.faint,
                minimumSize: const Size(0, 58),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                side:
                    BorderSide(color: tap == null ? t.line2 : t.ink, width: 2),
                textStyle:
                    TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
              ),
              child:
                  label == null ? child : Semantics(label: label, child: child),
            ),
          ),
        );
    return SingleChildScrollView(
      key: const ValueKey('classic-number-pad'),
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              display.isEmpty
                  ? (hasReadings
                      ? 'Enter hymn or reading number'
                      : 'Enter hymn number')
                  : display,
              key: const ValueKey('classic-number-display'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: fontSize,
                  color: t.ink,
                  fontWeight: FontWeight.bold),
            )),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9']
        ])
          Row(children: [
            for (final digit in row) button(Text(digit), () => onDigit(digit))
          ]),
        Row(children: [
          button(const Icon(Icons.cancel), onClear, label: 'Clear number'),
          button(const Text('0'), () => onDigit('0')),
          button(const Icon(Icons.backspace), onBackspace,
              label: 'Delete digit'),
        ]),
        Row(children: [
          if (showOld)
            button(
                Text(oldLabel == 'Old Hymnal' ? 'OLD»' : '$oldLabel»'), onOld),
          button(Text(newLabel == 'New Hymnal' ? 'NEW»' : '$newLabel»'), onNew)
        ]),
        if (onReading != null)
          Padding(
            padding: const EdgeInsets.all(5),
            child: OutlinedButton(
              onPressed: onReading,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text('READING: $display  $readingTitle',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(readingCategory, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        if (onOccasions != null || onReadings != null)
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: OutlinedButton.icon(
                    onPressed: onOccasions,
                    icon: const Icon(Icons.library_music_outlined, size: 18),
                    label: Text(occasionsLabel,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              if (hasReadings)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: OutlinedButton.icon(
                      onPressed: onReadings,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Additional readings',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
            ],
          ),
        if (discoveryRows != null) discoveryRows!,
        Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
                '${newLabel == 'New Hymnal' ? 'NEW' : newLabel}: $display $newTitle',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: t.ink))),
        if (showOld)
          Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                  '${oldLabel == 'Old Hymnal' ? 'OLD' : oldLabel}: $display $oldTitle',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: t.ink))),
      ]),
    );
  }
}

class ClassicSearchControls extends StatelessWidget {
  const ClassicSearchControls(
      {super.key,
      required this.controller,
      required this.filter,
      this.filterLabel,
      required this.onQuery,
      required this.onFilter});
  final TextEditingController controller;
  final String filter;
  final ValueChanged<String> onQuery;
  final VoidCallback onFilter;
  final String? filterLabel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          Expanded(
              child: TextField(
            controller: controller,
            onChanged: onQuery,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            cursorColor: Colors.greenAccent,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF222222),
              hintText: 'Search Hymns',
              hintStyle:
                  const TextStyle(color: Color(0xFF00FF00), fontSize: 20),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00FF00)),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )),
          const SizedBox(width: 6),
          Semantics(
              label: 'Hymnal filter: $filter',
              child: ElevatedButton(
                onPressed: onFilter,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8)),
                child: Text('${filterLabel ?? filter}\nHymns',
                    textAlign: TextAlign.center),
              )),
        ]),
      );
}

class ClassicSearchRow extends StatelessWidget {
  const ClassicSearchRow({super.key, required this.hymn, required this.onTap});
  final Hymn hymn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: hymn.version == 'new' ? t.bg : t.surface2,
        shape: RoundedRectangleBorder(side: BorderSide(color: t.ink, width: 2)),
        child: ListTile(
          leading: !hymn.isEnglishEdition
              ? Tooltip(
                  message: hymn.bookLabel, child: const Icon(Icons.menu_book))
              : SvgPicture.asset(
                  hymn.version == 'new'
                      ? 'assets/lettern.svg'
                      : 'assets/lettero.svg',
                  width: 32,
                  semanticsLabel:
                      hymn.version == 'new' ? 'New Hymnal' : 'Old Hymnal'),
          title: Text('${hymn.number}. ${hymn.title}',
              style: TextStyle(fontWeight: FontWeight.bold, color: t.ink)),
          subtitle: hymn.isEnglishEdition ? null : Text(hymn.bookLabel),
          onTap: onTap,
        ),
      ),
    );
  }
}
