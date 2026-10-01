import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A brief expanding ring, droplets, and heart pop. It never changes the
/// favorite state; the caller owns that, including attention-only nudges.
class FavoriteBurst extends StatefulWidget {
  final bool favorite;
  final Color color;

  const FavoriteBurst({super.key, required this.favorite, required this.color});

  @override
  State<FavoriteBurst> createState() => FavoriteBurstState();
}

class FavoriteBurstState extends State<FavoriteBurst>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  Color _burstColor = Colors.green;

  void play(Color color) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _burstColor = color;
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final progress = _animation.value;
          final active = _animation.isAnimating;
          final pop = active ? math.sin(progress * math.pi) * 0.3 : 0.0;
          return SizedBox(
            width: 24,
            height: 24,
            child: CustomPaint(
              painter: _BurstPainter(active ? progress : 1, _burstColor),
              child: Transform.scale(
                scale: 1 + pop,
                child: Icon(
                  widget.favorite || active
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: active
                      ? Color.lerp(_burstColor, widget.color,
                          Curves.easeIn.transform(progress))
                      : widget.color,
                  size: 24,
                ),
              ),
            ),
          );
        },
      );
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BurstPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final travel = Curves.easeOut.transform(progress);
    final paint = Paint()..color = color.withValues(alpha: 1 - progress);
    if (progress < 0.55) {
      canvas.drawCircle(
        center,
        10 + 18 * travel,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - progress / 0.55),
      );
    }
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < 7; i++) {
      final angle = i * 2 * math.pi / 7 - math.pi / 2;
      for (var j = 0; j < 2; j++) {
        final direction = angle + j * 0.16;
        final radius = 12 + (j == 0 ? 19 : 13) * travel;
        canvas.drawCircle(
          center + Offset(math.cos(direction), math.sin(direction)) * radius,
          (j == 0 ? 2.8 : 1.8) * (1 - progress),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
