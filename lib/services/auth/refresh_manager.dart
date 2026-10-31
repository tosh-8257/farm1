import '/services/auth/device_identity.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '/app_state.dart';
import 'session_store_service.dart';
import '/core/app_config.dart';
import '/services/secure_storage_service.dart';

class RefreshManager {
  static final RefreshManager _instance = RefreshManager._internal();
  factory RefreshManager() => _instance;
  RefreshManager._internal();

  static const int _expiryThresholdSeconds = 5 * 60;
  http.Client _client = http.Client();
  static const int _initialBackoffSeconds = 1;
  static const int _maxBackoffSeconds = 30;

  Completer<bool>? _refreshCompleter;
  int _consecutiveFailures = 0;
  DateTime? _nextAllowedRefreshTime;
  bool _lastFailureWasRevocation = false;

  bool get lastFailureWasRevocation => _lastFailureWasRevocation;

  static set client(http.Client value) => _instance._client = value;

  bool get isRefreshing => _refreshCompleter != null;

  bool get _hasRefreshToken => FFAppState().refreshToken.trim().isNotEmpty;
  bool get _hasAccessToken => FFAppState().accessToken.trim().isNotEmpty;

  bool get _isBackoffActive {
    final nextAllowed = _nextAllowedRefreshTime;
    return nextAllowed != null && DateTime.now().isBefore(nextAllowed);
  }

  Future<bool> refreshIfNeeded({bool force = false}) async {
    if (!_hasRefreshToken) {
      debugPrint(
          '[RefreshManager] No refresh token available. Skipping refresh.');
      return false;
    }

    if (isRefreshing) {
      debugPrint(
          '[RefreshManager] Refresh already in progress. Waiting for existing refresh.');
      await _refreshCompleter!.future;
      return _hasAccessToken;
    }

    if (!force && !_tokenNeedsRefresh()) {
      debugPrint('[RefreshManager] Access token does not need refresh yet.');
      return true;
    }

    if (_isBackoffActive) {
      debugPrint(
          '[RefreshManager] Refresh backoff active until $_nextAllowedRefreshTime. Skipping refresh.');
      return false;
    }

    return _performRefresh();
  }

  Future<bool> _performRefresh() async {
    _refreshCompleter = Completer<bool>();
    try {
      final result = await _doRefresh();
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(result);
      }
      return result;
    } catch (e) {
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _doRefresh() async {
    _lastFailureWasRevocation = false;
    final refreshToken = FFAppState().refreshToken.trim();
    if (refreshToken.isEmpty) {
      debugPrint('[RefreshManager] refresh token empty, cannot refresh.');
      return false;
    }

    debugPrint(
      '[RefreshManager] Starting token refresh (failures=$_consecutiveFailures).',
    );

    String? deviceId;
    try {
      deviceId = await DeviceIdentity.instance.deviceId();
    } catch (_) {
      deviceId = null;
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${AppConfig.api}/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'refresh_token': refreshToken,
              if (deviceId != null) 'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = response.body.isNotEmpty
            ? jsonDecode(response.body) as Map<String, dynamic>
            : <String, dynamic>{};
        final payload = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body;
        final newAccessToken = payload['access_token'] as String? ?? '';
        final newRefreshToken = payload['refresh_token'] as String? ?? '';

        if (newAccessToken.isEmpty) {
          debugPrint(
              '[RefreshManager] Refresh succeeded but returned no access token.');
          _registerFailure();
          return false;
        }

        FFAppState().accessToken = newAccessToken;
        FFAppState().isLoggedIn = true;
        final effectiveRefreshToken =
            newRefreshToken.isNotEmpty ? newRefreshToken : refreshToken;
        FFAppState().refreshToken = effectiveRefreshToken;
        await SecureStorageService.writeAccessToken(newAccessToken);
        await SecureStorageService.writeRefreshToken(effectiveRefreshToken);

        // Persist refreshed tokens into role-specific session store so that
        // admin/superadmin sessions and other persisted sessions are kept
        // in sync with the in-memory token state.
        try {
          final role = FFAppState().role;
          if (role.isNotEmpty) {
            await AuthSessionStore.saveRoleSession(
              role: role,
              accessToken: newAccessToken,
              refreshToken: effectiveRefreshToken,
              userId: FFAppState().userId,
            );
          }
        } catch (e) {
          debugPrint('[RefreshManager] Failed to persist refreshed tokens: $e');
        }

        _consecutiveFailures = 0;
        _nextAllowedRefreshTime = null;
        debugPrint('[RefreshManager] Token refresh succeeded.');
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        _lastFailureWasRevocation = true;
        debugPrint(
            '[AUTH REFRESH] Persistent refresh session rejected by backend.');
        _registerFailure();
        return false;
      }

      debugPrint(
        '[RefreshManager] Refresh request failed with status ${response.statusCode}. Keeping existing auth state.',
      );
      _registerFailure();
      return false;
    } catch (e) {
      debugPrint(
          '[RefreshManager] Refresh request failed: $e. Preserving existing auth state.');
      _registerFailure();
      return false;
    }
  }

  void reset() {
    _consecutiveFailures = 0;
    _nextAllowedRefreshTime = null;
    _refreshCompleter = null;
    _lastFailureWasRevocation = false;
  }

  void _registerFailure() {
    _consecutiveFailures++;
    final backoffSeconds = min(
      _initialBackoffSeconds * pow(2, _consecutiveFailures - 1).toInt(),
      _maxBackoffSeconds,
    );
    _nextAllowedRefreshTime =
        DateTime.now().add(Duration(seconds: backoffSeconds));
    debugPrint(
        '[RefreshManager] Next refresh allowed after $_nextAllowedRefreshTime.');
  }

  bool _tokenNeedsRefresh() {
    final token = FFAppState().accessToken.trim();
    if (token.isEmpty) {
      return true;
    }

    final expiry = _getJwtExpiry(token);
    if (expiry == null) {
      return true;
    }

    return expiry.isBefore(
        DateTime.now().add(const Duration(seconds: _expiryThresholdSeconds)));
  }

  DateTime? _getJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      var normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final decoded = utf8.decode(base64Url.decode(normalized));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
            .toLocal();
      }
      if (exp is String) {
        final expInt = int.tryParse(exp);
        if (expInt != null) {
          return DateTime.fromMillisecondsSinceEpoch(expInt * 1000, isUtc: true)
              .toLocal();
        }
      }
    } catch (e) {
      debugPrint('[RefreshManager] Failed to parse JWT expiry: $e');
    }
    return null;
  }
}
