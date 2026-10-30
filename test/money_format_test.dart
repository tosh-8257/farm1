import 'package:farm/pages/business/ops/ops_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money() appends the currency exactly once', () {
    expect(money(14396.32), '14,396.32 FARM');
    expect(money('5', 'KES'), '5.00 KES');
  });
}
