import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Onboarding illustration in brand colours only (black, white, grey):
/// rising bars inside a slowly turning loop. Drawn locally, no network asset.
class GrowthLoopArt extends StatefulWidget {
  const GrowthLoopArt({super.key, this.size = 280, this.color});
  final double size;
  final Color? color;

  @override
  State<GrowthLoopArt> createState() => _GrowthLoopArtState();
}

class _GrowthLoopArtState extends State<GrowthLoopArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: GrowthLoopPainter(_c.value, ink)),
      ),
    );
  }
}

class GrowthLoopPainter extends CustomPainter {
  GrowthLoopPainter(this.t, this.ink);
  final double t;
  final Color ink;

  static const grey = Color(0xFF9E9E9E);
  static const lightGrey = Color(0xFFE0E0E0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.42;
    canvas.drawCircle(c, r, Paint()
      ..color = lightGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2 + t * 2 * math.pi, math.pi * 1.2, false,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6);
    const bars = 4;
    final w = r * 0.22, gap = r * 0.12, base = c.dy + r * 0.45;
    final left = c.dx - (bars * w + (bars - 1) * gap) / 2;
    for (var i = 0; i < bars; i++) {
      final grow = 0.85 + 0.15 * math.sin((t + i * 0.15) * 2 * math.pi);
      final h = r * (0.3 + 0.22 * i) * grow;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + i * (w + gap), base - h, w, h), const Radius.circular(4)),
        Paint()..color = i == bars - 1 ? ink : grey,
      );
    }
  }

  /// Every colour this painter can use, for brand checks.
  List<Color> palette() => [ink, grey, lightGrey];

  @override
  bool shouldRepaint(GrowthLoopPainter old) => old.t != t || old.ink != ink;
}
