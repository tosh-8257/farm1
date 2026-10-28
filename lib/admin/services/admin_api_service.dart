import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '/app_state.dart';
import '/services/auth/session_store_service.dart';
import '../core/admin_config.dart';

class AdminApiService {
  static const int _expiryThresholdSeconds = 60;
  static Completer<bool>? _refreshCompleter;
  static int _consecutiveFailures = 0;
  static DateTime? _nextAllowedRefreshTime;
  static const int _initialBackoffSeconds = 1;
  static const int _maxBackoffSeconds = 30;

  static Future<AuthSession?> _getActiveSession() async {
    var activeRole =
        (await AuthSessionStore.readActiveRole() ?? '').toLowerCase();
    final stateRole = FFAppState().role.toLowerCase();
    if ((stateRole == 'admin' || stateRole == 'super_admin') &&
        activeRole != stateRole) {
      activeRole = stateRole;
    }
    if (activeRole == 'admin' || activeRole == 'super_admin') {
      final storedSession = await AuthSessionStore.readRoleSession(activeRole);
      if (storedSession != null &&
          (storedSession.accessToken.isNotEmpty ||
              storedSession.refreshToken.isNotEmpty)) {
        return storedSession;
      }

      final accessToken = FFAppState().accessToken;
      final refreshToken = FFAppState().refreshToken;
      if (stateRole == activeRole &&
          (accessToken.isNotEmpty || refreshToken.isNotEmpty)) {
        return AuthSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          role: activeRole,
          userId: FFAppState().userId,
          expiresAt: '',
          loggedInAt: '',
        );
      }
    }
    return null;
  }

  static Future<String> _getToken() async {
    debugPrint('Reading admin/super admin session...');
    final session = await _getActiveSession();
    final token = session?.accessToken ?? '';
    final role = session?.role ?? '';
    debugPrint(
        'Resolved session role=$role tokenPresent=${token.isNotEmpty} tokenLength=${token.length}');
    return token;
  }

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<String> _getRefreshToken() async {
    final session = await _getActiveSession();
    return session?.refreshToken ?? '';
  }

  static Future<String> _getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    final session = await _getActiveSession();
    if (session?.role.isNotEmpty ?? false) return session!.role;
    return prefs.getString('adminRole') ?? '';
  }

  static bool tokenNeedsRefresh(String token) {
    final expiry = _getJwtExpiry(token);
    if (expiry == null) {
      return true;
    }
    return expiry.isBefore(
        DateTime.now().add(const Duration(seconds: _expiryThresholdSeconds)));
  }

  static Future<String> getValidAccessToken({bool force = false}) async {
    final valid = await ensureValidSession(force: force);
    if (!valid) return '';
    final session = await _getActiveSession();
    final token = session?.accessToken ?? '';
    if (session != null && token.isNotEmpty) {
      final activeRole =
          (await AuthSessionStore.readActiveRole() ?? '').toLowerCase();
      if (activeRole != session.role.toLowerCase()) {
        await AuthSessionStore.saveRoleSession(
          role: session.role,
          accessToken: token,
          refreshToken: session.refreshToken,
          userId: session.userId,
        );
      }
      // Keep legacy ApiService requests aligned with the role-specific session.
      FFAppState().accessToken = token;
      FFAppState().refreshToken = session.refreshToken;
      FFAppState().role = session.role.toLowerCase();
      FFAppState().userId = session.userId;
      FFAppState().isLoggedIn = true;
    }
    return token;
  }

  static Future<bool> ensureValidSession({bool force = false}) async {
    final token = await _getToken();
    final refreshToken = await _getRefreshToken();
    if (token.isEmpty && refreshToken.isEmpty) {
      return false;
    }
    if (!force && token.isNotEmpty && !tokenNeedsRefresh(token)) {
      return true;
    }
    // Serialize refresh attempts to avoid concurrent refreshes which can
    // trigger server-side refresh-token reuse detection and revoke sessions.
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
      final newToken = await _getToken();
      return newToken.isNotEmpty && !tokenNeedsRefresh(newToken);
    }

    _refreshCompleter = Completer<bool>();
    try {
      // Backoff guard
      final nextAllowed = _nextAllowedRefreshTime;
      if (nextAllowed != null && DateTime.now().isBefore(nextAllowed)) {
        debugPrint(
            '[AdminApiService] Refresh backoff active until $_nextAllowedRefreshTime. Skipping refresh.');
        _refreshCompleter!.complete(false);
        return false;
      }

      final refreshed = await refreshSession();
      if (refreshed) {
        _consecutiveFailures = 0;
        _nextAllowedRefreshTime = null;
        _refreshCompleter!.complete(true);
        return true;
      }

      _consecutiveFailures++;
      final backoffSeconds =
          (_initialBackoffSeconds * (1 << (_consecutiveFailures - 1)))
              .clamp(_initialBackoffSeconds, _maxBackoffSeconds);
      _nextAllowedRefreshTime =
          DateTime.now().add(Duration(seconds: backoffSeconds));
      debugPrint(
          '[AdminApiService] Refresh failed. Applying backoff for $backoffSeconds seconds.');
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      _consecutiveFailures++;
      final backoffSeconds =
          (_initialBackoffSeconds * (1 << (_consecutiveFailures - 1)))
              .clamp(_initialBackoffSeconds, _maxBackoffSeconds);
      _nextAllowedRefreshTime =
          DateTime.now().add(Duration(seconds: backoffSeconds));
      debugPrint(
          '[AdminApiService] Exception during refresh: $e. Backoff $backoffSeconds seconds.');
      if (!_refreshCompleter!.isCompleted) _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  static Future<bool> refreshSession() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken.isEmpty) {
      return false;
    }

    try {
      final resp = await http
          .post(
            Uri.parse('${AdminConfig.api}/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint(
            '[AdminApiService] refresh failed with ${resp.statusCode}: ${resp.body}');
        return false;
      }

      final body = resp.body.isNotEmpty
          ? jsonDecode(resp.body) as Map<String, dynamic>
          : <String, dynamic>{};
      final payload = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;
      final newAccessToken = payload['access_token']?.toString() ?? '';
      final newRefreshToken =
          payload['refresh_token']?.toString() ?? refreshToken;
      final role = await _getStoredRole();
      if (newAccessToken.isEmpty) {
        return false;
      }

      final activeSession = await _getActiveSession();
      await AuthSessionStore.saveRoleSession(
        role: role,
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        userId: activeSession?.userId ?? FFAppState().userId,
      );
      FFAppState().accessToken = newAccessToken;
      FFAppState().refreshToken = newRefreshToken;
      FFAppState().role = role;
      FFAppState().isLoggedIn = true;
      debugPrint('[AdminApiService] admin session refreshed successfully');
      return true;
    } catch (e) {
      debugPrint('[AdminApiService] admin refresh error: $e');
      return false;
    }
  }

  static DateTime? _getJwtExpiry(String token) {
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
      debugPrint('[AdminApiService] Failed to parse admin JWT expiry: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>> _req({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    var token = await _getToken();
    if (token.isEmpty) throw Exception('Not authenticated');

    if (!isRetry && tokenNeedsRefresh(token)) {
      final refreshed = await ensureValidSession(force: true);
      if (refreshed) {
        token = await _getToken();
      }
    }

    if (token.isEmpty) throw Exception('Not authenticated');

    final uri = Uri.parse('${AdminConfig.api}$path');
    late http.Response res;
    switch (method) {
      case 'GET':
        res = await http.get(uri, headers: _headers(token));
        break;
      case 'POST':
        res = await http.post(uri,
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null);
        break;
      case 'PUT':
        res = await http.put(uri,
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        res = await http.patch(uri,
            headers: _headers(token),
            body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        res = await http.delete(uri, headers: _headers(token));
        break;
      default:
        throw Exception('Unknown method');
    }

    if (res.statusCode == 401 && !isRetry) {
      final refreshed = await ensureValidSession(force: true);
      if (refreshed) {
        return _req(method: method, path: path, body: body, isRetry: true);
      }

      final decoded = res.body.isNotEmpty
          ? jsonDecode(res.body) as Map<String, dynamic>
          : <String, dynamic>{};
      throw Exception(decoded['message'] ?? 'Unauthorized');
    }

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    throw Exception(decoded['message'] ?? 'Request failed (${res.statusCode})');
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(
      String identifier, String password) async {
    final res = await http.post(
      Uri.parse('${AdminConfig.api}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final roleValue = decoded['data']?['user']?['role'];
      if (roleValue != 'admin' && roleValue != 'super_admin') {
        throw Exception('Access denied. Admin account required.');
      }
      final accessToken = decoded['data']['access_token']?.toString() ?? '';
      final refreshToken = decoded['data']['refresh_token']?.toString() ?? '';
      final role = roleValue?.toString() ?? '';
      final userId = decoded['data']['user']['id']?.toString() ?? '';
      await AuthSessionStore.saveRoleSession(
        role: role,
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
      );
      FFAppState().accessToken = accessToken;
      FFAppState().refreshToken = refreshToken;
      FFAppState().userId = userId;
      FFAppState().role = role.toLowerCase();
      FFAppState().isLoggedIn = true;
      debugPrint('Admin session saved.');
      debugPrint('Access token length: ${accessToken.length}');
      debugPrint('Refresh token length: ${refreshToken.length}');
      debugPrint('Role: ${role.toUpperCase()}');
      return decoded;
    }
    throw Exception(decoded['message'] ?? 'Login failed');
  }

  static Future<void> logout() async {
    print('LOGOUT CALLED');
    print(StackTrace.current);
    try {
      await _req(method: 'POST', path: '/auth/logout');
    } finally {
      debugPrint(
          '[AdminApiService] explicit logout — clearing persisted admin session keys (reason=explicit logout)');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('adminName');
      await FFAppState().clearAuthCredentials('explicit admin logout');
    }
  }

  static Future<Map<String, dynamic>> _publicReq({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AdminConfig.api}$path'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final decoded = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message'] ?? 'Request failed (${response.statusCode})',
      );
    }
    return decoded;
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboardStats() =>
      _req(method: 'GET', path: '/admin/dashboard');

  static Future<Map<String, dynamic>> getAdmins() =>
      _req(method: 'GET', path: '/admin/admins');

  static Future<Map<String, dynamic>> setAdminStatus(
    String adminId,
    String action,
  ) {
    if (action != 'suspend' && action != 'approve') {
      throw ArgumentError.value(
          action, 'action', 'Expected suspend or approve');
    }
    return _req(
      method: 'PATCH',
      path: '/admin/admins/${Uri.encodeComponent(adminId)}/$action',
    );
  }

  static Future<Map<String, dynamic>> deleteAdmin(String adminId) => _req(
        method: 'DELETE',
        path: '/admin/admins/${Uri.encodeComponent(adminId)}',
      );

  static Future<Map<String, dynamic>> getSuperadmins() =>
      _req(method: 'GET', path: '/admin/superadmin/list');

  static Future<Map<String, dynamic>> createAdmin({
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String email,
    required String country,
    required String password,
  }) =>
      _req(
        method: 'POST',
        path: '/auth/admin/create',
        body: {
          'first_name': firstName,
          'last_name': lastName,
          'username': username,
          'phone': phone,
          'email': email,
          'country': country,
          'password': password,
        },
      );

  static Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      _publicReq(
        path: '/auth/request-password-reset',
        body: {'email': email},
      );

  static Future<Map<String, dynamic>> completePasswordReset({
    required String firebaseIdToken,
    required String password,
    required String confirmPassword,
  }) =>
      _publicReq(
        path: '/auth/password-reset/complete',
        body: {
          'firebase_id_token': firebaseIdToken,
          'password': password,
          'confirm_password': confirmPassword,
        },
      );

  static Future<Map<String, dynamic>> getSupportTickets() =>
      _req(method: 'GET', path: '/admin/support/tickets');

  static Future<Map<String, dynamic>> replyToSupportTicket(
    String ticketId,
    String message,
  ) =>
      _req(
        method: 'POST',
        path: '/admin/support/tickets/${Uri.encodeComponent(ticketId)}/reply',
        body: {'message': message},
      );

  // ── Users ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUsers({
    int page = 1,
    String? search,
    String? role,
    String? kycStatus,
  }) =>
      _req(
        method: 'GET',
        path: '/admin/users?page=$page'
            '${search != null ? "&search=${Uri.encodeQueryComponent(search)}" : ""}'
            '${role != null ? "&role=$role" : ""}'
            '${kycStatus != null ? "&kyc_status=$kycStatus" : ""}',
      );

  static Future<Map<String, dynamic>> getUserDetail(String userId) =>
      _req(method: 'GET', path: '/admin/users/$userId');

  static Future<Map<String, dynamic>> updateUserStatus(
          String userId, Map<String, dynamic> data) =>
      _req(method: 'PATCH', path: '/admin/users/$userId/status', body: data);

  // ── KYC ───────────────────────────────────────────────────────────────────
  static Future<
      Map<String,
          dynamic>> getKycQueue({int page = 1, String? status}) => _req(
      method: 'GET',
      path:
          '/admin/kyc/queue?page=$page${status != null ? "&status=$status" : ""}');

  static Future<Map<String, dynamic>> reviewKyc(String docId, String status,
          {String? rejectionReason}) =>
      _req(
        method: 'POST',
        path: '/admin/kyc/$docId/review',
        body: {
          'status': status,
          if (rejectionReason != null) 'rejection_reason': rejectionReason,
        },
      );

  // ── Transactions ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    String? type,
    String? status,
    String? search,
  }) =>
      _req(
        method: 'GET',
        path: '/admin/transactions?page=$page'
            '${type != null ? "&transaction_type=$type" : ""}'
            '${status != null ? "&status=$status" : ""}'
            '${search != null ? "&search=${Uri.encodeQueryComponent(search)}" : ""}',
      );

  static Future<Map<String, dynamic>> getTransactionDetails(String id) => _req(
        method: 'GET',
        path: '/admin/transactions/${Uri.encodeComponent(id)}',
      );

  // ── Escrow ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getEscrows(
          {int page = 1, String? status}) =>
      _req(
        method: 'GET',
        path: '/admin/escrow?page=$page'
            '${status != null ? "&status=$status" : ""}',
      );

  static Future<Map<String, dynamic>> resolveDispute(
          String escrowId, String winner, String note) =>
      _req(
        method: 'POST',
        path: '/admin/escrow/$escrowId/resolve',
        body: {'winner': winner, 'note': note},
      );

  // ── Deposits ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDeposits(
          {int page = 1, String? status}) =>
      _req(
        method: 'GET',
        path: '/admin/transactions?page=$page&transaction_type=deposit'
            '${status != null ? "&status=$status" : ""}',
      );

  // ── Withdrawals ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWithdrawals(
          {int page = 1, String? status}) =>
      _req(
        method: 'GET',
        path: '/admin/withdrawals?page=$page'
            '${status != null ? "&status=$status" : ""}',
      );

  static Future<Map<String, dynamic>> processWithdrawal(
    String txId,
    String action, {
    String? reason,
  }) =>
      _req(
        method: 'POST',
        path: '/admin/withdrawals/${Uri.encodeComponent(txId)}/process',
        body: {
          'status': action,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );

  static Future<Map<String, dynamic>> getNowpaymentsCryptoWithdrawals() => _req(
        method: 'GET',
        path: '/admin/crypto-withdrawals/pending',
      );

  static Future<Map<String, dynamic>> approveNowpaymentsCryptoWithdrawal(
          String reference) =>
      _req(
        method: 'POST',
        path:
            '/admin/crypto-withdrawals/${Uri.encodeComponent(reference)}/approve',
      );

  static Future<Map<String, dynamic>> verifyNowpaymentsCryptoWithdrawal(
    String reference,
    String verificationCode,
  ) =>
      _req(
        method: 'POST',
        path:
            '/admin/crypto-withdrawals/${Uri.encodeComponent(reference)}/verify',
        body: {'verification_code': verificationCode},
      );

  static Future<
      Map<String,
          dynamic>> getPayouts({int page = 1, String? status}) => _req(
      method: 'GET',
      path:
          '/admin/payouts?page=$page${status != null ? "&status=$status" : ""}');

  static Future<Map<String, dynamic>> processPayout(
          String payoutId, String status) =>
      _req(
          method: 'POST',
          path: '/admin/payouts/$payoutId/process',
          body: {'status': status});

  // ── Merchants ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMerchants(
          {int page = 1, String? status}) =>
      _req(
        method: 'GET',
        path: '/admin/merchants?page=$page'
            '${status != null ? "&status=$status" : ""}',
      );

  static Future<Map<String, dynamic>> decideMerchant(
          String merchantId, String status,
          {String? rejectionReason}) =>
      _req(
        method: 'POST',
        path: '/admin/merchants/$merchantId/decision',
        body: {
          'status': status,
          if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
            'rejection_reason': rejectionReason.trim(),
        },
      );

  static Future<Map<String, dynamic>> getMerchant(String merchantId) =>
      _req(method: 'GET', path: '/admin/merchants/$merchantId');

  static Future<Map<String, dynamic>> getKycDoc(String kycDocId) =>
      _req(method: 'GET', path: '/admin/kyc/$kycDocId');

  // ── Notifications ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> sendNotification(
          Map<String, dynamic> data) =>
      _req(method: 'POST', path: '/admin/notifications/broadcast', body: data);

  // ── Settings ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings() =>
      _req(method: 'GET', path: '/admin/settings');

  static Future<Map<String, dynamic>> updateSetting(String key, String value) =>
      _req(method: 'PUT', path: '/admin/settings/$key', body: {'value': value});

  // ── Fees ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getFees() =>
      _req(method: 'GET', path: '/admin/fees');

  static Future<Map<String, dynamic>> updateFee(String feeId, String value) =>
      _req(method: 'PUT', path: '/admin/fees/$feeId', body: {'value': value});

  // ── Audit logs ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAuditLogs({int page = 1}) =>
      _req(method: 'GET', path: '/admin/audit-logs?page=$page');

  // ── Analytics ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAnalytics({String period = 'week'}) =>
      _req(method: 'GET', path: '/admin/analytics?period=$period');
}
