import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';

/// Phase 7: Mkulima AI assistant. All rules (caps, allowlist, PIN) are enforced by the server.
class AiApi {
  static Map<String, dynamic> _d(Map<String, dynamic> r) =>
      r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
  static Future<Map<String, dynamic>> status() async => _d(await ApiService.request(method: 'GET', path: '/ai/status'));
  static Future<Map<String, dynamic>> chat(String message, {String? conversationId}) async => _d(await ApiService.request(
      method: 'POST',
      path: '/ai/chat',
      timeoutSeconds: 60,
      body: {'message': message, if (conversationId != null) 'conversation_id': conversationId}));
  static Future<List<Map<String, dynamic>>> conversations() async =>
      BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/ai/conversations'));
  static Future<Map<String, dynamic>> conversation(String id) async =>
      _d(await ApiService.request(method: 'GET', path: '/ai/conversations/$id'));
  static Future<void> deleteConversation(String id) => ApiService.request(method: 'DELETE', path: '/ai/conversations/$id');
  static Future<Map<String, dynamic>> permissions() async => _d(await ApiService.request(method: 'GET', path: '/ai/permissions'));
  static Future<Map<String, dynamic>> savePermissions(
          {required bool enabled, required num perTxCap, required num dailyCap}) async =>
      _d(await ApiService.request(method: 'PUT', path: '/ai/permissions', body: {
        'enabled': enabled,
        'per_tx_cap': perTxCap,
        'daily_cap': dailyCap,
        'allowed_actions': enabled ? ['send_farm', 'book_flight', 'pay_intent'] : <String>[],
      }));
  static Future<Map<String, dynamic>> revoke() async =>
      _d(await ApiService.request(method: 'POST', path: '/ai/permissions/revoke'));
  static Future<List<Map<String, dynamic>>> actions({String? status}) async => BusinessOpsApi.list(
      await ApiService.request(method: 'GET', path: '/ai/actions${status == null ? '' : '?status=$status'}'));
  static Future<Map<String, dynamic>> confirm(String id, String pin) async =>
      _d(await ApiService.request(method: 'POST', path: '/ai/actions/$id/confirm', body: {'pin': pin}));
  static Future<void> reject(String id) => ApiService.request(method: 'POST', path: '/ai/actions/$id/reject');
  static Future<List<Map<String, dynamic>>> audit() async =>
      BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/ai/audit'));
}
