import '/backend/services/api_service.dart';

/// Min and max for one coin, taken only from a backend payload.
/// Missing numbers stay null. The app does not invent a range.
class CoinLimit {
  const CoinLimit({
    required this.currency,
    this.network,
    this.minAmount,
    this.maxAmount,
    this.minUsd,
    this.maxUsd,
    this.feeEstimate,
    this.available,
    this.declared = false,
  });

  final String currency;
  final String? network;
  final double? minAmount;
  final double? maxAmount;
  final double? minUsd;
  final double? maxUsd;
  final double? feeEstimate;

  /// False when the provider is down and the payload is a FARM floor.
  final bool? available;

  /// True when the server published this row, including a row whose
  /// minimum and maximum are null (no limit).
  final bool declared;

  bool get hasAnyBound =>
      minAmount != null || maxAmount != null || minUsd != null || maxUsd != null;

  /// True when [usd] is inside every USD bound the server sent.
  bool allowsUsd(double usd) {
    if (minUsd != null && usd + 1e-9 < minUsd!) return false;
    if (maxUsd != null && usd - 1e-9 > maxUsd!) return false;
    return true;
  }

  String get rangeLabel {
    final coin = currency.toUpperCase();
    final net = (network ?? '').trim();
    final parts = <String>[];
    if (net.isNotEmpty) parts.add(net);
    if (minAmount != null) {
      parts.add('Min $minAmount $coin');
    }
    if (maxAmount != null) {
      parts.add('Max $maxAmount $coin');
    } else if (minAmount != null) {
      parts.add('No maximum published');
    }
    if (minUsd != null) parts.add('Min USD ${_usd(minUsd!)}');
    if (maxUsd != null) parts.add('Max USD ${_usd(maxUsd!)}');
    if (available == false && minUsd != null) {
      parts.add('provider floor');
    }
    if (!hasAnyBound && declared) {
      return 'No minimum or maximum is published for $coin';
    }
    if (parts.isEmpty || (parts.length == 1 && net.isNotEmpty)) {
      return 'Limits for $coin were not returned';
    }
    return parts.join(' · ');
  }
}

String _usd(double v) => v.toStringAsFixed(2);

double? _num(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (n == null || !n.isFinite || n <= 0) return null;
  return n;
}

double? _firstNum(Map map, List<String> keys) {
  for (final k in keys) {
    if (map.containsKey(k)) {
      final n = _num(map[k]);
      if (n != null) return n;
    }
  }
  return null;
}

/// Reads one coin from a backend object. Accepts the shapes the deposit
/// minimum endpoint already returns and the per-coin limit fields the
/// backend can add (`min`/`max`, `minimumUsd`/`maximumUsd`, nested `coins`).
CoinLimit? parseCoinLimit(Object? raw, {String? currency}) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final nested = map['data'];
  if (nested is Map && !map.containsKey('minimumAmount') && !map.containsKey('min')) {
    return parseCoinLimit(nested, currency: currency);
  }
  final code = (map['currency'] ?? map['coin'] ?? map['asset'] ?? map['token'] ?? currency ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final network = (map['network'] ?? map['network_code'] ?? map['chain'] ?? '')
      .toString()
      .trim();
  final available = map.containsKey('available')
      ? map['available'] == true
      : null;
  final declared = map.containsKey('available') ||
      map.containsKey('message') ||
      _explicitNull(map, 'min_amount') ||
      _explicitNull(map, 'max_amount') ||
      _explicitNull(map, 'minimumUsd') ||
      _explicitNull(map, 'min_usd') ||
      _explicitNull(map, 'minimumAmount');
  final limit = CoinLimit(
    currency: code,
    network: network.isEmpty ? null : network,
    minAmount: _firstNum(map, ['min_amount', 'minAmount', 'minimumAmount', 'min', 'minimum_deposit', 'minimum_withdrawal']),
    maxAmount: _firstNum(map, ['max_amount', 'maxAmount', 'maximumAmount', 'max', 'maximum_deposit', 'maximum_withdrawal']),
    minUsd: _firstNum(map, [
      'minUsd',
      'minimumUsd',
      'min_usd',
      'minimum_usd',
      'minimum_deposit_usd',
      'minimumDepositUsd',
    ]),
    maxUsd: _firstNum(map, ['maxUsd', 'maximumUsd', 'max_usd', 'maximum_usd', 'maximum_deposit_usd']),
    feeEstimate: _firstNum(map, ['fee_estimate', 'feeEstimate', 'fee']),
    available: available,
    declared: declared,
  );
  if (!limit.hasAnyBound && !limit.declared) return null;
  if (limit.currency.isEmpty && !limit.hasAnyBound) return null;
  return limit;
}

bool _explicitNull(Map map, String key) => map.containsKey(key) && map[key] == null;

List<CoinLimit> _expandNetworks(Map map, {String? currency}) {
  final networks = map['networks'];
  if (networks is! List || networks.isEmpty) {
    final one = parseCoinLimit(map, currency: currency);
    return one == null ? const [] : [one];
  }
  final out = <CoinLimit>[];
  for (final network in networks) {
    if (network is! Map) continue;
    final row = Map<String, dynamic>.from(network);
    row.putIfAbsent('currency', () => map['currency'] ?? map['coin'] ?? currency);
    final one = parseCoinLimit(row, currency: currency ?? '${map['currency'] ?? ''}');
    if (one != null) out.add(one);
  }
  return out;
}

/// A limits payload may be one coin or a list under `coins` / `data`.
/// A coin may also carry a `networks` list with its own min and max.
List<CoinLimit> parseCoinLimitList(Object? raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    if (map['networks'] is List) return _expandNetworks(map);
    final list = map['coins'] ?? map['limits'] ?? map['currencies'] ?? map['assets'];
    if (list is List) return parseCoinLimitList(list);
    final data = map['data'];
    if (data is List) return parseCoinLimitList(data);
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      if (inner['networks'] is List) return _expandNetworks(inner);
      final innerList = inner['coins'] ?? inner['limits'] ?? inner['assets'];
      if (innerList is List) return parseCoinLimitList(innerList);
      if (innerList is Map) return _limitsFromCoinMap(innerList);
      final one = parseCoinLimit(inner);
      return one == null ? const [] : [one];
    }
    final one = parseCoinLimit(map);
    return one == null ? const [] : [one];
  }
  if (raw is List) {
    return raw.map(parseCoinLimit).whereType<CoinLimit>().toList();
  }
  return const [];
}

List<CoinLimit> _limitsFromCoinMap(Map<dynamic, dynamic> raw) {
  final out = <CoinLimit>[];
  raw.forEach((key, value) {
    if (value is! Map) return;
    final row = Map<String, dynamic>.from(value);
    row.putIfAbsent('currency', () => '$key');
    out.addAll(_expandNetworks(row, currency: '$key'));
  });
  return out;
}

CoinLimit? limitFor(List<CoinLimit> limits, String currency, {String? network}) {
  final code = currency.trim().toLowerCase();
  final net = network?.trim().toLowerCase();
  final matches = limits.where((limit) => limit.currency == code || limit.currency.isEmpty).toList();
  if (net != null && net.isNotEmpty) {
    for (final limit in matches) {
      if ((limit.network ?? '').toLowerCase() == net) return _withCurrency(limit, code);
    }
    if (matches.length == 1 && (matches.first.network ?? '').isEmpty) {
      return _withCurrency(matches.first, code);
    }
    if (matches.length > 1) return null;
  }
  if (matches.length == 1) return _withCurrency(matches.first, code);
  final withNetwork = matches.where((limit) => (limit.network ?? '').isNotEmpty).toList();
  if (withNetwork.length > 1 && (net == null || net.isEmpty)) return null;
  if (matches.isNotEmpty) return _withCurrency(matches.first, code);
  return null;
}

CoinLimit _withCurrency(CoinLimit limit, String code) {
  if (limit.currency.isNotEmpty) return limit;
  return CoinLimit(
    currency: code,
    network: limit.network,
    minAmount: limit.minAmount,
    maxAmount: limit.maxAmount,
    minUsd: limit.minUsd,
    maxUsd: limit.maxUsd,
    feeEstimate: limit.feeEstimate,
    available: limit.available,
    declared: limit.declared,
  );
}

String _withNetwork(String path, String? network) {
  final net = network?.trim() ?? '';
  if (net.isEmpty) return path;
  final join = path.contains('?') ? '&' : '?';
  return '$path$join${'network=${Uri.encodeQueryComponent(net)}'}';
}

Future<List<CoinLimit>> _limitsAt(List<String> paths, String currency, {String? network}) async {
  final code = currency.trim().toLowerCase();
  Object? lastError;
  for (final path in paths) {
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: _withNetwork(path, network),
        requiresAuth: true,
      );
      final many = parseCoinLimitList(response);
      final matched = many.where((limit) => limit.currency == code || limit.currency.isEmpty).toList();
      if (matched.isNotEmpty) {
        return matched.map((limit) => _withCurrency(limit, code)).toList();
      }
      final one = parseCoinLimit(response, currency: code);
      if (one != null && (one.hasAnyBound || one.declared)) {
        return [_withCurrency(one, code)];
      }
    } on ApiServiceException catch (e) {
      lastError = e;
      if (e.statusCode == 404 || e.statusCode == 405) continue;
      rethrow;
    }
  }
  if (lastError != null) throw lastError;
  return const [];
}

/// Deposit bounds for [currency], including one row per network when the
/// payload has them. A missing USD minimum is not an error.
Future<List<CoinLimit>> fetchDepositCoinLimits(String currency, {String? network}) async {
  final code = currency.trim().toLowerCase();
  final limits = await _limitsAt([
    '/wallet/deposit/crypto/limits/${Uri.encodeQueryComponent(code)}',
    '/wallet/deposit/crypto/minimum/${Uri.encodeQueryComponent(code)}',
    '/wallet/deposit/crypto/limits',
  ], code, network: network);
  if (limits.isEmpty || limits.every((limit) => !limit.hasAnyBound && !limit.declared)) {
    throw const FormatException('Deposit limits for this coin were not returned.');
  }
  return limits;
}

Future<CoinLimit> fetchDepositCoinLimit(String currency, {String? network}) async {
  final limits = await fetchDepositCoinLimits(currency, network: network);
  final match = limitFor(limits, currency, network: network);
  if (match == null || !match.hasAnyBound) {
    throw const FormatException('Deposit limits for this coin were not returned.');
  }
  return match;
}

/// Withdrawal bounds for [currency]. One entry per network when the payload
/// includes them. A missing USD minimum is left null.
Future<List<CoinLimit>> fetchWithdrawCoinLimits(String currency, {String? network}) async {
  final code = currency.trim().toLowerCase();
  final limits = await _limitsAt([
    '/withdraw/crypto/limits/${Uri.encodeQueryComponent(code)}',
  ], code, network: network);
  if (limits.isEmpty || limits.every((limit) => !limit.hasAnyBound && !limit.declared)) {
    throw const FormatException('Withdrawal limits for this coin were not returned.');
  }
  return limits;
}

/// Algorand receive limits. Null bounds mean no published limit.
/// A missing route (older server) returns an empty list.
Future<List<CoinLimit>> fetchChainLimits() async {
  try {
    final response = await ApiService.request(
      method: 'GET',
      path: '/wallet/chain/limits',
      requiresAuth: true,
    );
    final many = parseCoinLimitList(response);
    if (many.isNotEmpty) return many;
    final one = parseCoinLimit(response);
    return one == null ? const [] : [one];
  } on ApiServiceException catch (e) {
    if (e.statusCode == 404 || e.statusCode == 405) return const [];
    rethrow;
  }
}

Future<CoinLimit> fetchWithdrawCoinLimit(String currency, {String? network}) async {
  final limits = await fetchWithdrawCoinLimits(currency, network: network);
  final match = limitFor(limits, currency, network: network);
  if (match == null || !match.hasAnyBound) {
    throw const FormatException('Withdrawal limits for this coin were not returned.');
  }
  return match;
}
