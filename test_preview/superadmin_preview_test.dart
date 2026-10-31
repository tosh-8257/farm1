// Renders super admin screens with fixture API responses to PNGs for visual review.
// Not part of the default test suite. Run:
//   flutter test test_preview/superadmin_preview_test.dart --dart-define=PREVIEW_TAG=after
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:farm/admin/pages/escrow_management_page.dart';
import 'package:farm/admin/pages/transactions_management_page.dart';
import 'package:farm/pages/superadmin/superadmin_dashboard_page.dart';
import 'package:farm/app_state.dart';
import 'package:farm/core/app_theme.dart';
import 'package:farm/services/auth/session_store_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tag = String.fromEnvironment('PREVIEW_TAG', defaultValue: 'after');
const fontDir = '/usr/share/fonts/truetype/sand-box/google/Plus Jakarta Sans';

String _jwt() {
  String seg(Map<String, Object> j) => base64Url.encode(utf8.encode(jsonEncode(j))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256'})}.${seg({'sub': 'admin-1', 'exp': exp})}.sig';
}


// Fixture rows shaped like the backend responses; used only to render previews.
final _now = DateTime.now().toUtc();
final _txs = [
  {'id': '052a9198-00c1-4180-b4ad-4a5fcf9b6c92', 'transaction_reference': 'TXN-052A9198', 'transaction_type': 'transfer', 'amount': '262.00', 'status': 'completed', 'sender_name': 'Grace Wanjiru', 'receiver_name': 'Anthony Muriithi', 'date': '30 Oct 2026', 'time': '14:02'},
  {'id': '058aac3b-285f-47bf-ad57-e68a0ef4ca30', 'transaction_reference': 'TXN-058AAC3B', 'transaction_type': 'deposit', 'amount': '13000', 'status': 'pending', 'sender_name': 'M-Pesa', 'receiver_name': 'Onesmus Musyoki', 'date': '30 Oct 2026', 'time': '11:40'},
];
final _escrows = [
  {'id': '7c1e0b2a-55aa-4bb1-9d3e-0f9a8b7c6d5e', 'reference_code': 'ESC-7C1E0B', 'title': 'Maize 20 bags', 'amount': '4500', 'status': 'completed', 'created_at': _now.toIso8601String(), 'users_escrow_contracts_buyer_idTousers': {'username': 'grace'}, 'users_escrow_contracts_seller_idTousers': {'username': 'anthony'}},
  {'id': '9d2f1c3b-66bb-4cc2-8e4f-1a0b9c8d7e6f', 'reference_code': 'ESC-9D2F1C', 'title': 'Dairy feed', 'amount': '1200', 'status': 'active', 'created_at': _now.toIso8601String(), 'users_escrow_contracts_buyer_idTousers': {'username': 'onesmus'}, 'users_escrow_contracts_seller_idTousers': {'username': 'grace'}},
];

Future<http.Response> _handler(http.Request r) async {
  final p = r.url.path;
  Object body;
  if (p.endsWith('/superadmin/dashboard')) {
    body = {'data': {
      'total_users': 128, 'total_revenue': 38.09, 'active_transactions': 3,
      'escrow_creation_earnings': 13.67, 'escrow_creation_count': 47,
      'escrow_release_earnings': 12.42, 'escrow_release_count': 42,
      'withdraw_fee_earnings': 7.8, 'withdraw_transaction_count': 6,
      'merchant_sales_fee_earnings': 2.7, 'merchant_sales_count': 10,
      'revenue_streams': [
        {'type': 'escrow_lock', 'label': 'Escrow creation fees', 'total': 13.67, 'count': 47},
        {'type': 'escrow_release', 'label': 'Escrow release fees', 'total': 12.42, 'count': 42},
        {'type': 'withdrawal', 'label': 'Withdrawal fees', 'total': 7.8, 'count': 6},
        {'type': 'merchant_payment', 'label': 'Merchant sales fees', 'total': 2.7, 'count': 10},
        {'type': 'transfer', 'label': 'Transfer fees', 'total': 1.5, 'count': 3},
      ],
      'system_checks': {'checked_at': _now.toIso8601String(), 'checks': [
        {'name': 'Database', 'status': 'ok', 'detail': '4 ms'},
        {'name': 'USD/KES rate', 'status': 'ok', 'detail': 'live'},
        {'name': 'Pending > 24h', 'status': 'degraded', 'detail': '2 transactions'},
        {'name': 'API server', 'status': 'ok', 'detail': 'up 312 min, 141 MB heap'},
      ]},
      'recent_activities': [],
    }};
  } else if (p.endsWith('/admin/wallet')) {
    body = {'data': {'available_balance': 22.08, 'merchant_sales_revenue': 2.7, 'merchant_sales_count': 10}};
  } else if (p.endsWith('/currency-rates/current')) {
    body = {'data': {'usd_kes_rate': 129.25, 'farm_usd_rate': 0.00773694, 'source': 'live', 'is_override': false, 'live_enabled': true, 'stale': false, 'updated_at': _now.subtract(const Duration(minutes: 12)).toIso8601String()}};
  } else if (p.endsWith('/currency-rates')) {
    body = {'data': [{'usd_kes_rate': 131, 'farm_usd_rate': 0.007633587786259542}]};
  } else if (p.contains('/transactions')) {
    body = {'data': _txs, 'meta': {'total': _txs.length}};
  } else if (p.contains('/escrow')) {
    body = {'data': _escrows, 'meta': {'total': _escrows.length}};
  } else if (p.contains('exchange-rates')) {
    body = {'data': []};
  } else {
    body = {'data': []};
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}

Future<void> _loadFonts() async {
  final jak = File('$fontDir/PlusJakartaSans-VariableFont_wght.ttf').readAsBytesSync();
  for (final v in ['regular', '100', '200', '300', '500', '600', '700', '800', '900']) {
    await (FontLoader('PlusJakartaSans_$v')..addFont(Future.value(ByteData.view(jak.buffer)))).load();
  }
  final art = '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/flutter-sdk'}/bin/cache/artifacts/material_fonts';
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File('$art/MaterialIcons-Regular.otf').readAsBytesSync().buffer)))).load();
  await (FontLoader('Roboto')..addFont(Future.value(ByteData.view(File('$art/Roboto-Regular.ttf').readAsBytesSync().buffer)))).load();
}

/// [pushedTheme] mimics how the super admin dashboard pushes a page:
/// 'dark' = the old push without a theme, 'light' = the fixed push.
Future<void> _shoot(WidgetTester t, Widget page, String name, {double height = 1700, String pushedTheme = 'none'}) async {
  await t.binding.setSurfaceSize(Size(400, height));
  t.view.physicalSize = Size(400 * 2, height * 2);
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  final ThemeData? wrap = pushedTheme == 'light' ? AppTheme.lightTheme() : pushedTheme == 'dark' ? AppTheme.darkTheme() : null;
  await http.runWithClient(() async {
    await t.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: pushedTheme == 'dark' ? AppTheme.darkTheme() : AppTheme.lightTheme(),
        home: wrap == null ? page : Theme(data: wrap, child: page),
      ),
    ));
    for (var i = 0; i < 10; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }, () => MockClient(_handler));
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/workspace/superadmin-preview-$name-$tag.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(minutes: 5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final orig = reportTestException;
    reportTestException = (details, desc) {
      final e = '${details.exception}';
      if (e.contains('google_fonts') || e.contains('allowRuntimeFetching') || e.contains('Failed to load font')) return;
      orig(details, desc);
    };
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'adminName': 'Super Admin', 'adminRole': 'super_admin'});
    FlutterSecureStorage.setMockInitialValues({});
    FFAppState.reset();
    await AuthSessionStore.saveRoleSession(role: 'super_admin', accessToken: _jwt(), refreshToken: 'r', userId: 'sa-1');
  });

  const pushed = tag == 'before' ? 'dark' : 'light';
  testWidgets('dashboard', (t) async => _shoot(t, const SuperadminDashboardPage(), 'dashboard', height: 4200));
  testWidgets('transactions', (t) async => _shoot(t, const TransactionsManagementPage(), 'transactions', height: 1100, pushedTheme: pushed));
  testWidgets('escrows', (t) async => _shoot(t, const EscrowManagementPage(), 'escrows', height: 1100, pushedTheme: pushed));
}
