import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum PageTurnRegion { top, middle, bottom }

PageTurnRegion pageTurnRegion(double y, double height) => y < height * .35
    ? PageTurnRegion.top
    : y >= height * .65
        ? PageTurnRegion.bottom
        : PageTurnRegion.middle;

/// A finger-driven page fold. Preview widgets must have no playback/history
/// side effects; only a completed turn opens the adjacent reader.
class HymnPageTurn extends StatefulWidget {
  const HymnPageTurn(
      {super.key,
      required this.child,
      required this.previewBuilder,
      required this.onTurn});
  final Widget child;
  final Widget? Function(int direction) previewBuilder;
  final ValueChanged<int> onTurn;

  @override
  State<HymnPageTurn> createState() => _HymnPageTurnState();
}

class _HymnPageTurnState extends State<HymnPageTurn>
    with SingleTickerProviderStateMixin {
  late final _turn =
      AnimationController(vsync: this, lowerBound: -1, upperBound: 1, value: 0);
  final Map<int, Widget?> _previews = {};
  bool _settling = false;
  bool _pointerCancelled = false;
  double _drag = 0;
  int? _activeDirection;
  PageTurnRegion _region = PageTurnRegion.bottom;
  Offset _touchOrigin = Offset.zero;
  ui.Image? _logo;
  String? _logoAsset;
  // Two small decoded textures shared by all readers, not decoded per drag.
  static final _logos = <String, Future<ui.Image>>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final asset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/brand/wordmark_dark.png'
        : 'assets/brand/wordmark_light.png';
    if (_logoAsset == asset) return;
    _logoAsset = asset;
    _logos.putIfAbsent(asset, () async {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List(),
          targetWidth: 480);
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    }).then((image) {
      if (mounted && _logoAsset == asset) setState(() => _logo = image);
    });
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  Widget? _preview(int direction) =>
      _previews.putIfAbsent(direction, () => widget.previewBuilder(direction));

  Future<void> _release(double velocity, {bool cancel = false}) async {
    if (_settling || _turn.value == 0) return;
    final sign = _turn.value.sign;
    final forwardFling = velocity * sign > 500 && _turn.value.abs() > .04;
    final reverseFling = velocity * sign < -500;
    final commit =
        !cancel && !reverseFling && (_turn.value.abs() >= .16 || forwardFling);
    _settling = true;
    final reduced = MediaQuery.disableAnimationsOf(context);
    try {
      await _turn
          .animateTo(commit ? sign : 0,
              duration: Duration(milliseconds: reduced ? 0 : 220),
              curve: Curves.easeOut)
          .orCancel;
      if (mounted && commit) widget.onTurn(sign < 0 ? 1 : -1);
      if (mounted && !commit) setState(() => _activeDirection = null);
    } on TickerCanceled {
      // The reader was closed while settling.
    } finally {
      _settling = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        return Listener(
          onPointerDown: (event) => _touchOrigin = event.localPosition,
          onPointerCancel: (_) => _pointerCancelled = true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) {
              if (_settling) return;
              _region = pageTurnRegion(_touchOrigin.dy, constraints.maxHeight);
              _pointerCancelled = false;
              _drag = 0;
              _previews.clear();
            },
            onHorizontalDragUpdate: (details) {
              if (_settling) return;
              _drag = (_drag + details.delta.dx / constraints.maxWidth)
                  .clamp(-1, 1);
              final dir = _drag < 0 ? 1 : -1;
              final preview = _preview(dir);
              if (preview != null && _activeDirection != dir) {
                setState(() => _activeDirection = dir);
              }
              _turn.value = preview == null ? 0 : _drag;
            },
            onHorizontalDragEnd: (details) {
              // Flutter may report an accepted drag's pointer cancellation as
              // drag-end. Wait until raw pointer dispatch has recorded it.
              Future.microtask(() {
                if (mounted) {
                  _release(details.primaryVelocity ?? 0,
                      cancel: _pointerCancelled);
                }
              });
            },
            onHorizontalDragCancel: () => _release(0, cancel: true),
            child: ClipRect(
              child: Stack(fit: StackFit.expand, children: [
                if (_activeDirection != null)
                  Positioned.fill(
                      child: IgnorePointer(
                          child: ExcludeFocus(
                    child: ExcludeSemantics(
                        child: TickerMode(
                      enabled: false,
                      child:
                          RepaintBoundary(child: _preview(_activeDirection!)!),
                    )),
                  ))),
                ClipPath(
                  key: const ValueKey('hymn-page-fold'),
                  clipper:
                      PageCurlClipper(_turn, reduced: reduced, region: _region),
                  child: RepaintBoundary(child: widget.child),
                ),
                IgnorePointer(
                    child: CustomPaint(
                  painter: PageCurlPainter(_turn,
                      paper: Theme.of(context).scaffoldBackgroundColor,
                      reduced: reduced,
                      region: _region,
                      logo: _logo),
                  isComplex: false,
                  willChange: true,
                )),
              ]),
            ),
          ),
        );
      });
}

/// Shared geometry keeps the retained reader layer and the paper underside
/// joined at the same curved edge. All coordinates are logical pixels.
class PageCurlGeometry {
  PageCurlGeometry(Size size, double progress, {bool middle = false}) {
    final p = progress.clamp(0.0, 1.0);
    // A sheet reflects across a diagonal crease, rather than stretching into
    // a ribbon. Start at the lower outer corner and sweep across the page.
    normal =
        middle ? const Offset(1, 0) : const Offset(.9396926208, .3420201433);
    final farCorner = normal.dx * size.width + normal.dy * size.height;
    final distance = farCorner * (1 - p) - size.width * .08 * p;
    creasePoint = normal * distance;
    radius = math.min(size.width * .10, farCorner * p * .22) *
        math.sin(math.pi * p).clamp(.15, 1);
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      Offset(0, size.height)
    ];
    double signed(Offset point) =>
        point.dx * normal.dx + point.dy * normal.dy - distance;
    List<Offset> clip(bool inside) {
      final result = <Offset>[];
      for (var i = 0; i < corners.length; i++) {
        final a = corners[i];
        final b = corners[(i + 1) % corners.length];
        final da = signed(a), db = signed(b);
        final keepA = inside ? da <= 0 : da >= 0;
        final keepB = inside ? db <= 0 : db >= 0;
        if (keepA) result.add(a);
        if (keepA != keepB) result.add(Offset.lerp(a, b, da / (da - db))!);
      }
      return result;
    }

    final flat = clip(true);
    front = Path();
    if (flat.isNotEmpty) front.addPolygon(flat, true);
    final lifted = clip(false);
    final reflected =
        lifted.map((point) => point - normal * (2 * signed(point))).toList();
    underside = Path();
    if (reflected.length >= 3) {
      // Slightly soften the free paper corner; leave the crease endpoints
      // exact so the painted sheet and clipped live page cannot separate.
      for (var i = 0; i < reflected.length; i++) {
        final point = reflected[i];
        final before = reflected[(i + reflected.length - 1) % reflected.length];
        final after = reflected[(i + 1) % reflected.length];
        final onCrease = signed(lifted[i]).abs() < .01;
        final round = onCrease
            ? 0.0
            : math.min(
                9.0,
                math.min((point - before).distance, (after - point).distance) *
                    .12);
        final entry = Offset.lerp(
            point, before, round / math.max(1, (point - before).distance))!;
        final exit = Offset.lerp(
            point, after, round / math.max(1, (after - point).distance))!;
        if (i == 0) {
          underside.moveTo(entry.dx, entry.dy);
        } else {
          underside.lineTo(entry.dx, entry.dy);
        }
        underside.quadraticBezierTo(point.dx, point.dy, exit.dx, exit.dy);
      }
      underside.close();
    }
    if (middle) {
      final edge = distance;
      final freeEdge = 2 * distance - size.width;
      underside.reset();
      underside
        ..moveTo(edge, 0)
        ..lineTo(edge, size.height)
        ..lineTo(freeEdge, size.height)
        ..cubicTo(freeEdge - radius * .7, size.height * .75,
            freeEdge - radius * .7, size.height * .25, freeEdge, 0)
        ..close();
    }
    final intersections =
        lifted.where((point) => signed(point).abs() < .01).toList();
    crease = Path();
    if (intersections.length >= 2) {
      crease.moveTo(intersections.first.dx, intersections.first.dy);
      crease.lineTo(intersections.last.dx, intersections.last.dy);
    }
  }
  late final Path front, underside, crease;
  late final Offset normal, creasePoint;
  late final double radius;
}

class PageCurlClipper extends CustomClipper<Path> {
  PageCurlClipper(this.turn,
      {this.reduced = false, this.region = PageTurnRegion.bottom})
      : super(reclip: turn);
  final PageTurnRegion region;
  final Animation<double> turn;
  final bool reduced;
  @override
  Path getClip(Size size) {
    final progress = turn.value.abs();
    if (progress == 0) return Path()..addRect(Offset.zero & size);
    if (progress >= 1) return Path();
    final path = reduced
        ? (Path()
          ..addRect(
              Rect.fromLTWH(0, 0, size.width * (1 - progress), size.height)))
        : PageCurlGeometry(size, progress,
                middle: region == PageTurnRegion.middle)
            .front;
    final transform = Matrix4.identity();
    if (turn.value > 0) {
      transform.translateByDouble(size.width, 0, 0, 1);
      transform.scaleByDouble(-1, 1, 1, 1);
    }
    if (region == PageTurnRegion.top && !reduced) {
      transform.translateByDouble(0, size.height, 0, 1);
      transform.scaleByDouble(1, -1, 1, 1);
    }
    return path.transform(transform.storage);
  }

  @override
  bool shouldReclip(PageCurlClipper old) =>
      old.turn != turn || old.reduced != reduced || old.region != region;
}

class PageCurlPainter extends CustomPainter {
  PageCurlPainter(this.turn,
      {required this.paper,
      this.reduced = false,
      this.region = PageTurnRegion.bottom,
      this.logo})
      : super(repaint: turn);
  final Animation<double> turn;
  final Color paper;
  final PageTurnRegion region;
  final ui.Image? logo;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final p = turn.value.abs();
    if (reduced || p <= 0 || p >= 1) return;
    final curl =
        PageCurlGeometry(size, p, middle: region == PageTurnRegion.middle);
    canvas.save();
    if (turn.value > 0) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    if (region == PageTurnRegion.top) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    // Soft lift shadow from the free corner, plus a narrow contact shadow
    // on the revealed page. Neither needs an offscreen saveLayer or bitmap.
    canvas.save();
    canvas.translate(curl.normal.dx * 5, curl.normal.dy * 5);
    canvas.drawPath(
        curl.underside,
        Paint()
          ..color = Colors.black.withValues(alpha: .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(
        curl.crease,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = Colors.black.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.restore();
    final light = Color.lerp(paper, Colors.white, .20)!;
    final mid = Color.lerp(paper, Colors.black, .10)!;
    final shade = Color.lerp(paper, Colors.black, .34)!;
    // Lighting runs perpendicular to the crease. Most of the broad flap
    // remains paper-white; the darker roll is confined to its curved edge.
    canvas.drawPath(
        curl.underside,
        Paint()
          ..shader = ui.Gradient.linear(
            curl.creasePoint - curl.normal * math.max(1, curl.radius * 2.4),
            curl.creasePoint,
            [paper, light, mid, shade],
            const [0, .32, .78, 1],
          ));
    if (logo != null) {
      final width = math.min(150.0, size.width * .38);
      final height = width * logo!.height / logo!.width;
      final origin = Offset(
          size.width - width / 2 - 14,
          region == PageTurnRegion.middle
              ? size.height / 2
              : size.height - height / 2 - 20);
      final signedDistance = (origin - curl.creasePoint).dx * curl.normal.dx +
          (origin - curl.creasePoint).dy * curl.normal.dy;
      final center = origin - curl.normal * (2 * signedDistance);
      canvas.save();
      canvas.clipPath(curl.underside);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(2 * math.atan2(curl.normal.dy, curl.normal.dx));
      // Keep the full wordmark readable on the reverse of the turning page.
      canvas.scale(
          turn.value > 0 ? -1 : 1, region == PageTurnRegion.top ? -1 : 1);
      canvas.drawImageRect(
          logo!,
          Rect.fromLTWH(0, 0, logo!.width.toDouble(), logo!.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          Paint()..filterQuality = FilterQuality.low);
      canvas.restore();
    }
    canvas.drawPath(
        curl.crease,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65
          ..color = Colors.black.withValues(alpha: .15));
    canvas.restore();
  }

  @override
  bool shouldRepaint(PageCurlPainter old) =>
      old.turn != turn ||
      old.paper != paper ||
      old.reduced != reduced ||
      old.region != region ||
      old.logo != logo;
}
