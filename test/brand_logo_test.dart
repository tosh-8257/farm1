import 'package:farm/components/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand logo is the original app logo, not the coin', () {
    expect(BrandLogo.asset, 'assets/images/app_logo.png');
  });

  testWidgets('BrandLogo renders the app logo asset', (t) async {
    await t.pumpWidget(const MaterialApp(home: BrandLogo(size: 48)));
    final img = t.widget<Image>(find.byType(Image));
    expect((img.image as AssetImage).assetName, 'assets/images/app_logo.png');
  });
}
