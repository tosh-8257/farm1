import 'dart:io';
import 'dart:ui' as ui;

import 'package:farm/components/quick_action/quick_action_widget.dart';
import 'package:farm/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _fonts() async {
  const dir = '/usr/share/fonts/truetype/sand-box/google/Plus Jakarta Sans';
  final f = Directory(dir).listSync().whereType<File>().firstWhere((f) => f.path.endsWith('.ttf'));
  final bytes = f.readAsBytesSync();
  for (final v in ['regular', '400', '500', '600', '700', '800']) {
    await (FontLoader('PlusJakartaSans_$v')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
  const art = '/workspace/flutter-sdk/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(File('$art/MaterialIcons-Regular.otf').readAsBytesSync().buffer))))
      .load();
}

void main() {
  setUpAll(() {
    final orig = reportTestException;
    reportTestException = (d, s) {
      final e = '${d.exception}';
      if (e.contains('google_fonts') || e.contains('allowRuntimeFetching') || e.contains('Failed to load font')) return;
      orig(d, s);
    };
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  testWidgets('mkulima quick action row preview', (tester) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(800, 280);
    tester.view.devicePixelRatio = 2;
    final key = GlobalKey();
    Widget qa(IconData i, String l) => QuickActionWidget(icon: Icon(i, size: 24), label: l, onTap: () {});
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme(),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          body: Center(
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              qa(Icons.north_east_rounded, 'Send'),
              qa(Icons.smart_toy_outlined, 'Mkulima'),
              qa(Icons.shield_outlined, 'Escrow'),
              qa(Icons.account_balance_rounded, 'Invest'),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/workspace/mkulima-action-preview.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
