import '/backend/services/api_service.dart';
import 'ecosystem_logic.dart';

class EcosystemApi {
  static Future<Map<String, dynamic>> _call(String method, String path, [Map<String, dynamic>? body]) =>
      ApiService.request(method: method, path: path, body: body);

  static Future<Map<String, dynamic>?> platformStatus() async {
    try {
      return await ApiService.request(method: 'GET', path: '/platform/status', requiresAuth: false);
    } catch (e) {
      if (routeIsMissing(e)) return null;
      return null;
    }
  }

  static Future<bool> _postExists(String path, [Map<String, dynamic>? body]) async {
    try {
      await _call('POST', path, body ?? const {});
      return true;
    } catch (e) {
      return !routeIsMissing(e);
    }
  }

  static Future<bool> _getExists(String path) async {
    try {
      await ApiService.request(method: 'GET', path: path);
      return true;
    } catch (e) {
      return !routeIsMissing(e);
    }
  }

  /// Probes each phase. A missing platform status hides everything, because
  /// that route is the first phase and is not on the current production API.
  static Future<EcosystemFlags> flags() async {
    final status = await platformStatus();
    if (status == null) return EcosystemFlags.hidden;
    final dropship = await _postExists('/suppliers/apply');
    final stores = await _postExists('/business/stores');
    final cargo = await _postExists('/cargo/quotes');
    final dispatch = await _postExists(
      '/admin/dispatch/jobs/00000000-0000-4000-8000-000000000001/assign',
      const {'partnerId': '00000000-0000-4000-8000-000000000002'},
    );
    final settlement = await _getExists('/commerce/ai/authority');
    return EcosystemFlags(
      platform: true,
      dropship: dropship,
      stores: stores,
      cargo: cargo,
      dispatch: dispatch,
      settlement: settlement,
      shopifyEnabled: integrationEnabled(status, 'shopify'),
      wooEnabled: integrationEnabled(status, 'woocommerce'),
      mapsVerified: integrationVerified(status, 'maps'),
    );
  }

  static Future<Map<String, dynamic>> applySupplier({
    required String kind,
    required String legalName,
    String? region,
  }) =>
      _call('POST', '/suppliers/apply', {
        'kind': kind,
        'legalName': legalName,
        if (region != null && region.isNotEmpty) 'region': region,
      });

  static Future<Map<String, dynamic>> mySupplier() => _call('GET', '/suppliers/me');

  static Future<Map<String, dynamic>> supplierDecision(String fulfilmentId, String decision) =>
      _call('POST', '/suppliers/fulfilments/$fulfilmentId/decision', {'decision': decision});

  static Future<Map<String, dynamic>> importListing({required String variantId, required num retailPrice}) =>
      _call('POST', '/merchant/dropship/listings', {
        'variantId': variantId,
        'retailPrice': retailPrice,
      });

  static Future<Map<String, dynamic>> placeOrder({
    required String idempotencyKey,
    required String variantId,
    required int qty,
    required num retail,
  }) =>
      _call('POST', '/merchant/dropship/orders', {
        'idempotencyKey': idempotencyKey,
        'lines': [
          {'variantId': variantId, 'qty': qty, 'retail': retail},
        ],
      });

  static Future<Map<String, dynamic>> payOrder({required String orderId, required String transactionId}) =>
      _call('POST', '/merchant/dropship/orders/$orderId/pay', {'transactionId': transactionId});

  static Future<Map<String, dynamic>> forwardOrder(String orderId) =>
      _call('POST', '/merchant/dropship/orders/$orderId/forward');

  static Future<Map<String, dynamic>> connectStore({required String platform, required String shopDomain}) =>
      _call('POST', '/business/stores', {'platform': platform, 'shopDomain': shopDomain});

  static Future<Map<String, dynamic>> syncStore(String id) => _call('POST', '/business/stores/$id/sync');

  static Future<Map<String, dynamic>> cargoQuote({
    required String fromZone,
    required String toZone,
    required num weightKg,
  }) =>
      _call('POST', '/cargo/quotes', {
        'fromZone': fromZone,
        'toZone': toZone,
        'weightKg': weightKg,
      });

  static Future<Map<String, dynamic>> cargoBook({
    required String fromZone,
    required String toZone,
    required num weightKg,
    required String idempotencyKey,
    required String transactionId,
  }) =>
      _call('POST', '/cargo/shipments', {
        'fromZone': fromZone,
        'toZone': toZone,
        'weightKg': weightKg,
        'idempotencyKey': idempotencyKey,
        'transactionId': transactionId,
      });

  static Future<Map<String, dynamic>> openJob(String shipmentId) =>
      _call('POST', '/admin/dispatch/shipments/$shipmentId/job');

  static Future<Map<String, dynamic>> assignJob({required String jobId, required String partnerId}) =>
      _call('POST', '/admin/dispatch/jobs/$jobId/assign', {'partnerId': partnerId});

  static Future<Map<String, dynamic>> aiAuthority() =>
      ApiService.request(method: 'GET', path: '/commerce/ai/authority', requiresAuth: false);

  static Future<Map<String, dynamic>> recordSettlement(String orderId) =>
      _call('POST', '/admin/settlements/orders/$orderId');
}
