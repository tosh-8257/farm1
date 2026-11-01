import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small persistent stale-while-revalidate store for read-only screen data
/// (balances, recent transactions, business pages).
///
/// - Values are JSON, kept in memory after [load] so reads are synchronous
///   (first frame can paint cached data with no spinner).
/// - Scoped per user id; [clear] runs on logout so another account never sees
///   this one's data.
/// - Display only. Money actions (send, withdraw, pay, payouts) must always
///   use a fresh server response, never this cache.
class OfflineCache {
  OfflineCache._();
  static const _prefix = 'swr:v1:';
  static const _maxBytes = 200 * 1024; // per entry
  static final Map<String, Object?> _mem = {};
  static String _scope = '';
  static SharedPreferences? _prefs;

  /// Loads the cached entries for [userId] into memory. Cheap: one prefs read.
  static Future<void> load(String userId, {SharedPreferences? prefs}) async {
    _scope = userId;
    _mem.clear();
    try {
      _prefs = prefs ?? await SharedPreferences.getInstance();
      if (userId.isEmpty || _scope != userId) return;
      final head = '$_prefix$userId:';
      for (final k in _prefs!.getKeys()) {
        if (!k.startsWith(head)) continue;
        final raw = _prefs!.getString(k);
        if (raw == null) continue;
        try {
          _mem[k.substring(head.length)] = jsonDecode(raw);
        } catch (_) {
          unawaited(_prefs!.remove(k));
        }
      }
    } catch (e) {
      debugPrint('[OfflineCache] load skipped: $e');
    }
  }

  /// Switches scope when the signed-in user changes (e.g. after login).
  static Future<void> ensureScope(String userId) async {
    if (userId == _scope && _prefs != null) return;
    await load(userId);
  }

  static Object? read(String key) => _mem[key];

  static Map<String, dynamic>? readMap(String key) {
    final v = _mem[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  static bool has(String key) => _mem.containsKey(key);

  /// Stores [value] (JSON-encodable) for the current user. Fire and forget.
  static void write(String key, Object? value) {
    if (_scope.isEmpty || value == null) return;
    try {
      final raw = jsonEncode(value);
      if (raw.length > _maxBytes) return;
      _mem[key] = jsonDecode(raw);
      unawaited(_prefs?.setString('$_prefix$_scope:$key', raw));
    } catch (_) {
      // Not JSON-encodable: skip caching, never break the caller.
    }
  }

  /// Removes every cached entry for every user (logout).
  static Future<void> clear() async {
    _mem.clear();
    _scope = '';
    try {
      final p = _prefs ?? await SharedPreferences.getInstance();
      for (final k in p.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
        await p.remove(k);
      }
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTest() {
    _mem.clear();
    _scope = '';
    _prefs = null;
  }
}
