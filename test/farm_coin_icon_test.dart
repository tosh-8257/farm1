import 'dart:io';

import 'package:farm/components/farm_coin_icon.dart';
import 'package:farm/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coin mark is a transparent vector, not the brand badge', () {
    final svg = File(FarmCoinIcon.asset).readAsStringSync();
    expect(svg, contains('<svg'));
    expect(svg.toLowerCase(), isNot(contains('ffffff')));
    expect(svg, isNot(contains('rx="22"')));
    final coin = File('assets/images/farm_coin.png').readAsBytesSync();
    final brand = File('assets/images/app_logo.png').readAsBytesSync();
    expect(coin, isNot(equals(brand)));
  });

  testWidgets('the shared coin icon tints and has no badge background', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FarmCoinIcon(size: 26, color: AppTheme.accent)),
    ));
    expect(find.byType(FarmCoinIcon), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('FARM'), findsOneWidget);
  });
}
