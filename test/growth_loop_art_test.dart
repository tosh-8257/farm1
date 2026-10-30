import 'package:farm/components/growth_loop_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isGreyscale(Color c) => c.r == c.g && c.g == c.b;

void main() {
  test('onboarding art uses only black/white/grey', () {
    for (final ink in [Colors.black, Colors.white]) {
      for (final c in GrowthLoopPainter(0.3, ink).palette()) {
        expect(_isGreyscale(c), isTrue, reason: '$c');
      }
    }
  });
  testWidgets('renders without network', (t) async {
    await t.pumpWidget(const MaterialApp(home: Center(child: GrowthLoopArt(size: 100))));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(GrowthLoopArt), findsOneWidget);
  });
}
