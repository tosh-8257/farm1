import '/backend/services/api_service.dart';
import 'business_ops_api.dart';

/// Phase 3 developer API dashboard calls. Keys are hashed on the server;
/// the full secret only ever appears in the create/rotate response.
class DeveloperApi {
  static Future<Map<String, dynamic>> _call(String method, String path,
          [Map<String, dynamic>? body]) =>
      ApiService.request(method: method, path: '/business/developer$path', body: body);

  static final data = BusinessOpsApi.data;
  static final list = BusinessOpsApi.list;

  static Future<Map<String, dynamic>> meta() async => data(await _call('GET', '/meta'));
  static Future<Map<String, dynamic>> overview(String mode) async =>
      data(await _call('GET', '/overview?mode=$mode'));

  static Future<List<Map<String, dynamic>>> keys(String mode) async =>
      list(await _call('GET', '/keys?mode=$mode'));
  static Future<Map<String, dynamic>> createKey(String name, String mode, List<String> scopes) async =>
      data(await _call('POST', '/keys', {'name': name, 'mode': mode, 'scopes': scopes}));
  static Future<Map<String, dynamic>> rotateKey(String id, String pin) async =>
      data(await _call('POST', '/keys/$id/rotate', {'pin': pin}));
  static Future<void> revokeKey(String id, String pin) =>
      _call('POST', '/keys/$id/revoke', {'pin': pin});

  static Future<List<Map<String, dynamic>>> webhooks(String mode) async =>
      list(await _call('GET', '/webhooks?mode=$mode'));
  static Future<Map<String, dynamic>> createWebhook(Map<String, dynamic> body) async =>
      data(await _call('POST', '/webhooks', body));
  static Future<Map<String, dynamic>> updateWebhook(String id, Map<String, dynamic> body) async =>
      data(await _call('PATCH', '/webhooks/$id', body));
  static Future<Map<String, dynamic>> rollSecret(String id, String pin) async =>
      data(await _call('POST', '/webhooks/$id/roll-secret', {'pin': pin}));
  static Future<void> deleteWebhook(String id, String pin) =>
      _call('POST', '/webhooks/$id/delete', {'pin': pin});
  static Future<void> testWebhook(String id) => _call('POST', '/webhooks/$id/test');
  static Future<List<Map<String, dynamic>>> deliveries(String id) async =>
      list(await _call('GET', '/webhooks/$id/deliveries?limit=50'));
  static Future<void> retryDelivery(String id) => _call('POST', '/deliveries/$id/retry');

  static Future<List<Map<String, dynamic>>> requests(String mode, {bool errorsOnly = false}) async =>
      list(await _call('GET', '/requests?mode=$mode&limit=100${errorsOnly ? '&errors=true' : ''}'));
  static Future<Map<String, dynamic>> usage(String mode, String range) async =>
      data(await _call('GET', '/usage?mode=$mode&range=$range'));
}
