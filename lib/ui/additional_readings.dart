import 'reader_sequence.dart';
import '../services/error_reports.dart';
import 'report_error.dart';
import 'hymn_page_turn.dart';
import 'package:flutter/material.dart';
import 'package:sdahymnal/models/additional_reading.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

class AdditionalReadingsPage extends StatefulWidget {
  final AdditionalReadingCatalog catalog;

  const AdditionalReadingsPage({super.key, required this.catalog});

  @override
  State<AdditionalReadingsPage> createState() => _AdditionalReadingsPageState();
}

class _AdditionalReadingsPageState extends State<AdditionalReadingsPage> {
  String _category = 'ALL';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final categories = ['ALL', ...widget.catalog.categories];
    final query = _query.trim().toLowerCase();
    final readings = widget.catalog.readings.where((reading) {
      final categoryMatch = _category == 'ALL' || reading.category == _category;
      final queryMatch = query.isEmpty ||
          reading.title.toLowerCase().contains(query) ||
          reading.number.toString().contains(query) ||
          reading.category.toLowerCase().contains(query) ||
          (reading.scriptureReference ?? '').toLowerCase().contains(query);
      return categoryMatch && queryMatch;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Additional Readings'),
        leading: IconButton(
          icon: HymnalIcons.backChevron(t.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search readings',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: t.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: t.line),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category == 'ALL' ? 'All readings' : category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: readings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final reading = readings[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    title: Text('${reading.number}  ${reading.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text([
                        reading.category,
                        if (reading.scriptureReference?.isNotEmpty ?? false)
                          reading.scriptureReference!,
                      ].join('  •  ')),
                    ),
                    trailing: HymnalIcons.rowChevron(t.muted),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdditionalReadingPage(
                              reading: reading,
                              readings: readings,
                              categoryTitle:
                                  _category == 'ALL' ? null : _category)),
                    ),
                  ),
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

  Widget _reader(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      bottomNavigationBar: widget.sequence == null
          ? null
          : SafeArea(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                  TextButton.icon(
                      onPressed:
                          widget.sequence!.canMove(-1) ? () => _move(-1) : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous')),
                  TextButton.icon(
                      onPressed:
                          widget.sequence!.canMove(1) ? () => _move(1) : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Next')),
                ])),
      appBar: AppBar(
        title: Text('${widget.reading.number}  ${widget.reading.title}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Reading options',
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Text('Report Errors'))
            ],
            onSelected: (_) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ReportErrorPage(
                        subject: ErrorReportSubject(
                            kind: 'reading',
                            title: widget.reading.title,
                            edition: widget.reading.edition,
                            number: widget.reading.number,
                            itemId: widget.reading.id)))),
          )
        ],
        leading: IconButton(
          icon: HymnalIcons.backChevron(t.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (widget.categoryTitle != null || widget.sequence != null)
            Container(
              key: const ValueKey('reading-category-indicator'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(bottom: BorderSide(color: t.line2)),
              ),
              child: Text(
                widget.sequence?.label ??
                    'Category: ${widget.categoryTitle} · ${widget.readings.indexWhere((r) => r.id == widget.reading.id) + 1} of ${widget.readings.length}',
                style:
                    TextStyle(fontFamily: kSans, fontSize: 13, color: t.accent),
              ),
            ),
          Expanded(
              child: Stack(
            children: [
              ListView(
                key: const ValueKey('additional-reading-scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 100),
                children: [
                  Text(widget.reading.category.toUpperCase(),
                      style: TextStyle(
                          color: t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1)),
                  if (widget.reading.scriptureReference?.isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.menu_book_outlined,
                            size: 18, color: t.muted),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                              'Scripture: ${widget.reading.scriptureReference}',
                              style: TextStyle(color: t.muted)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  ...widget.reading.segments.expand((segment) => [
                        Text(segment.text,
                            style: TextStyle(
                              fontFamily: kSerif,
                              fontSize: 19,
                              height: 1.55,
                              fontWeight: segment.isCongregation
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontStyle: segment.isCongregation
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              color: t.ink,
                            )),
                        const SizedBox(height: 24),
                      ]),
                ],
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FloatingActionButton.extended(
                    heroTag: widget.previewOnly ? null : 'reading-auto-scroll',
                    onPressed: _toggleAutoScroll,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    label:
                        Text(_running ? 'Pause reading' : 'Start auto-scroll'),
                  ),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }
}
