import '/backend/services/api_service.dart';

/// Min and max for one coin, taken only from a backend payload.
/// Missing numbers stay null. The app does not invent a range.
class CoinLimit {
  const CoinLimit({
    required this.currency,
    this.minAmount,
    this.maxAmount,
    this.minUsd,
    this.maxUsd,
  });

  final String currency;
  final double? minAmount;
  final double? maxAmount;
  final double? minUsd;
  final double? maxUsd;

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
    final parts = <String>[];
    if (minAmount != null) {
      parts.add('Min $minAmount $coin');
    } else if (minUsd != null) {
      parts.add('Min USD ${_usd(minUsd!)}');
    }
    if (maxAmount != null) {
      parts.add('Max $maxAmount $coin');
    } else if (maxUsd != null) {
      parts.add('Max USD ${_usd(maxUsd!)}');
    }
    if (minUsd != null && minAmount != null) {
      parts.add('at least USD ${_usd(minUsd!)}');
    }
    if (maxUsd != null && maxAmount != null) {
      parts.add('at most USD ${_usd(maxUsd!)}');
    }
    if (parts.isEmpty) return 'Limits for $coin were not returned';
    return parts.join(' · ');
  }
}

String _usd(double v) => v.toStringAsFixed(2);

double? _num(Object? v) {
  if (v == null) return null;
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (n == null || !n.isFinite || n < 0) return null;
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
  final limit = CoinLimit(
    currency: code,
    minAmount: _firstNum(map, ['min_amount', 'minAmount', 'minimumAmount', 'min']),
    maxAmount: _firstNum(map, ['max_amount', 'maxAmount', 'maximumAmount', 'max']),
    minUsd: _firstNum(map, ['minUsd', 'minimumUsd', 'min_usd', 'minimum_usd']),
    maxUsd: _firstNum(map, ['maxUsd', 'maximumUsd', 'max_usd', 'maximum_usd']),
  );
  if (limit.currency.isEmpty && !limit.hasAnyBound) return null;
  if (!limit.hasAnyBound && limit.currency.isEmpty) return null;
  return limit.hasAnyBound ? limit : null;
}

/// A limits payload may be one coin or a list under `coins` / `data`.
List<CoinLimit> parseCoinLimitList(Object? raw) {
  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    final list = map['coins'] ?? map['limits'] ?? map['currencies'];
    if (list is List) return parseCoinLimitList(list);
    final data = map['data'];
    if (data is List) return parseCoinLimitList(data);
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      final innerList = inner['coins'] ?? inner['limits'];
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
    final one = parseCoinLimit(row, currency: '$key');
    if (one != null) out.add(one);
  });
  return out;
}

CoinLimit? limitFor(List<CoinLimit> limits, String currency) {
  final code = currency.trim().toLowerCase();
  for (final limit in limits) {
    if (limit.currency == code) return limit;
  }
  if (limits.length == 1 && limits.first.currency.isEmpty) {
    return CoinLimit(
      currency: code,
      minAmount: limits.first.minAmount,
      maxAmount: limits.first.maxAmount,
      minUsd: limits.first.minUsd,
      maxUsd: limits.first.maxUsd,
    );
  }
  return null;
}

Future<CoinLimit?> _firstLimit(List<String> paths, String currency) async {
  final code = currency.trim().toLowerCase();
  Object? lastError;
  for (final path in paths) {
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: path,
        requiresAuth: true,
      );
      final many = parseCoinLimitList(response);
      final match = limitFor(many, code);
      if (match != null) return match;
      final one = parseCoinLimit(response, currency: code);
      if (one != null) {
        return CoinLimit(
          currency: one.currency.isEmpty ? code : one.currency,
          minAmount: one.minAmount,
          maxAmount: one.maxAmount,
          minUsd: one.minUsd,
          maxUsd: one.maxUsd,
        );
      }
    } on ApiServiceException catch (e) {
      lastError = e;
      if (e.statusCode == 404 || e.statusCode == 405) continue;
      rethrow;
    }
  }
  if (lastError != null) throw lastError;
  return null;
}

/// Deposit bounds for [currency]. Tries the per-coin limits route, then the
/// existing NOWPayments minimum route. Throws if every route fails.
Future<CoinLimit> fetchDepositCoinLimit(String currency) async {
  final code = currency.trim().toLowerCase();
  final limit = await _firstLimit([
    '/wallet/deposit/crypto/limits/${Uri.encodeQueryComponent(code)}',
    '/wallet/deposit/crypto/limits',
  ], code);
  if (limit == null || !limit.hasAnyBound) {
    throw const FormatException('Deposit limits for this coin were not returned.');
  }
  return limit;
}

/// Withdrawal bounds for [currency]. The legacy minimum route is global USD;
/// a per-coin payload replaces it when the backend sends one.
Future<CoinLimit> fetchWithdrawCoinLimit(String currency) async {
  final code = currency.trim().toLowerCase();
  final limit = await _firstLimit([
    '/withdraw/crypto/limits/${Uri.encodeQueryComponent(code)}',
  ], code);
  if (limit == null || !limit.hasAnyBound) {
    throw const FormatException('Withdrawal limits for this coin were not returned.');
  }
  return limit;
}
