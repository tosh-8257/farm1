/// Which new ecosystem screens may appear. A missing route means that
/// phase is not on the server this app is talking to.
class EcosystemFlags {
  const EcosystemFlags({
    this.platform = false,
    this.dropship = false,
    this.stores = false,
    this.cargo = false,
    this.dispatch = false,
    this.settlement = false,
    this.catalogue = false,
    this.orders = false,
    this.cargoList = false,
    this.partnerApply = false,
    this.partnerPortal = false,
    this.cargoAdmin = false,
    this.escrowPay = false,
    this.shopifyEnabled = false,
    this.wooEnabled = false,
    this.mapsVerified = false,
  });

  final bool platform;
  final bool dropship;
  final bool stores;
  final bool cargo;
  final bool dispatch;
  final bool settlement;
  final bool catalogue;
  final bool orders;
  final bool cargoList;
  final bool partnerApply;
  final bool partnerPortal;
  final bool cargoAdmin;
  final bool escrowPay;
  final bool shopifyEnabled;
  final bool wooEnabled;
  final bool mapsVerified;

  bool get any =>
      dropship ||
      stores ||
      cargo ||
      dispatch ||
      settlement ||
      catalogue ||
      orders ||
      cargoList ||
      partnerApply ||
      partnerPortal ||
      cargoAdmin;

  static const hidden = EcosystemFlags();
}

/// Nest's missing-route message. A validation 400 means the route exists.
bool routeIsMissing(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('cannot get') ||
      text.contains('cannot post') ||
      text.contains('cannot patch') ||
      text.contains('cannot delete');
}

bool integrationEnabled(Object? status, String provider) {
  if (status is! Map) return false;
  final data = status['data'] is Map ? status['data'] as Map : status;
  final list = data['integrations'];
  if (list is! List) return false;
  for (final row in list) {
    if (row is Map && '${row['provider']}' == provider) {
      return row['enabled'] == true;
    }
  }
  return false;
}

bool integrationVerified(Object? status, String provider) {
  if (status is! Map) return false;
  final data = status['data'] is Map ? status['data'] as Map : status;
  final list = data['integrations'];
  if (list is! List) return false;
  for (final row in list) {
    if (row is Map && '${row['provider']}' == provider) {
      return row['verified'] == true;
    }
  }
  return false;
}

/// Cargo quotes must not invent an arrival time or a map.
String cargoQuoteSummary(Map<dynamic, dynamic> quote) {
  final data = quote['data'] is Map ? quote['data'] as Map : quote;
  final amount = data['amount'] ?? data['price_farm'] ?? data['price'] ?? data['total'];
  final eta = data['eta'];
  final maps = data['maps_verified'] == true;
  final price = amount == null ? 'Price from the rate table' : '$amount FARM';
  final arrival = eta == null ? 'No arrival time is published' : 'ETA $eta';
  final mapLine = maps ? 'Map verified' : 'No live map';
  return '$price. $arrival. $mapLine.';
}

/// Shopify and WooCommerce stay unverified until a later check.
String storeSyncMessage({required bool verified}) {
  if (verified) return 'This shop has been verified.';
  return 'This connection is unverified. Sync does not call Shopify or WooCommerce.';
}

const partnerRegistrationNote =
    'Delivery partner is an operational role, not a new account type. '
    'An application uses this same account. An admin assigns a job only to an approved partner whose documents are not expired. '
    'There is no GPS or live tracking. Proof is a code, a signature reference, or an https photo link.';

/// Rows from `{ data: [ ... ] }`. An empty or unexpected body is an empty list.
List<Map<String, dynamic>> recordList(Object? body) {
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is! List) return const [];
  return [for (final row in data) if (row is Map) Map<String, dynamic>.from(row)];
}

/// Timeline events already stored on a shipment. Nothing is invented.
List<Map<String, dynamic>> shipmentTimeline(Object? body) {
  if (body is! Map) return const [];
  final data = body['data'] is Map ? body['data'] as Map : body;
  final timeline = data['timeline'];
  if (timeline is! List) return const [];
  return [for (final row in timeline) if (row is Map) Map<String, dynamic>.from(row)];
}

bool httpsReference(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && uri.isScheme('https') && uri.host.isNotEmpty;
}

/// Order pay accepts only the wallet auth fields. The server builds the escrow key.
Map<String, dynamic> orderPayBody(Map<String, dynamic> auth) {
  final body = <String, dynamic>{};
  final pin = auth['pin'];
  if (pin is String && pin.isNotEmpty) body['pin'] = pin;
  if (auth['biometric_auth'] == true) body['biometric_auth'] = true;
  final fingerprint = auth['device_fingerprint'];
  if (fingerprint is String && fingerprint.isNotEmpty) {
    body['device_fingerprint'] = fingerprint;
  }
  return body;
}

Map<String, dynamic> cargoBookBody({
  required String fromZone,
  required String toZone,
  required num weightKg,
  required String idempotencyKey,
  required Map<String, dynamic> auth,
  String? pickupAddress,
  String? deliveryAddress,
  String? orderId,
}) =>
    {
      'fromZone': fromZone,
      'toZone': toZone,
      'weightKg': weightKg,
      'idempotencyKey': idempotencyKey,
      ...orderPayBody(auth),
      if (pickupAddress != null && pickupAddress.isNotEmpty) 'pickupAddress': pickupAddress,
      if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'deliveryAddress': deliveryAddress,
      if (orderId != null && orderId.isNotEmpty) 'orderId': orderId,
    };

Map<String, dynamic> shipmentEventBody(String status) => {'status': status};

Map<String, dynamic> partnerDecisionBody(String decision) => {'decision': decision};

Map<String, dynamic> partnerOnlineBody(bool online) => {'online': online};

Map<String, dynamic> partnerLocationBody(num lat, num lng) => {'lat': lat, 'lng': lng};

Map<String, dynamic> partnerDocumentBody(String kind, {String? expiresAt}) => {
      'kind': kind,
      if (expiresAt != null && expiresAt.isNotEmpty) 'expiresAt': expiresAt,
    };

/// Location is stored only while the partner is online and has an assigned job.
bool partnerMayPostLocation({required bool online, required bool assigned}) => online && assigned;

String assignmentJobId(Map<dynamic, dynamic> row) => '${row['job_id'] ?? row['jobId'] ?? ''}'.trim();

/// A partner response must not display a delivery code.
Map<String, dynamic> withoutDeliverySecret(Map<String, dynamic> body) {
  Map<String, dynamic> strip(Map<dynamic, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (key == 'otp' || key == 'code' || key == 'code_hash') return;
      if (value is Map) {
        out[key] = strip(value);
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  return strip(body);
}

bool cargoSplitValid(int farmBps, int partnerBps) =>
    farmBps >= 0 && partnerBps >= 0 && farmBps + partnerBps == 10000;

/// Module rows from platform status. Null when this server has no module list.
List<Map<String, dynamic>>? moduleList(Object? status) {
  if (status is! Map) return null;
  final data = status['data'] is Map ? status['data'] as Map : status;
  final list = data['modules'];
  if (list is! List) return null;
  return [for (final row in list) if (row is Map) Map<String, dynamic>.from(row)];
}

bool moduleEnabled(List<Map<String, dynamic>> modules, String id) {
  for (final row in modules) {
    if ('${row['id']}' == id && row['enabled'] == true) return true;
  }
  return false;
}

/// Screens follow the module list. Route probes are not used once the list exists.
EcosystemFlags flagsFromModules(Object? status) {
  final modules = moduleList(status);
  if (modules == null) return EcosystemFlags.hidden;
  bool on(String id) => moduleEnabled(modules, id);
  final dropship = on('dropshipping_lite') || on('supplier_portal') || on('catalogue') || on('orders');
  final cargo = on('cargo_quotes') || on('cargo_bookings') || on('cargo_history') || on('cargo_tracking');
  final partner = on('partner_assignment') ||
      on('partner_apply') ||
      on('partner_portal') ||
      on('partner_applications');
  return EcosystemFlags(
    platform: true,
    dropship: dropship,
    stores: on('store_connections') || on('external_stores'),
    cargo: cargo,
    dispatch: on('partner_assignment'),
    settlement: on('settlement_records'),
    catalogue: dropship || on('catalogue') || on('dropship_catalogue'),
    orders: dropship || on('orders') || on('dropship_orders'),
    cargoList: cargo || on('cargo_history') || on('cargo_tracking'),
    partnerApply: partner,
    partnerPortal: partner,
    cargoAdmin: on('cargo_admin'),
    escrowPay: on('escrow_payments') || dropship || cargo,
    shopifyEnabled: integrationEnabled(status, 'shopify'),
    wooEnabled: integrationEnabled(status, 'woocommerce'),
    mapsVerified: integrationVerified(status, 'maps'),
  );
}

class FeeLine {
  const FeeLine(this.label, this.value);
  final String label;
  final String value;
}

num? _asNum(Object? value) {
  if (value is num) return value;
  if (value == null) return null;
  return num.tryParse('$value');
}

/// Breakdown from server order fields. A missing commission is not treated as zero or 10%.
List<FeeLine> orderFeeLines(Map<dynamic, dynamic> order) {
  final retail = _asNum(order['retail_total'] ?? order['retail']);
  final wholesale = _asNum(order['supplier_total'] ?? order['wholesale']);
  final rawFee = order.containsKey('commission_farm') ? order['commission_farm'] : order['commission'];
  final fee = rawFee == null ? null : _asNum(rawFee);
  final lines = <FeeLine>[
    if (retail != null) FeeLine('Retail', '$retail FARM'),
    if (wholesale != null) FeeLine('Supplier cost', '$wholesale FARM'),
    FeeLine('FARM commission', fee == null ? 'Not configured' : '$fee FARM'),
  ];
  if (retail != null && wholesale != null && fee != null) {
    lines.add(FeeLine('Seller net', '${retail - wholesale - fee} FARM'));
  }
  if (retail != null) {
    lines.add(FeeLine('Charged to your wallet', '$retail FARM'));
  }
  lines.add(const FeeLine('Held in', 'Server escrow'));
  return lines;
}

List<FeeLine> cargoFeeLines(Map<dynamic, dynamic> quote) {
  final data = quote['data'] is Map ? quote['data'] as Map : quote;
  final price = _asNum(data['price_farm'] ?? data['amount'] ?? data['price']);
  final lines = <FeeLine>[
    FeeLine('Delivery charge', price == null ? 'From the rate table' : '$price FARM'),
  ];
  if (data['farm_share_bps'] != null && data['partner_share_bps'] != null) {
    lines.add(FeeLine('Split', 'FARM ${data['farm_share_bps']} bps, partner ${data['partner_share_bps']} bps'));
  }
  lines.add(const FeeLine('Arrival time', 'None published'));
  lines.add(FeeLine('Map', data['maps_verified'] == true ? 'Verified' : 'Not verified'));
  if (price != null) lines.add(FeeLine('Charged to your wallet', '$price FARM'));
  lines.add(const FeeLine('Held in', 'Server escrow'));
  return lines;
}

String feeSummary(List<FeeLine> lines) => lines.map((line) => '${line.label}: ${line.value}').join('\n');

class SalesTotals {
  const SalesTotals({required this.count, this.retail, this.supplier, this.commission});
  final int count;
  final num? retail;
  final num? supplier;
  final num? commission;

  num? get net {
    if (retail == null || supplier == null || commission == null) return null;
    return retail! - supplier! - commission!;
  }
}

/// Sums only numbers the server sent. One missing commission leaves the total unset.
SalesTotals salesTotals(List<Map<String, dynamic>> orders) {
  num retail = 0;
  num supplier = 0;
  num commission = 0;
  var retailSeen = false;
  var supplierSeen = false;
  var commissionSeen = orders.isNotEmpty;
  for (final order in orders) {
    final r = _asNum(order['retail_total'] ?? order['retail']);
    final s = _asNum(order['supplier_total'] ?? order['wholesale'] ?? order['supplier']);
    if (r != null) {
      retail += r;
      retailSeen = true;
    }
    if (s != null) {
      supplier += s;
      supplierSeen = true;
    }
    if (!order.containsKey('commission_farm') && !order.containsKey('commission')) {
      commissionSeen = false;
    } else {
      final fee = order['commission_farm'] ?? order['commission'];
      if (fee == null) {
        commissionSeen = false;
      } else {
        commission += _asNum(fee) ?? 0;
      }
    }
  }
  return SalesTotals(
    count: orders.length,
    retail: retailSeen ? retail : null,
    supplier: supplierSeen ? supplier : null,
    commission: commissionSeen ? commission : null,
  );
}

/// Groups the in-app notices the server sends for orders, shipments, and jobs.
String noticeEntityId(Map<dynamic, dynamic> item) {
  final metadata = item['metadata'];
  final fromMeta = metadata is Map ? metadata['entityId'] ?? metadata['entity_id'] : null;
  return '${item['entity_id'] ?? item['entityId'] ?? fromMeta ?? ''}'.trim();
}

String ecosystemNoticeGroup(Map<dynamic, dynamic> item) {
  final title = '${item['title'] ?? ''}'.toLowerCase();
  final body = '${item['body'] ?? item['message'] ?? ''}'.toLowerCase();
  final type = '${item['type'] ?? ''}'.toLowerCase();
  final text = '$title $body $type';
  if (title.contains('delivery code')) return 'delivery_code';
  if (title.contains('payout')) return 'payout';
  if (text.contains('delivery job') || title == 'delivery job') return 'job';
  if (text.contains('shipment')) return 'shipment';
  if (text.contains('order update') || title.contains('order')) return 'order';
  return '';
}

List<String> zoneNames(Object? body) {
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is! List) return const [];
  final names = <String>[];
  for (final row in data) {
    if (row is String && row.trim().isNotEmpty) names.add(row.trim());
    if (row is Map) {
      final name = '${row['name'] ?? row['zone'] ?? ''}'.trim();
      if (name.isNotEmpty) names.add(name);
    }
  }
  return names;
}

const settlementRecordNote =
    'A settlement record splits a paid order into collection, supplier payable, FARM commission, and seller net. '
    'It does not move wallet balances.';

const autonomousPayNote =
    'Mkulima cannot send money from commerce. A payment still needs your PIN or biometrics.';
