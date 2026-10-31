import 'package:farm/components/growth_loop_art.dart';
import 'package:farm/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isGreyscale(Color c) => c.r == c.g && c.g == c.b;

GrowthLoopPainter _painter(WidgetTester t) =>
    t.widget<CustomPaint>(find.descendant(of: find.byType(GrowthLoopArt), matching: find.byType(CustomPaint))).painter!
        as GrowthLoopPainter;

void main() {
  test('onboarding art is monochrome plus only the brand accent', () {
    for (final ink in [Colors.black, Colors.white]) {
      final p = GrowthLoopPainter(0.3, ink);
      for (final c in p.palette()) {
        expect(_isGreyscale(c), isTrue, reason: '$c');
      }
      expect(p.accents(), [AppTheme.accent]);
      expect(AppTheme.accent, kBrandAccent);
    }
  });

  test('bars rise from 0 one after another, hold, then reset smoothly', () {
    double f(int i, double p) => GrowthLoopPainter.barFraction(i, p);
    for (var i = 0; i < GrowthLoopPainter.bars; i++) {
      expect(f(i, 0), 0, reason: 'bar $i starts empty');
      expect(f(i, 0.7), 1, reason: 'bar $i full during hold');
      expect(f(i, 0.999), lessThan(0.01), reason: 'bar $i back to ~0');
    }
    for (final p in [0.1, 0.2, 0.3, 0.4]) {
      for (var i = 1; i < GrowthLoopPainter.bars; i++) {
        expect(f(i - 1, p), greaterThanOrEqualTo(f(i, p)));
      }
    }
    expect(f(0, 0.15), greaterThan(f(3, 0.15)));
    expect(f(3, 0.3), 0, reason: 'last bar waits its turn');
    var prev = 0.0;
    for (var p = 0.0; p <= 0.6; p += 0.02) {
      final v = f(2, p);
      expect(v, greaterThanOrEqualTo(prev));
      prev = v;
    }
    expect(GrowthLoopPainter.barFraction(0, null), 1);
  });

  testWidgets('renders and animates without network', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: GrowthLoopArt(size: 100))));
    final p1 = _painter(t).barsT;
    await t.pump(const Duration(milliseconds: 500));
    final p2 = _painter(t).barsT;
    expect(p1, isNotNull);
    expect(p2, isNot(p1));
  });

  testWidgets('reduced motion shows bars full and stops animating', (t) async {
    await t.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: Center(child: GrowthLoopArt(size: 100))),
    ));
    expect(_painter(t).barsT, isNull);
    expect(t.hasRunningAnimations, isFalse);
  });
}
