import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coin icon asset is not a copy of the brand logo', () {
    final coin = File('assets/images/farm_coin.png').readAsBytesSync();
    final brand = File('assets/images/app_logo.png').readAsBytesSync();
    expect(coin, isNot(equals(brand)));
    expect(File('assets/images/farm_coin_128.png').existsSync(), isTrue);
  });
}
