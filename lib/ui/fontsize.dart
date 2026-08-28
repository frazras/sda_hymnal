import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import 'package:sdahymnal/services/prefs.dart';
import 'package:sdahymnal/theme.dart';
import 'package:sdahymnal/ui/common.dart';

/// Sample hymn markup for the live preview — verse 1 + chorus of
/// "All Creatures of Our God and King", copied verbatim from the mockup's
/// `sample` property (same `<font>` marker format as hymns.json bodies).
const String _sample = '<font color="#0B6138"><b>1</b></font><br>\n'
    'All creatures of our God and King,<br>\n'
    'Lift up your voice with us and sing:<br>\n'
    'Alleluia! Alleluia!<br>\n'
    'O burning sun with golden beam<br>\n'
    'And silver moon with softer gleam:<br>\n'
    '<br>\n'
    '<i><b><font color="#CD9B1D">CHORUS:</font></b><br>\n'
    'Oh, praise Him! Oh, praise Him!<br>\n'
    'Alleluia, alleluia, alleluia!<br>\n'
    '</i>';

/// Font Size sub-page: custom 16–30 slider + live hymn-lyrics preview.
/// Pushed with slideRoute() from Settings and from the hymn page "Aa" button.
class FontSizer extends StatelessWidget {
  const FontSizer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SubPageHeader(title: 'Font Size'),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: FontSizeController.instance,
                builder: (context, fontSize, _) {
                  final fs = fontSize.clamp(16.0, 30.0).roundToDouble();
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SliderCard(fs: fs),
                        const SectionLabel('PREVIEW',
                            padding: EdgeInsets.fromLTRB(24, 2, 24, 6)),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 60),
                              child: Html(
                                data: styleHymnBody(_sample, t, fs),
                                style: {
                                  'body': Style(
                                    margin: Margins.zero,
                                    padding: HtmlPaddings.zero,
                                    fontFamily: t.isClassic ? 'Roboto' : kSerif,
                                    fontSize: FontSize(fs),
                                    lineHeight:
                                        LineHeight(t.isClassic ? 1.45 : 1.7),
                                    color: t.ink,
                                  ),
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slider card: "Lyrics size" label + live "{n} pt" value, custom slider,
/// A/A end glyphs. Margin 20, surface, line border, radius 16, card shadow,
/// padding 18/18/8.
class _SliderCard extends StatelessWidget {
  final double fs;

  const _SliderCard({required this.fs});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(16),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Lyrics size',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.muted,
                ),
              ),
              Text(
                '${fs.round()} pt',
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                ),
              ),
            ],
          ),
          _FontSlider(fs: fs),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A',
                  style: TextStyle(
                      fontFamily: kSerif, fontSize: 12, color: t.faint),
                ),
                Text(
                  'A',
                  style: TextStyle(
                      fontFamily: kSerif, fontSize: 19, color: t.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom slider (no Material Slider): 48px hit area with a 13px horizontal
/// inset (half the 26px thumb, so the thumb never overflows the card at the
/// extremes), 4px track, accent fill, white thumb. Tapping anywhere on the
/// hit area jumps the thumb; dragging updates live. Integer steps 16–30,
/// persisted via FontSizeController on every change.
class _FontSlider extends StatelessWidget {
  static const double _inset = 13;
  static const double _thumb = 26;

  final double fs;

  const _FontSlider({required this.fs});

  void _setFromDx(double dx, double trackWidth) {
    final frac = ((dx - _inset) / trackWidth).clamp(0.0, 1.0);
    final next = (16 + frac * 14).roundToDouble();
    if (next != fs) FontSizeController.instance.set(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final frac = ((fs - 16) / 14).clamp(0.0, 1.0);
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth - _inset * 2;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _setFromDx(d.localPosition.dx, trackWidth),
            onHorizontalDragStart: (d) =>
                _setFromDx(d.localPosition.dx, trackWidth),
            onHorizontalDragUpdate: (d) =>
                _setFromDx(d.localPosition.dx, trackWidth),
            child: Stack(
              children: [
                // Track
                Positioned(
                  left: _inset,
                  right: _inset,
                  top: 22,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.surface2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Filled portion
                Positioned(
                  left: _inset,
                  top: 22,
                  height: 4,
                  width: trackWidth * frac,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Thumb — hard-coded white in BOTH themes per spec; its
                // shadow (0 2px 6px rgba(16,21,15,0.18)) is not theme-gated.
                Positioned(
                  left: trackWidth * frac,
                  top: (48 - _thumb) / 2,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: t.line),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2E10150F),
                          offset: Offset(0, 2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
