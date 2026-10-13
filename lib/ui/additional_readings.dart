import 'reader_sequence.dart';
import '../l10n/app_text.dart';
import '../services/search_normalization.dart';
import '../services/error_reports.dart';
import 'report_error.dart';
import 'hymn_page_turn.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';
import 'package:sdahymnal/ui/fontsize.dart';
import 'package:sdahymnal/ui/kit.dart';

class AdditionalReadingsPage extends StatefulWidget {
  final AdditionalReadingCatalog catalog;

  const AdditionalReadingsPage({super.key, required this.catalog});

  @override
  State<AdditionalReadingsPage> createState() => _AdditionalReadingsPageState();
}

class _AdditionalReadingsPageState extends State<AdditionalReadingsPage> {
  String _category = 'ALL';
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['ALL', ...widget.catalog.categories];
    final query = normalizeHymnSearch(_query.text);
    final readings = widget.catalog.readings.where((reading) {
      final categoryMatch = _category == 'ALL' || reading.category == _category;
      final queryMatch = query.isEmpty ||
          normalizeHymnSearch(reading.title).contains(query) ||
          reading.number.toString().contains(query) ||
          normalizeHymnSearch(reading.category).contains(query) ||
          normalizeHymnSearch(reading.scriptureReference ?? '').contains(query);
      return categoryMatch && queryMatch;
    }).toList(growable: false);

    return HymnalPage(
      title: context.appText.additionalReadingsTitle,
      body: Column(
        children: [
          HymnSearchField(
            controller: _query,
            hint: context.appText.searchReadings,
            clearTooltip: context.appText.clearSearch,
            onChanged: (_) => setState(() {}),
            margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(children: [
              for (final category in categories)
                Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterPill(
                      label: category == 'ALL'
                          ? context.appText.allReadings
                          : category,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    )),
            ]),
          ),
          Expanded(
            child: readings.isEmpty
                ? EmptyHint(title: context.appText.noMatchingReadings)
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: readings.length,
                    itemBuilder: (context, index) {
                      final reading = readings[index];
                      return HymnRow(
                        key: ValueKey('reading-row-${reading.id}'),
                        number: '${reading.number}',
                        title: reading.title,
                        subtitle: [
                          reading.category,
                          if (reading.scriptureReference?.isNotEmpty ?? false)
                            reading.scriptureReference!,
                        ].join(' · '),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                            context,
                            slideRoute(AdditionalReadingPage(
                                reading: reading,
                                readings: readings,
                                categoryTitle:
                                    _category == 'ALL' ? null : _category)),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdditionalReadingPage extends StatefulWidget {
  final AdditionalReading reading;
  final List<AdditionalReading> readings;
  final String? categoryTitle;
  final bool previewOnly;
  final ReaderSequence? sequence;

  const AdditionalReadingPage({
    super.key,
    required this.reading,
    this.readings = const [],
    this.categoryTitle,
    this.previewOnly = false,
    this.sequence,
  });

  @override
  State<AdditionalReadingPage> createState() => _AdditionalReadingPageState();
}

class _AdditionalReadingPageState extends State<AdditionalReadingPage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  AnimationController? _autoScroll;
  bool _running = false;

  @override
  void dispose() {
    _autoScroll?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toggleAutoScroll() {
    if (_running) {
      _autoScroll?.stop();
      setState(() => _running = false);
      return;
    }
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final distance = _scroll.position.maxScrollExtent - _scroll.offset;
    final duration = Duration(milliseconds: (distance / 22 * 1000).round());
    _autoScroll?.dispose();
    _autoScroll = AnimationController(vsync: this, duration: duration)
      ..addListener(() {
        if (_scroll.hasClients) {
          _scroll.jumpTo(distance * (_autoScroll?.value ?? 0) +
              (_scroll.position.maxScrollExtent - distance));
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _running = false);
        }
      });
    setState(() => _running = true);
    _autoScroll!.forward();
  }

  AdditionalReading? _adjacent(int direction) {
    final readings = widget.readings;
    final index = readings.indexWhere((item) => item.id == widget.reading.id);
    if (index < 0 || readings.length < 2) return null;
    final target = index + direction;
    if (widget.categoryTitle != null) {
      return readings[target % readings.length];
    }
    return target < 0 || target >= readings.length ? null : readings[target];
  }

  void _move(int direction) {
    if (widget.sequence != null) {
      final page = widget.sequence!.page(direction);
      if (page != null) {
        Navigator.pushReplacement(
            context,
            PageRouteBuilder<void>(
                transitionDuration: Duration.zero,
                pageBuilder: (_, __, ___) => page));
      }
      return;
    }
    final target = _adjacent(direction);
    if (target == null) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => AdditionalReadingPage(
          reading: target,
          readings: widget.readings,
          categoryTitle: widget.categoryTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.previewOnly
      ? _reader(context)
      : HymnPageTurn(
          previewBuilder: (direction) {
            if (widget.sequence != null) {
              return widget.sequence!.page(direction, previewOnly: true);
            }
            final target = _adjacent(direction);
            return target == null
                ? null
                : AdditionalReadingPage(
                    key: const ValueKey('reading-turn-preview'),
                    reading: target,
                    readings: widget.readings,
                    categoryTitle: widget.categoryTitle,
                    previewOnly: true,
                  );
          },
          onTurn: _move,
          child: _reader(context),
        );

  void _report() => Navigator.push(
      context,
      slideRoute(ReportErrorPage(
          subject: ErrorReportSubject(
              kind: 'reading',
              title: widget.reading.title,
              edition: widget.reading.edition,
              number: widget.reading.number,
              itemId: widget.reading.id))));

  void _showOptions() {
    showHymnalSheet<void>(
      context,
      title: context.appText.readingOptions,
      builder: (sheet) => ValueListenableBuilder<bool>(
        valueListenable: AutoScroll.instance,
        builder: (context, autoScroll, _) => Column(children: [
          SettingsRow(
            key: const ValueKey('reading-text-size'),
            leading: const RowIcon(Icons.text_fields),
            title: context.appText.textSize,
            divider: true,
            onTap: () {
              Navigator.pop(sheet);
              Navigator.push(context, slideRoute(const FontSizer()));
            },
          ),
          SettingsSwitchRow(
            key: const ValueKey('reading-auto-scroll'),
            leading: const RowIcon(Icons.vertical_align_bottom),
            title: context.appText.autoScroll,
            value: autoScroll,
            divider: true,
            onChanged: (on) {
              AutoScroll.instance.set(on);
              if (!on && _running) _toggleAutoScroll();
            },
          ),
          SettingsRow(
            key: const ValueKey('reading-report-error'),
            leading: const RowIcon(Icons.flag_outlined),
            title: context.appText.reportErrors,
            onTap: () {
              Navigator.pop(sheet);
              _report();
            },
          ),
        ]),
      ),
    );
  }

  Widget _reader(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      // Same keyboard paging as the hymn reader.
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        },
        child: Focus(
          autofocus: !widget.previewOnly,
          child: SafeArea(
            child: Column(
              children: [
                SubPageHeader(
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.reading.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: trackingEm(0.14, 10),
                          color: t.muted,
                        )),
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '${widget.reading.number}  ',
                            style: TextStyle(
                                color: t.accent, fontWeight: FontWeight.w700)),
                        TextSpan(text: widget.reading.title),
                      ]),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        color: t.ink,
                      ),
                    ),
                  ]),
                  trailing: IconButton(
                    key: const ValueKey('reading-options'),
                    tooltip: context.appText.readingOptions,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.more_vert, color: t.ink),
                    onPressed: _showOptions,
                  ),
                ),
                if (widget.categoryTitle != null || widget.sequence != null)
                  Container(
                    key: const ValueKey('reading-category-indicator'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border(bottom: BorderSide(color: t.line2)),
                    ),
                    child: Text(
                      widget.sequence?.labelFor(context) ??
                          context.appText.categoryPosition(
                              widget.categoryTitle!,
                              widget.readings.indexWhere(
                                      (r) => r.id == widget.reading.id) +
                                  1,
                              widget.readings.length),
                      style: TextStyle(
                          fontFamily: kSans, fontSize: 13, color: t.accent),
                    ),
                  ),
                Expanded(
                    child: Stack(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: FontSizeController.instance,
                      builder: (context, fontSize, _) => ListView(
                        key: const ValueKey('additional-reading-scroll'),
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(24, 18, 24, 100),
                        children: [
                          if (widget.reading.scriptureReference?.isNotEmpty ??
                              false)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.menu_book_outlined,
                                    size: 16, color: t.muted),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                      context.appText.readingScripture(
                                          widget.reading.scriptureReference!),
                                      style: TextStyle(
                                          fontFamily: kSans,
                                          fontSize: 12.5,
                                          color: t.muted)),
                                ),
                              ],
                            ),
                          const SizedBox(height: 18),
                          ...widget.reading.segments.expand((segment) => [
                                Text(segment.text,
                                    style: TextStyle(
                                      fontFamily: kSerif,
                                      fontSize: fontSize,
                                      height: 1.6,
                                      fontWeight: segment.isCongregation
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontStyle: segment.isCongregation
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                      color: t.ink,
                                    )),
                                SizedBox(height: fontSize * 1.1),
                              ]),
                        ],
                      ),
                    ),
                    // Auto-scroll is opt-in, as in the hymn reader.
                    ValueListenableBuilder<bool>(
                      valueListenable: AutoScroll.instance,
                      builder: (context, enabled, _) => !enabled
                          ? const SizedBox.shrink()
                          : Positioned(
                              right: 20,
                              bottom: 20,
                              child: FloatingActionButton.extended(
                                heroTag: widget.previewOnly
                                    ? null
                                    : 'reading-auto-scroll',
                                onPressed: _toggleAutoScroll,
                                icon: Icon(
                                    _running ? Icons.pause : Icons.play_arrow),
                                label: Text(_running
                                    ? context.appText.pauseReading
                                    : context.appText.startAutoScroll),
                              ),
                            ),
                    ),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
