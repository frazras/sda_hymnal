import 'package:sdahymnal/l10n/app_text.dart';
import 'package:flutter/material.dart';

import '../models/hymn.dart';
import '../models/hymn_sheet_music.dart';
import '../theme.dart';

/// Stays inside the reader so playback, autoplay and category order keep their
/// existing owner. Page buttons avoid competing with a zoomed score's pan.
class HymnSheetMusic extends StatefulWidget {
  final Hymn hymn;
  final VoidCallback onLyrics;

  const HymnSheetMusic({super.key, required this.hymn, required this.onLyrics});

  @override
  State<HymnSheetMusic> createState() => _HymnSheetMusicState();
}

class _HymnSheetMusicState extends State<HymnSheetMusic> {
  final _transform = TransformationController();
  final _viewport = GlobalKey();
  AssetBundle? _bundle;
  Future<HymnSheetMusicCatalog>? _catalog;
  int _page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (bundle != _bundle) {
      _bundle = bundle;
      _load();
    }
  }

  void _load() {
    _catalog = _bundle!
        .loadString('assets/sheet_music/catalog.json')
        .then(HymnSheetMusicCatalog.fromJson);
  }

  @override
  void didUpdateWidget(HymnSheetMusic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hymn.version != widget.hymn.version ||
        oldWidget.hymn.number != widget.hymn.number) {
      _page = 0;
      _resetZoom();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _resetZoom() => _transform.value = Matrix4.identity();

  void _zoom(double factor) {
    final box = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final scene = _transform.toScene(center);
    final scale =
        (_transform.value.getMaxScaleOnAxis() * factor).clamp(1.0, 5.0);
    if (scale == 1) {
      _resetZoom();
    } else {
      _transform.value = Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(
            center.dx - scene.dx * scale, center.dy - scene.dy * scale, 0);
    }
  }

  void _selectPage(int page) {
    _resetZoom();
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(children: [
          Expanded(
            child: Text(context.appText.sheetMusic,
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
          ),
          TextButton.icon(
            key: const ValueKey('score-show-lyrics'),
            onPressed: widget.onLyrics,
            icon: const Icon(Icons.notes),
            label: Text(context.appText.lyrics),
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<HymnSheetMusicCatalog>(
          future: _catalog,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message(context.appText.scoreLoadError, retry: true);
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pages =
                snapshot.data!.forHymn(widget.hymn.version, widget.hymn.number);
            if (pages.isEmpty) {
              return _message(context.appText.scoreUnavailable);
            }
            final page = pages[_page];
            return Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRect(
                    child: InteractiveViewer(
                      key: _viewport,
                      transformationController: _transform,
                      minScale: 1,
                      maxScale: 5,
                      child: SizedBox.expand(
                        child: Image.asset(
                          page.asset,
                          key: ValueKey(page.asset),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          semanticLabel: context.appText.scorePageDescription(
                              widget.hymn.number, _page + 1, pages.length),
                          errorBuilder: (_, __, ___) =>
                              _message(context.appText.scorePageError),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  IconButton(
                    tooltip: context.appText.previousScorePage,
                    onPressed: _page > 0 ? () => _selectPage(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                        context.appText.pageOfTotal(_page + 1, pages.length),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.ink)),
                  ),
                  IconButton(
                    tooltip: context.appText.nextScorePage,
                    onPressed: _page + 1 < pages.length
                        ? () => _selectPage(_page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    tooltip: context.appText.zoomOut,
                    onPressed: () => _zoom(1 / 1.5),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    tooltip: context.appText.zoomIn,
                    onPressed: () => _zoom(1.5),
                    icon: const Icon(Icons.zoom_in),
                  ),
                  IconButton(
                    tooltip: context.appText.fitScore,
                    onPressed: _resetZoom,
                    icon: const Icon(Icons.fit_screen),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(context.appText.printedScoreHelp,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.muted, fontSize: 12)),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _message(String text, {bool retry = false}) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.library_music_outlined, size: 36),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (retry)
              TextButton(
                  onPressed: () => setState(_load),
                  child: Text(context.appText.retry)),
          ]),
        ),
      );
}
