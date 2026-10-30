import '/backend/services/api_service.dart';

/// Tap to pay (NFC HCE / QR). The token never carries the amount; the backend does.
class NfcPayApi {
  static Map<String, dynamic> _d(Map<String, dynamic> r) =>
      Map<String, dynamic>.from((r['data'] as Map?) ?? const {});

  static Future<bool> enabled() async =>
      _d(await ApiService.request(method: 'GET', path: '/nfc-pay/config'))['enabled'] == true;

  static Future<Map<String, dynamic>> create(double amount, {String? description}) async => _d(await ApiService.request(
      method: 'POST',
      path: '/nfc-pay/requests',
      body: {'amount': amount, if ((description ?? '').trim().isNotEmpty) 'description': description!.trim()}));

  static Future<Map<String, dynamic>> status(String id) async =>
      _d(await ApiService.request(method: 'GET', path: '/nfc-pay/requests/$id'));

  static Future<Map<String, dynamic>> resolve(String token) async => _d(await ApiService.request(
      method: 'GET', path: '/nfc-pay/resolve?token=${Uri.encodeQueryComponent(token)}'));

  static Future<Map<String, dynamic>> pay(String token, String pin) async =>
      _d(await ApiService.request(method: 'POST', path: '/nfc-pay/pay', body: {'token': token, 'pin': pin}));

  /// Accepts "farmpay:<token>", "farmpay1.…" or a URL containing ?t=<token>.
  static String? extractToken(String raw) {
    var s = raw.trim();
    if (s.startsWith('farmpay:')) s = s.substring(8);
    final m = RegExp(r'farmpay1\.[0-9a-fA-F-]{36}\.\d+\.[A-Za-z0-9_-]+').firstMatch(s);
    return m?.group(0);
  }
}
