// Renders admin screens with fixture API responses to PNGs for visual review.
// Not part of the default test suite. Run:
//   flutter test test_preview/admin_preview_test.dart --dart-define=PREVIEW_TAG=after
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:farm/admin/pages/admin_dashboard_page.dart';
import 'package:farm/admin/pages/user_management_page.dart';
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
final _txs = [
  {'id': '052a9198-00c1-4180-b4ad-4a5fcf9b6c92', 'transaction_reference': '052a9198-00c1-4180-b4ad-4a5fcf9b6c92', 'transaction_type': 'deposit', 'amount': '262.00', 'status': 'completed'},
  {'id': '058aac3b-285f-47bf-ad57-e68a0ef4ca30', 'transaction_reference': '058aac3b-285f-47bf-ad57-e68a0ef4ca30', 'transaction_type': 'deposit', 'amount': '13000', 'status': 'completed'},
  {'id': '0d8d7519-4351-4a3c-9a0e-5c1b2d3e4f50', 'transaction_reference': '0d8d7519-4351-4a3c-9a0e-5c1b2d3e4f50', 'transaction_type': 'withdrawal', 'amount': '1250.5', 'status': 'pending'},
];
final _users = [
  {'id': 'u1', 'first_name': 'Anthony', 'last_name': 'Muriithi', 'email': 'hellomotono@gmail.com', 'kyc_status': 'rejected', 'balance': '0'},
  {'id': 'u2', 'first_name': 'Onesmus', 'last_name': 'Musyoki', 'email': 'efootballking2284@gmail.com', 'kyc_status': 'none', 'balance': '0'},
  {'id': 'u3', 'first_name': 'Grace', 'last_name': 'Wanjiru', 'email': 'grace.w@example.com', 'kyc_status': 'verified', 'balance': '15420.75'},
];

Future<http.Response> _handler(http.Request r) async {
  final p = r.url.path;
  Map<String, dynamic> body;
  if (p.endsWith('/admin/dashboard')) {
    body = {'data': {'total_users': 128, 'active_escrows': 4, 'pending_kyc': 7, 'pending_payouts': 2}};
  } else if (p.contains('/transactions')) {
    body = {'data': _txs, 'total': _txs.length};
  } else if (p.contains('/users')) {
    final k = r.url.queryParameters['kyc_status'] ?? r.url.queryParameters['kycStatus'];
    final rows = k == null ? _users : _users.where((u) => u['kyc_status'] == k).toList();
    body = {'data': rows, 'meta': {'total': rows.length}};
  } else {
    return http.Response('not found', 404);
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}

Future<void> _loadFonts() async {
  final jak = File('$fontDir/PlusJakartaSans-VariableFont_wght.ttf').readAsBytesSync();
  for (final v in ['regular', '100', '200', '300', '500', '600', '700', '800', '900']) {
    final l = FontLoader('PlusJakartaSans_$v')..addFont(Future.value(ByteData.view(jak.buffer)));
    await l.load();
  }
  final art = '${Platform.environment['FLUTTER_ROOT'] ?? '/workspace/flutter-sdk'}/bin/cache/artifacts/material_fonts';
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(File('$art/MaterialIcons-Regular.otf').readAsBytesSync().buffer)));
  await icons.load();
  final roboto = FontLoader('Roboto')..addFont(Future.value(ByteData.view(File('$art/Roboto-Regular.ttf').readAsBytesSync().buffer)));
  await roboto.load();
}

Future<void> _shoot(WidgetTester t, Widget page, String name, {double height = 1700}) async {
  await t.binding.setSurfaceSize(Size(400, height));
  t.view.physicalSize = Size(400 * 2, height * 2);
  t.view.devicePixelRatio = 2;
  final key = GlobalKey();
  await http.runWithClient(() async {
    await t.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        home: Theme(data: AppTheme.lightTheme(), child: page),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump(const Duration(milliseconds: 50));
    }
  }, () => MockClient(_handler));
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('/workspace/admin-preview-$name-$tag.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final orig = reportTestException;
    reportTestException = (details, desc) {
      if ('${details.exception}'.contains('google_fonts') || '${details.exception}'.contains('allowRuntimeFetching')) return;
      orig(details, desc);
    };
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadFonts();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'adminName': 'Admin', 'adminRole': 'admin'});
    FlutterSecureStorage.setMockInitialValues({});
    FFAppState.reset();
    await AuthSessionStore.saveRoleSession(role: 'admin', accessToken: _jwt(), refreshToken: 'r', userId: 'admin-1');
  });

  testWidgets('dashboard', (t) async => _shoot(t, const AdminDashboardPage(), 'dashboard', height: 1900));
  testWidgets('users', (t) async => _shoot(t, const UserManagementPage(), 'users', height: 1300));
}
