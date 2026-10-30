import '/backend/services/api_service.dart';

/// Live fee schedule from the backend (GET /fees). Rates are never hardcoded in the app.
class FeeRule {
  FeeRule(this.key, this.label, this.percent, this.flat, this.min, this.max, this.payer);
  final String key;
  final String label;
  final double percent;
  final double flat;
  final double min;
  final double max; // 0 = no cap
  final String? payer;

  /// Same maths as the backend: percent + flat, floored at min, capped at max (0 = no cap).
  double feeFor(double amount, {int dp = 2}) {
    if (!(amount > 0)) return 0;
    var f = amount * percent / 100 + flat;
    if (min > 0 && f < min) f = min;
    if (max > 0 && f > max) f = max;
    final m = _pow10(dp);
    return (f * m).roundToDouble() / m;
  }

  String get percentLabel =>
      percent == percent.roundToDouble() ? '${percent.toStringAsFixed(0)}%' : '${percent.toString()}%';

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }
}

class FeesApi {
  static Map<String, FeeRule>? _cache;
  static DateTime? _at;

  static double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static Map<String, FeeRule> parse(dynamic body) {
    final list = body is Map && body['data'] is List ? body['data'] as List : (body is List ? body : const []);
    final out = <String, FeeRule>{};
    for (final e in list) {
      if (e is! Map) continue;
      final k = '${e['key'] ?? ''}';
      if (k.isEmpty) continue;
      out[k] = FeeRule(k, '${e['label'] ?? k}', _n(e['percent']), _n(e['flat']), _n(e['min']), _n(e['max']),
          e['payer']?.toString());
    }
    return out;
  }

  /// Cached for 60s. Throws when the schedule can't be loaded (callers show an error, never a guessed rate).
  static Future<Map<String, FeeRule>> schedule({bool refresh = false}) async {
    if (!refresh && _cache != null && _at != null && DateTime.now().difference(_at!) < const Duration(seconds: 60)) {
      return _cache!;
    }
    final m = parse(await ApiService.request(method: 'GET', path: '/fees'));
    if (m.isEmpty) throw Exception('Fee schedule unavailable');
    _cache = m;
    _at = DateTime.now();
    return m;
  }

  static Future<FeeRule> rule(String key) async {
    final r = (await schedule())[key];
    if (r == null) throw Exception('Fee "$key" unavailable');
    return r;
  }

  static void clear() => _cache = null;
}
