import 'package:farm/admin/widgets/admin_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shortId truncates long ids to head…tail', () {
    expect(shortId('052a9b1c-0000-4000-8000-9f1e2d3c9c92'), '052a9…9c92');
    expect(shortId('TX-123'), 'TX-123');
    expect(shortId(null), '');
  });

  test('formatFarmAmount uses separators and never abbreviates', () {
    expect(formatFarmAmount(13000), '13,000.00');
    expect(formatFarmAmount('1234567.5', sign: '+'), '+1,234,567.50');
    expect(formatFarmAmount(-12.3), '12.30');
    expect(formatFarmAmount('x'), '0.00');
  });

  test('admin text colours meet WCAG AA on white', () {
    double lum(c) => c.computeLuminance();
    double ratio(c) => (1.05) / (lum(c) + 0.05);
    for (final c in [AdminColors.text, AdminColors.textSecondary, AdminColors.success, AdminColors.error, AdminColors.warning]) {
      expect(ratio(c), greaterThanOrEqualTo(4.5));
    }
  });
}
