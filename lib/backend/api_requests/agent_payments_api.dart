import 'dart:math';
import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';
import '/pages/agent_payments/business_identity.dart';
import '/services/payment_confirm.dart';

/// Phase 9: agentic payments. Caps, PIN checks and money movement are all enforced by the server.
class AgentPaymentsApi {
  static Map<String, dynamic> _d(Map<String, dynamic> r) =>
      r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
  static Future<Map<String, dynamic>> _r(String m, String p, [Map<String, dynamic>? b]) =>
      ApiService.request(method: m, path: p, body: b);

  /// Random idempotency key (keep one per form so retries never double-create).
  static String newKey() {
    final r = Random.secure();
    return List.generate(32, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  static Future<Map<String, dynamic>> status() async => _d(await _r('GET', '/agent-payments/status'));
  // Payer
  static Future<Map<String, dynamic>> intent(String id) async => _d(await _r('GET', '/agent-payments/intents/$id'));
  static Future<Map<String, dynamic>> pay(String id, PaymentConfirmation auth) async =>
      _d(await _r('POST', '/agent-payments/intents/$id/pay', auth.authFields()));
  static Future<List<Map<String, dynamic>>> mandates() async =>
      BusinessOpsApi.list(await _r('GET', '/agent-payments/authorizations'));
  static Future<Map<String, dynamic>> createMandate(Map<String, dynamic> body) async =>
      _d(await _r('POST', '/agent-payments/authorizations', body));

  /// Name and stable id before the PIN. Tries the new lookup, then a direct
  /// read. A missing route returns null so the screen can say so.
  static Future<BusinessIdentity?> lookupBusiness(String code) async {
    final q = Uri.encodeQueryComponent(code.trim());
    for (final path in [
      '/agent-payments/businesses/lookup?code=$q',
      '/agent-payments/businesses/$q',
    ]) {
      try {
        final raw = await _r('GET', path);
        final identity = parseBusinessIdentity(raw);
        if (identity != null && (identity.name.isNotEmpty || identity.id.isNotEmpty)) {
          return identity;
        }
      } on ApiServiceException catch (e) {
        if (e.statusCode == 404 || e.statusCode == 405) continue;
        rethrow;
      }
    }
    return null;
  }
  static Future<Map<String, dynamic>> revokeMandate(String id) async =>
      _d(await _r('POST', '/agent-payments/authorizations/$id/revoke'));
  static Future<List<Map<String, dynamic>>> requests({String? status}) async => BusinessOpsApi.list(
      await _r('GET', '/agent-payments/requests${status == null ? '' : '?status=$status'}'));
  static Future<Map<String, dynamic>> confirmRequest(String id, PaymentConfirmation auth) async =>
      _d(await _r('POST', '/agent-payments/requests/$id/confirm', auth.authFields()));
  static Future<Map<String, dynamic>> rejectRequest(String id) async =>
      _d(await _r('POST', '/agent-payments/requests/$id/reject'));
  // Business dashboard
  static Future<List<Map<String, dynamic>>> businessIntents({String? status}) async => BusinessOpsApi.list(
      await _r('GET', '/business/payment-intents${status == null ? '' : '?status=$status'}'));
  static Future<Map<String, dynamic>> createIntent(Map<String, dynamic> body, String idempotencyKey) async =>
      _d(await _r('POST', '/business/payment-intents', {...body, 'idempotency_key': idempotencyKey}));
  static Future<Map<String, dynamic>> businessIntent(String id) async => _d(await _r('GET', '/business/payment-intents/$id'));
  static Future<Map<String, dynamic>> cancelIntent(String id) async =>
      _d(await _r('POST', '/business/payment-intents/$id/cancel'));
  static Future<List<Map<String, dynamic>>> refunds(String id) async =>
      BusinessOpsApi.list(await _r('GET', '/business/payment-intents/$id/refunds'));
  static Future<Map<String, dynamic>> refund(String id, Map<String, dynamic> body, String idempotencyKey) async =>
      _d(await _r('POST', '/business/payment-intents/$id/refunds', {...body, 'idempotency_key': idempotencyKey}));
  static Future<List<Map<String, dynamic>>> businessMandates() async =>
      BusinessOpsApi.list(await _r('GET', '/business/agent-authorizations'));
}
