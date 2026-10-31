import 'dart:io';

import 'package:farm/components/quick_action/quick_action_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuickActionWidget onTap overrides route navigation', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuickActionWidget(
          label: 'Mkulima',
          icon: const Icon(Icons.smart_toy_outlined),
          onTap: () => tapped++,
        ),
      ),
    ));
    await tester.tap(find.text('Mkulima'));
    expect(tapped, 1);
  });

  test('dashboard has Mkulima action after Send and a single Scan QR entry', () {
    final src = File('lib/pages/dashboard/dashboard_widget.dart').readAsStringSync();
    final send = src.indexOf("label: 'Send'");
    final mkulima = src.indexOf("label: 'Mkulima'");
    expect(send, greaterThan(0));
    expect(mkulima, greaterThan(send));
    expect(src.contains('const MkulimaHubPage()'), isTrue);
    expect("navigate:\${QRScannerWidget.routeName}".allMatches(src).length, 0);
    expect("'Scan QR'".allMatches(src).length, 1);
  });

  test('profile no longer has a Mkulima entry', () {
    final src = File('lib/pages/profile_settings/profile_settings_widget.dart').readAsStringSync();
    expect(src.contains('MkulimaHubPage'), isFalse);
    expect(src.contains("label: 'Mkulima'"), isFalse);
  });
}
