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
  final bool shopifyEnabled;
  final bool wooEnabled;
  final bool mapsVerified;

  bool get any => dropship || stores || cargo || dispatch || settlement;

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
  final amount = data['amount'] ?? data['price'] ?? data['total'];
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
    'This release has no self-serve application. An admin can assign a job only to an approved partner whose documents are not expired. '
    'There is no GPS or live tracking.';

const settlementRecordNote =
    'A settlement record splits a paid order into collection, supplier payable, FARM commission, and seller net. '
    'It does not move wallet balances.';

const autonomousPayNote =
    'Mkulima cannot send money from commerce. A payment still needs your PIN or biometrics.';
