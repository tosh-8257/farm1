import 'dart:io';

import 'package:farm/admin/widgets/admin_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('superadmin dashboard has no hardcoded health percentages', () {
    final src = File('lib/pages/superadmin/superadmin_dashboard_page.dart').readAsStringSync();
    expect(RegExp(r"'9\d\.\d%'").hasMatch(src), isFalse);
    expect(src.contains("system_health'] ?? 98"), isFalse);
    expect(src.contains('system_checks'), isTrue);
    expect(src.contains('revenue_streams'), isTrue);
    expect(src.contains('/admin/currency-rates/current'), isTrue);
  });

  test('admin search decoration is readable on white', () {
    final d = adminSearchDecoration('Search');
    expect(d.fillColor, Colors.white);
    expect(d.hintStyle?.color, AdminColors.textSecondary);
  });

  test('info colour meets AA on white', () {
    expect(1.05 / (AdminColors.info.computeLuminance() + 0.05), greaterThanOrEqualTo(4.5));
  });
}
