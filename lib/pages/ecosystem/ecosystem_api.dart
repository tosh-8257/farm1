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
    final catalogue = await _getExists('/merchant/dropship/catalogue');
    final orders = await _getExists('/merchant/dropship/orders');
    final cargoList = await _getExists('/cargo/shipments');
    final partnerApply = await _postExists('/partners/apply');
    final cargoAdmin = await _getExists('/admin/cargo/rates');
    return EcosystemFlags(
      platform: true,
      dropship: dropship,
      stores: stores,
      cargo: cargo,
      dispatch: dispatch,
      settlement: settlement,
      catalogue: catalogue,
      orders: orders,
      cargoList: cargoList,
      partnerApply: partnerApply,
      cargoAdmin: cargoAdmin,
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

  static Future<Map<String, dynamic>> catalogue({String? query, String? category}) {
    final params = <String, String>{
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
    };
    final suffix = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return _call('GET', '/merchant/dropship/catalogue$suffix');
  }

  static Future<Map<String, dynamic>> orders() => _call('GET', '/merchant/dropship/orders');

  static Future<Map<String, dynamic>> cancelOrder({
    required String orderId,
    required String idempotencyKey,
    required String reason,
  }) =>
      _call('POST', '/merchant/dropship/orders/$orderId/cancel', {
        'idempotencyKey': idempotencyKey,
        'reason': reason,
      });

  static Future<Map<String, dynamic>> openReturn({
    required String orderId,
    required String idempotencyKey,
    required String reason,
  }) =>
      _call('POST', '/merchant/dropship/orders/$orderId/returns', {
        'idempotencyKey': idempotencyKey,
        'reason': reason,
      });

  static Future<Map<String, dynamic>> openDispute({
    required String orderId,
    required String idempotencyKey,
    required String reason,
  }) =>
      _call('POST', '/merchant/dropship/orders/$orderId/disputes', {
        'idempotencyKey': idempotencyKey,
        'reason': reason,
      });

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
    String? pickupAddress,
    String? deliveryAddress,
  }) =>
      _call('POST', '/cargo/shipments', {
        'fromZone': fromZone,
        'toZone': toZone,
        'weightKg': weightKg,
        'idempotencyKey': idempotencyKey,
        'transactionId': transactionId,
        if (pickupAddress != null && pickupAddress.isNotEmpty) 'pickupAddress': pickupAddress,
        if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      });

  static Future<Map<String, dynamic>> shipments() => _call('GET', '/cargo/shipments');

  static Future<Map<String, dynamic>> shipment(String id) => _call('GET', '/cargo/shipments/$id');

  static Future<Map<String, dynamic>> shipmentReceipt(String id) => _call('GET', '/cargo/shipments/$id/receipt');

  static Future<Map<String, dynamic>> shipmentDispute({required String id, required String reason}) =>
      _call('POST', '/cargo/shipments/$id/disputes', {'reason': reason});

  static Future<Map<String, dynamic>> openJob(String shipmentId) =>
      _call('POST', '/admin/dispatch/shipments/$shipmentId/job');

  static Future<Map<String, dynamic>> assignJob({required String jobId, required String partnerId}) =>
      _call('POST', '/admin/dispatch/jobs/$jobId/assign', {'partnerId': partnerId});

  static Future<Map<String, dynamic>> applyPartner({
    required String kind,
    required String legalName,
    String? phone,
    String? serviceArea,
    String? companyRegistration,
  }) =>
      _call('POST', '/partners/apply', {
        'kind': kind,
        'legalName': legalName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (serviceArea != null && serviceArea.isNotEmpty) 'serviceArea': serviceArea,
        if (companyRegistration != null && companyRegistration.isNotEmpty) 'companyRegistration': companyRegistration,
      });

  static Future<Map<String, dynamic>> myPartner() => _call('GET', '/partners/me');

  static Future<Map<String, dynamic>> addVehicle({
    required String category,
    required String makeModel,
    required String registration,
    required num capacityKg,
  }) =>
      _call('POST', '/partners/vehicles', {
        'category': category,
        'makeModel': makeModel,
        'registration': registration,
        'capacityKg': capacityKg,
      });

  static Future<Map<String, dynamic>> addDriver({required String legalName, required String licenceRef}) =>
      _call('POST', '/partners/drivers', {'legalName': legalName, 'licenceRef': licenceRef});

  static Future<Map<String, dynamic>> jobProof({
    required String jobId,
    required String method,
    String? reference,
  }) =>
      _call('POST', '/partners/jobs/$jobId/proof', {
        'method': method,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
      });

  static Future<Map<String, dynamic>> verifyProof({required String jobId, required String code}) =>
      _call('POST', '/partners/jobs/$jobId/proof/verify', {'code': code});

  static Future<Map<String, dynamic>> deliverJob(String jobId) => _call('POST', '/partners/jobs/$jobId/deliver');

  static Future<Map<String, dynamic>> cargoRates() => _call('GET', '/admin/cargo/rates');

  static Future<Map<String, dynamic>> cargoZones() => _call('GET', '/admin/cargo/zones');

  static Future<Map<String, dynamic>> createCargoRate({
    required String fromZone,
    required String toZone,
    required num baseFeeFarm,
    required num perKgFarm,
  }) =>
      _call('POST', '/admin/cargo/rates', {
        'fromZone': fromZone,
        'toZone': toZone,
        'baseFeeFarm': baseFeeFarm,
        'perKgFarm': perKgFarm,
      });

  static Future<Map<String, dynamic>> setCargoRateActive({required String id, required bool active}) =>
      _call('PATCH', '/admin/cargo/rates/$id', {'active': active});

  static Future<Map<String, dynamic>> setCargoSplit({required int farmShareBps, required int partnerShareBps}) =>
      _call('PATCH', '/admin/cargo/split', {
        'farmShareBps': farmShareBps,
        'partnerShareBps': partnerShareBps,
      });

  static Future<Map<String, dynamic>> aiAuthority() =>
      ApiService.request(method: 'GET', path: '/commerce/ai/authority', requiresAuth: false);

  static Future<Map<String, dynamic>> recordSettlement(String orderId) =>
      _call('POST', '/admin/settlements/orders/$orderId');
}
