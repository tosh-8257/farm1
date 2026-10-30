import 'dart:convert';

import 'package:farm/admin/services/admin_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwtExpiringAt(DateTime expiry) {
  String seg(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = expiry.millisecondsSinceEpoch ~/ 1000;
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg({'sub': 'admin-1', 'exp': exp})}.signature';
}

void main() {
  group('AdminApiService.tokenNeedsRefresh', () {
    test('keeps a token that is valid well beyond the refresh threshold', () {
      final token = _jwtExpiringAt(
        DateTime.now().add(const Duration(minutes: 30)),
      );
      expect(AdminApiService.tokenNeedsRefresh(token), isFalse);
    });

    test('refreshes a token that expires within the 60s threshold', () {
      final token = _jwtExpiringAt(
        DateTime.now().add(const Duration(seconds: 30)),
      );
      expect(AdminApiService.tokenNeedsRefresh(token), isTrue);
    });

    test('refreshes an already expired token', () {
      final token = _jwtExpiringAt(
        DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(AdminApiService.tokenNeedsRefresh(token), isTrue);
    });

    test('treats empty or malformed tokens as needing refresh', () {
      expect(AdminApiService.tokenNeedsRefresh(''), isTrue);
      expect(AdminApiService.tokenNeedsRefresh('not-a-jwt'), isTrue);
    });
  });
}
