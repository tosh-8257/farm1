import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';
import '/core/app_config.dart';

/// Phase 10: x402 paid APIs. Verification and settlement happen on the server and on Algorand.
class X402Api {
  static Map<String, dynamic> _d(Map<String, dynamic> r) =>
      r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
  static Future<Map<String, dynamic>> _r(String m, String p, [Map<String, dynamic>? b]) =>
      ApiService.request(method: m, path: p, body: b);

  /// Public URL agents call (answers 402 until paid).
  static String gatewayUrl(String path) =>
      AppConfig.api.replaceFirst(RegExp(r'/v\d+$'), '') + path;

  static Future<Map<String, dynamic>> status() async => _d(await _r('GET', '/x402/status'));
  static Future<List<Map<String, dynamic>>> resources() async =>
      BusinessOpsApi.list(await _r('GET', '/business/x402/resources'));
  static Future<Map<String, dynamic>> resource(String id) async => _d(await _r('GET', '/business/x402/resources/$id'));
  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      _d(await _r('POST', '/business/x402/resources', body));
  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) async =>
      _d(await _r('PATCH', '/business/x402/resources/$id', body));
  static Future<List<Map<String, dynamic>>> payments({String? resourceId}) async => BusinessOpsApi.list(
      await _r('GET', '/business/x402/payments${resourceId == null ? '' : '?resource_id=$resourceId'}'));
}
