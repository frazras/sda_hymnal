import 'package:sdahymnal/l10n/app_text.dart';
import 'package:sdahymnal/l10n/instrument_text.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/services/instrument_catalog.dart';

/// One compact field on the mixer; the two levels live in a scrollable sheet.
class InstrumentPicker extends StatelessWidget {
  const InstrumentPicker(
      {super.key,
      required this.program,
      required this.defaultLabel,
      required this.onChanged,
      this.label});
  final int? program;
  final String defaultLabel;
  final String? label;
  final Future<void> Function(int?) onChanged;

  @override
  Widget build(BuildContext context) => TextButton(
        style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size.fromHeight(48)),
        onPressed: () async {
          final selected = await showModalBottomSheet<int>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SafeArea(
                child: FractionallySizedBox(
                    heightFactor: .72,
                    child: _InstrumentChoices(
                        program: program, defaultLabel: defaultLabel))),
          );
          if (selected == null || !context.mounted) return;
          await onChanged(selected == -1 ? null : selected);
        },
        child: Row(children: [
          Expanded(
              child: Text(
                  [
                    if (label != null) label!,
                    program == null
                        ? defaultLabel
                        : context.appText.instrumentName(program!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          const Icon(Icons.chevron_right, size: 20),
        ]),
      );
}

class _InstrumentChoices extends StatefulWidget {
  const _InstrumentChoices({required this.program, required this.defaultLabel});
  final int? program;
  final String defaultLabel;
  @override
  State<_InstrumentChoices> createState() => _InstrumentChoicesState();
}

class _InstrumentChoicesState extends State<_InstrumentChoices> {
  String? category;
  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          leading: category == null
              ? const Icon(Icons.piano)
              : IconButton(
                  tooltip: context.appText.backToInstrumentFamilies,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => category = null)),
          title: Text(category == null
              ? context.appText.instrumentCategory
              : context.appText.instrumentFamily(category!)),
          trailing: IconButton(
              tooltip: context.appText.close,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context)),
        ),
        Expanded(
            child: ListView(
                key: ValueKey(category ?? 'instrument-families'),
                children: category == null
                    ? [
                        ListTile(
                            title: Text(widget.defaultLabel),
                            trailing: widget.program == null
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(context, -1)),
                        for (final name in instrumentCategories.keys)
                          ListTile(
                              title:
                                  Text(context.appText.instrumentFamily(name)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(() => category = name)),
                      ]
                    : [
                        for (final entry
                            in instrumentCategories[category]!.entries)
                          ListTile(
                              title: Text(
                                  context.appText.instrumentName(entry.key)),
                              subtitle: entry.key == 114
                                  ? Text(context.appText.steelpanRollHelp)
                                  : null,
                              trailing: widget.program == entry.key
                                  ? const Icon(Icons.check)
                                  : null,
                              onTap: () => Navigator.pop(context, entry.key)),
                      ])),
      ]);
}
