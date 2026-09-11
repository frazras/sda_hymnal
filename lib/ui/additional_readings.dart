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
                              reading: reading, readings: readings)),
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

  const AdditionalReadingPage({
    super.key,
    required this.reading,
    this.readings = const [],
  });

  @override
  State<AdditionalReadingPage> createState() => _AdditionalReadingPageState();
}

class _AdditionalReadingPageState extends State<AdditionalReadingPage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  AnimationController? _autoScroll;
  bool _running = false;
  double _dragDx = 0;

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

  void _move(int direction) {
    final readings = widget.readings;
    final index = readings.indexWhere((item) => item.id == widget.reading.id);
    final targetIndex = index + direction;
    if (index < 0 || targetIndex < 0 || targetIndex >= readings.length) return;
    Navigator.pushReplacement(
      context,
      slideRoute(
        AdditionalReadingPage(
          reading: readings[targetIndex],
          readings: readings,
        ),
        fromLeft: direction < 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.reading.number}  ${widget.reading.title}'),
        leading: IconButton(
          icon: HymnalIcons.backChevron(t.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
            onHorizontalDragEnd: (_) {
              if (_dragDx > 40) {
                _move(-1);
              } else if (_dragDx < -40) {
                _move(1);
              }
            },
            child: ListView(
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
                if (widget.reading.scriptureReference?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 18, color: t.muted),
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
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Align(
              alignment: Alignment.centerRight,
              child: FloatingActionButton.extended(
                onPressed: _toggleAutoScroll,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                label: Text(_running ? 'Pause reading' : 'Start auto-scroll'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
