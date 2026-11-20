/// Name and stable id shown before someone allows a business to request payments.
class BusinessIdentity {
  const BusinessIdentity({
    required this.id,
    required this.name,
    this.publicCode,
    this.status,
  });

  final String id;
  final String name;
  final String? publicCode;
  final String? status;

  /// Code the business can read out. Falls back to the internal id.
  String get displayId {
    final code = publicCode?.trim() ?? '';
    if (code.isNotEmpty) return code;
    return id;
  }
}

/// Accepts the current profile payload and the lookup payload the backend
/// is adding (`public_code`, `trading_name`, `business_name`).
BusinessIdentity? parseBusinessIdentity(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final nested = map['data'] ?? map['business'];
  final hasName = _pick(map, const ['trading_name', 'business_name', 'legal_name', 'name']).isNotEmpty;
  if (nested is Map && !hasName) return parseBusinessIdentity(nested);
  final id = _pick(map, const ['id', 'business_id', 'uuid']);
  final code = _pick(map, const ['public_code', 'publicCode', 'business_code', 'code']);
  final name = _pick(map, const ['trading_name', 'business_name', 'legal_name', 'name']);
  final stable = id.isNotEmpty ? id : code;
  if (stable.isEmpty && name.isEmpty) return null;
  final status = _pick(map, const ['status']);
  return BusinessIdentity(
    id: stable,
    name: name,
    publicCode: code.isEmpty ? null : code,
    status: status.isEmpty ? null : status,
  );
}

String _pick(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = '${map[key] ?? ''}'.trim();
    if (value.isNotEmpty && value != 'null') return value;
  }
  return '';
}
