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
    this.cargoAdmin = false,
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
  final bool cargoAdmin;
  final bool shopifyEnabled;
  final bool wooEnabled;
  final bool mapsVerified;

  bool get any =>
      dropship || stores || cargo || dispatch || settlement || catalogue || orders || cargoList || partnerApply || cargoAdmin;

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

bool cargoSplitValid(int farmBps, int partnerBps) =>
    farmBps >= 0 && partnerBps >= 0 && farmBps + partnerBps == 10000;

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
