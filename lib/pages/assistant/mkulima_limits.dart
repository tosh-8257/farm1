/// Platform ceilings from AI permissions. The app does not invent a
/// 100,000 FARM cap. A missing field means the server did not publish one.
class MkulimaCeilings {
  const MkulimaCeilings({this.perTx, this.daily});

  final num? perTx;
  final num? daily;
}

MkulimaCeilings mkulimaCeilings(Map<dynamic, dynamic> permissions) {
  return MkulimaCeilings(
    perTx: _ceiling(permissions, const [
      'platform_per_tx_ceiling',
      'max_per_tx_cap',
    ]),
    daily: _ceiling(permissions, const [
      'platform_daily_ceiling',
      'platform_daily_cap',
      'max_daily_cap',
      'daily_cap_max',
    ]),
  );
}

/// Daily ceiling, for callers that only need one number.
num? mkulimaDeclaredCeiling(Map<dynamic, dynamic> permissions) =>
    mkulimaCeilings(permissions).daily;

/// Null when the server published no ceiling. The app then shows no maximum.
String? mkulimaCeilingLabel(Map<dynamic, dynamic> permissions) {
  final caps = mkulimaCeilings(permissions);
  final parts = <String>[];
  if (caps.perTx != null) parts.add('per payment ${caps.perTx}');
  if (caps.daily != null) parts.add('per day ${caps.daily}');
  if (parts.isEmpty) return null;
  return parts.join(', ');
}

/// Any positive per-payment and daily amount is accepted. A null platform
/// ceiling is not a maximum. The user's daily limit still has to cover
/// the per-payment limit.
bool mkulimaAcceptsLimits({
  required num? perTx,
  required num? daily,
  required Map<dynamic, dynamic> permissions,
}) {
  if (perTx == null || daily == null || perTx <= 0 || daily < perTx) return false;
  // A null platform ceiling is not a maximum, and a published ceiling is
  // not applied here. The server decides. Any positive pair is allowed.
  mkulimaCeilings(permissions);
  return true;
}

num? _ceiling(Map<dynamic, dynamic> permissions, List<String> keys) {
  for (final key in keys) {
    if (!permissions.containsKey(key)) continue;
    final raw = permissions[key];
    if (raw == null) continue;
    final value = raw is num ? raw : num.tryParse('$raw');
    if (value != null && value > 0) return value;
  }
  return null;
}
