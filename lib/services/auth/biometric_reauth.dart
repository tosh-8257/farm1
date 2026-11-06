import 'package:flutter/foundation.dart';

import '/app_state.dart';
import '/backend/services/api_service.dart';
import '/services/auth/device_identity.dart';
import '/services/auth/session_store_service.dart';
import '/services/secure_storage_service.dart';

/// Session renewal from `GET /auth/session/config` and
/// `POST /auth/session/biometric`.
///
/// The body is `{ device, refresh_token? }`. `device` is the same signed
/// challenge proof used at login. No SMS code is sent. A disabled or missing
/// route leaves the stored session untouched.
class BiometricReauth {
  static Future<bool> get isEnabled async {
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/auth/session/config',
        requiresAuth: false,
      );
      final data = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      return data['biometric_reauth'] == true;
    } catch (e) {
      debugPrint('[BiometricReauth] session config unavailable: $e');
      return false;
    }
  }

  /// Returns a login-shaped map when the server issued tokens, otherwise null.
  static Future<Map<String, dynamic>?> exchange({String? refreshToken}) async {
    if (!await isEnabled) return null;
    final device = await DeviceIdentity.instance.loginProof();
    if (device == null) return null;
    final refresh = (refreshToken ?? FFAppState().refreshToken).trim();

    Map<String, dynamic> response;
    try {
      response = await ApiService.request(
        method: 'POST',
        path: '/auth/session/biometric',
        requiresAuth: false,
        body: {
          'device': device,
          if (refresh.isNotEmpty) 'refresh_token': refresh,
        },
      );
    } on ApiServiceException catch (e) {
      debugPrint('[BiometricReauth] rejected ${e.statusCode}');
      return null;
    } catch (e) {
      debugPrint('[BiometricReauth] request failed: $e');
      return null;
    }

    final payload = response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : response;
    final access = (payload['access_token'] ?? '').toString();
    final nextRefresh = (payload['refresh_token'] ?? '').toString();
    if (access.isEmpty) return null;

    final effectiveRefresh = nextRefresh.isNotEmpty ? nextRefresh : refresh;
    final user = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : null;
    FFAppState().accessToken = access;
    if (effectiveRefresh.isNotEmpty) {
      FFAppState().refreshToken = effectiveRefresh;
    }
    FFAppState().isLoggedIn = true;
    FFAppState().needsBiometricReauth = false;
    if (user != null) {
      final id = user['id']?.toString() ?? '';
      if (id.isNotEmpty) FFAppState().userId = id;
      final role = user['role']?.toString().toLowerCase() ?? '';
      if (role.isNotEmpty) FFAppState().role = role;
      final name = user['first_name']?.toString() ?? '';
      if (name.isNotEmpty) FFAppState().firstName = name;
      final username = user['username']?.toString() ?? '';
      if (username.isNotEmpty) FFAppState().userName = username;
      final phone = user['phone']?.toString() ?? '';
      if (phone.isNotEmpty) FFAppState().phone = phone;
    }
    await SecureStorageService.writeAccessToken(access);
    if (effectiveRefresh.isNotEmpty) {
      await SecureStorageService.writeRefreshToken(effectiveRefresh);
    }
    final role = FFAppState().role.trim().isEmpty ? 'user' : FFAppState().role;
    FFAppState().role = role;
    try {
      await AuthSessionStore.saveRoleSession(
        role: role,
        accessToken: access,
        refreshToken: effectiveRefresh,
        userId: FFAppState().userId,
      );
    } catch (e) {
      debugPrint('[BiometricReauth] could not persist session: $e');
    }
    return {
      'success': true,
      'data': {
        'access_token': access,
        'refresh_token': effectiveRefresh,
        'requiresPhoneVerification': false,
        'reauth': payload['reauth'] ?? 'biometric',
        if (user != null) 'user': user,
      },
    };
  }
}
