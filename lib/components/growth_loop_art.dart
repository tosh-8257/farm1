import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Onboarding illustration in brand colours (black, white, grey + the gold
/// accent on the loop arc and the tallest bar):
/// bars that rise one after another inside a slowly turning loop.
/// Drawn locally, no network asset. With reduced motion the loop is still
/// and the bars are shown at full height.
class GrowthLoopArt extends StatefulWidget {
  const GrowthLoopArt({super.key, this.size = 280, this.color});
  final double size;
  final Color? color;

  @override
  State<GrowthLoopArt> createState() => _GrowthLoopArtState();
}

class _GrowthLoopArtState extends State<GrowthLoopArt> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  late final AnimationController _bars = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _loop.stop();
      _bars.stop();
    } else {
      if (!_loop.isAnimating) _loop.repeat();
      if (!_bars.isAnimating) _bars.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.color ?? Theme.of(context).colorScheme.onSurface;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_loop, _bars]),
        builder: (_, __) => CustomPaint(
          painter: GrowthLoopPainter(reduced ? 0 : _loop.value, ink, barsT: reduced ? null : _bars.value),
        ),
      ),
    );
  }
}

class GrowthLoopPainter extends CustomPainter {
  /// [barsT] is the bar-cycle position 0..1; null draws the bars full.
  GrowthLoopPainter(this.t, this.ink, {this.barsT, this.accent = AppTheme.accent});
  final double t;
  final Color ink;
  final Color accent;
  final double? barsT;

  static const grey = Color(0xFF9E9E9E);
  static const lightGrey = Color(0xFFE0E0E0);
  static const bars = 4;

  // Cycle timing: bar i rises during [i*stagger, i*stagger+rise], all hold
  // until holdEnd, then all settle smoothly back to 0 before repeating.
  static const stagger = 0.12, rise = 0.2, holdEnd = 0.82;

  /// Height fraction (0..1) of bar [i] at cycle position [p].
  static double barFraction(int i, double? p) {
    if (p == null) return 1;
    if (p >= holdEnd) {
      final out = ((p - holdEnd) / (1 - holdEnd)).clamp(0.0, 1.0);
      return 1 - Curves.easeInOut.transform(out);
    }
    final start = i * stagger;
    final x = ((p - start) / rise).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(x);
  }

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
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 6);
    final w = r * 0.22, gap = r * 0.12, base = c.dy + r * 0.45;
    final left = c.dx - (bars * w + (bars - 1) * gap) / 2;
    for (var i = 0; i < bars; i++) {
      final h = r * (0.3 + 0.22 * i) * barFraction(i, barsT);
      if (h <= 0.5) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left + i * (w + gap), base - h, w, h), const Radius.circular(4)),
        Paint()..color = i == bars - 1 ? accent : grey,
      );
    }
  }

  /// Every monochrome colour this painter can use, for brand checks.
  List<Color> palette() => [ink, grey, lightGrey];

  /// The only non-grey colour drawn (arc + tallest bar).
  List<Color> accents() => [accent];

  @override
  bool shouldRepaint(GrowthLoopPainter old) => old.t != t || old.ink != ink || old.barsT != barsT || old.accent != accent;
}
