import '/services/auth/device_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/core/config/supabase_config.dart';
import '/core/config/env.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/services/api_service.dart';
import '/backend/services/turnstile_payload.dart';
import '/services/auth/refresh_manager.dart';
import '/services/app_session_manager.dart';
import '/services/notification_service.dart';
import '/services/auth/session_store_service.dart';
import '/services/biometric_lock_service.dart';

/// Centralized authentication service for the FARM app.
///
/// This service handles:
/// 1. Supabase authentication (signUp, login, logout, etc.)
/// 2. FARM backend JWT exchange and management
/// 3. Session refresh and verification
///
/// Registration Flow:
/// Flutter → Supabase → Verification Email → User verifies
/// → Flutter receives session → Backend creates user/wallet
/// → Backend issues FARM JWT
///
/// Login Flow:
/// Flutter → Supabase Login → Access Token
/// → POST /auth/supabase → Backend verifies → Issues FARM JWT
/// → Flutter stores FARM JWT → Dashboard
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  static Map<String, dynamic> normalizeLoginResponse(
      Map<String, dynamic> response) {
    final rawData = response['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    final user = data['user'];
    final normalizedUser =
        user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{};

    return {
      'success': true,
      'farmJwt': data['access_token']?.toString() ?? '',
      'refreshToken': data['refresh_token']?.toString() ?? '',
      'requiresPhoneVerification': data['requiresPhoneVerification'] == true,
      'pendingLoginId': data['pendingLoginId']?.toString() ?? '',
      'phone': data['phone']?.toString() ?? '',
      'user': normalizedUser,
      'loginMethod': 'backend',
      'data': data,
    };
  }

  SupabaseClient get _supabase => SupabaseConfig.client;

  /// Register a new FARM account and start backend phone verification.
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    String? country,
    String? referralCode,
    String? turnstileToken,
  }) async {
    try {
      return await ApiService.register(
        firstName: firstName,
        lastName: lastName,
        username: username,
        phone: phone,
        password: password,
        email: email,
        country: country,
        referralCode: referralCode,
        turnstileToken: turnstileToken,
      );
    } on AuthException catch (e) {
      throw Exception('Sign up error: ${e.message}');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  /// Log in with email or phone and password.
  ///
  /// Email-based login continues to use Supabase + backend token exchange.
  /// Phone/username login uses the backend login route directly.
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? turnstileToken,
    String? countryCode,
  }) async {
    try {
      final normalizedIdentifier = identifier.trim();

      final Map<String, dynamic> response;
      try {
        response = await ApiService.login(
          identifier: normalizedIdentifier,
          password: password,
          turnstileToken: turnstileToken,
          countryCode: countryCode,
          device: await DeviceIdentity.instance.loginProof(),
        );
      } on ApiServiceException catch (e) {
        final pendingId = e.data?['pending_device_id']?.toString();
        if (e.code == 'NEW_DEVICE' && pendingId != null) {
          throw NewDeviceRequiredException(pendingId);
        }
        rethrow;
      }

      final normalized = normalizeLoginResponse(response);
      final responseData = normalized['data'] as Map<String, dynamic>? ?? {};
      final farmJwt = normalized['farmJwt'] as String? ?? '';
      final refreshToken = normalized['refreshToken'] as String? ?? '';
      final backendUser = responseData['user'] is Map<String, dynamic>
          ? responseData['user'] as Map<String, dynamic>
          : (responseData['user'] is Map
              ? Map<String, dynamic>.from(responseData['user'] as Map)
              : null);

      // The backend decides whether this account needs phone verification.
      if (farmJwt.isNotEmpty) {
        await _persistSessionTokens(
          farmJwt: farmJwt,
          refreshToken: refreshToken,
          backendUser: backendUser,
        );
        final role = backendUser?['role']?.toString().toLowerCase() ?? '';
        if (role == 'user') {
          await NotificationService.registerForCurrentUser();
        }
      }

      return normalized;
    } on NewDeviceRequiredException {
      rethrow;
    } on AuthException catch (e) {
      throw Exception('Login error: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<Map<String, dynamic>> completeFirebaseLogin({
    required String identifier,
    required String firebaseToken,
    String? countryCode,
    String? turnstileToken,
  }) async {
    try {
      final Map<String, dynamic> response;
      try {
        response = await ApiService.completeFirebaseLogin(
          identifier: identifier,
          firebaseToken: firebaseToken,
          countryCode: countryCode,
          turnstileToken: turnstileToken,
          device: await DeviceIdentity.instance.loginProof(),
        );
      } on ApiServiceException catch (e) {
        final pendingId = e.data?['pending_device_id']?.toString();
        if (e.code == 'NEW_DEVICE' && pendingId != null) {
          throw NewDeviceRequiredException(pendingId);
        }
        rethrow;
      }

      final responseData = response['data'] as Map<String, dynamic>? ?? {};
      final farmJwt = responseData['access_token'] as String? ?? '';
      final refreshToken = responseData['refresh_token'] as String? ?? '';
      final backendUser = responseData['user'] as Map<String, dynamic>?;

      if (farmJwt.isNotEmpty) {
        await _persistSessionTokens(
          farmJwt: farmJwt,
          refreshToken: refreshToken,
          backendUser: backendUser,
        );
        await NotificationService.registerForCurrentUser();
      }

      return {
        'success': true,
        'farmJwt': farmJwt,
        'refreshToken': refreshToken,
        'user': backendUser,
        'loginMethod': 'firebase',
      };
    } on NewDeviceRequiredException {
      rethrow;
    } catch (e) {
      throw Exception('Firebase login failed: $e');
    }
  }

  /// Verify phone with backend using the Firebase ID token.
  Future<Map<String, dynamic>> verifyPhone({
    required String firebaseIdToken,
    required String pendingLoginId,
    String? turnstileToken,
  }) async {
    try {
      final response = await ApiService.verifyPhone(
        firebaseIdToken: firebaseIdToken,
        pendingLoginId: pendingLoginId,
        turnstileToken: turnstileToken,
      );

      final responseData = response['data'] as Map<String, dynamic>? ?? {};
      final farmJwt = responseData['access_token'] as String? ?? '';
      final refreshToken = responseData['refresh_token'] as String? ?? '';
      final backendUser = responseData['user'] as Map<String, dynamic>?;

      if (farmJwt.isNotEmpty) {
        await _persistSessionTokens(
          farmJwt: farmJwt,
          refreshToken: refreshToken,
          backendUser: backendUser,
        );
        await NotificationService.registerForCurrentUser();
      }

      return {
        'success': true,
        'farmJwt': farmJwt,
        'refreshToken': refreshToken,
        'user': backendUser,
      };
    } catch (e) {
      throw Exception('Phone verification failed: $e');
    }
  }

  Future<void> registerFcmToken() async {
    await NotificationService.registerForCurrentUser();
  }

  Future<void> _persistSessionTokens({
    required String farmJwt,
    required String refreshToken,
    required Map<String, dynamic>? backendUser,
  }) async {
    final role = backendUser is Map<String, dynamic>
        ? backendUser['role']?.toString().toLowerCase() ?? ''
        : '';
    final normalizedRole = role.isEmpty ? 'user' : role;

    if (normalizedRole == 'admin') {
      FFAppState().accessToken = farmJwt;
      FFAppState().refreshToken = refreshToken;
      FFAppState().isLoggedIn = true;
      FFAppState().userId = backendUser?['id']?.toString() ?? '';
      FFAppState().role = normalizedRole;

      debugPrint('Admin login detected.');
      debugPrint('Saving AdminSession...');
      debugPrint('Access token length: ${farmJwt.length}');
      debugPrint('Refresh token length: ${refreshToken.length}');
      debugPrint('Role: ADMIN');
      await AuthSessionStore.saveAdminSession(
        accessToken: farmJwt,
        refreshToken: refreshToken,
        role: normalizedRole,
        userId: backendUser?['id']?.toString() ?? '',
      );
      debugPrint('Skipping biometric setup.');
      return;
    }

    if (normalizedRole == 'super_admin') {
      FFAppState().accessToken = farmJwt;
      FFAppState().refreshToken = refreshToken;
      FFAppState().isLoggedIn = true;
      FFAppState().userId = backendUser?['id']?.toString() ?? '';
      FFAppState().role = normalizedRole;

      debugPrint('Super admin login detected.');
      debugPrint('Saving SuperAdminSession...');
      debugPrint('Access token length: ${farmJwt.length}');
      debugPrint('Refresh token length: ${refreshToken.length}');
      debugPrint('Role: SUPER_ADMIN');
      await AuthSessionStore.saveSuperAdminSession(
        accessToken: farmJwt,
        refreshToken: refreshToken,
        role: normalizedRole,
        userId: backendUser?['id']?.toString() ?? '',
      );
      debugPrint('Skipping biometric setup.');
      return;
    }

    final backendData = backendUser!;
    FFAppState().accessToken = farmJwt;
    FFAppState().refreshToken = refreshToken;
    FFAppState().isLoggedIn = farmJwt.isNotEmpty;
    FFAppState().userId = backendData['id']?.toString() ?? '';
    FFAppState().firstName = backendData['first_name']?.toString() ?? '';
    FFAppState().userName = backendData['username']?.toString() ?? '';
    FFAppState().phone = backendData['phone']?.toString() ?? '';
    FFAppState().kycStatus = backendData['kyc_status']?.toString() ?? '';
    FFAppState().emailVerified = backendData['email_verified'] == true;
    FFAppState().role = normalizedRole;
    await AuthSessionStore.saveUserSession(
      accessToken: farmJwt,
      refreshToken: refreshToken,
      role: normalizedRole,
      userId: backendData['id']?.toString() ?? '',
    );

    debugPrint(
        '[AuthService] Login completed. Starting background user syncNow.');
    Future.microtask(() {
      return AppSessionManager().syncNow().catchError((e) {
        debugPrint('[AuthService] syncNow background refresh failed: $e');
      });
    });
  }

  /// Exchange Supabase token for FARM backend JWT.
  ///
  /// This calls the backend /auth/supabase endpoint which:
  /// 1. Verifies the Supabase token
  /// 2. Creates or updates the FARM user
  /// 3. Creates a wallet if needed
  /// 4. Issues a FARM JWT for API authentication
  ///
  /// Public method used by AuthService.login() and BiometricLoginService.
  Future<Map<String, dynamic>> exchangeSupabaseToken(
    String supabaseToken, {
    String? turnstileToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${Env.api}/auth/supabase'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseToken',
        },
        body: jsonEncode(
          attachTurnstileToken(
            {'supabase_token': supabaseToken},
            turnstileToken: turnstileToken,
          ),
        ),
      );

      final bodyData = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final message = bodyData['message'] ?? response.body;
        throw Exception(
            'Token exchange failed: ${response.statusCode} - $message');
      }

      final payload = bodyData['data'] is Map<String, dynamic>
          ? bodyData['data'] as Map<String, dynamic>
          : bodyData;

      return payload;
    } catch (e) {
      throw Exception('Failed to exchange token: $e');
    }
  }

  /// Log out the user from Supabase and FARM backend, and clear all local auth data.
  Future<void> logout() async {
    print('LOGOUT CALLED');
    print(StackTrace.current);
    Exception? logoutError;

    if (FFAppState().isUser && FFAppState().biometricsEnabled) {
      try {
        await BiometricLockService().disableBiometrics();
      } catch (e) {
        debugPrint('Could not unregister biometrics during logout: $e');
      }
    }

    try {
      await ApiService.revokeAllSessions();
    } catch (e) {
      debugPrint('Backend revoke-all error: $e');
      try {
        await ApiService.logout();
      } catch (e2) {
        debugPrint('Backend logout fallback error: $e2');
        logoutError = Exception('Backend logout failed: $e2');
      }
    }

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error: $e');
      logoutError = Exception('Supabase logout failed: $e');
    }

    try {
      await FFAppState().clearAuthCredentials();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', 'en');
    } catch (e) {
      debugPrint('Local clear auth data error: $e');
      logoutError = Exception('Local logout cleanup failed: $e');
    }

    if (logoutError != null) {
      debugPrint('Logout completed with errors: ${logoutError.toString()}');
    }
  }

  Future<void> deleteAccount({
    required String password,
    required bool acknowledged,
    required bool confirmDelete,
  }) async {
    print('LOGOUT CALLED');
    print(StackTrace.current);
    try {
      await ApiService.deleteAccount(
        body: {
          'password': password,
          'acknowledged': acknowledged,
          'confirm_delete': confirmDelete,
        },
      );
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut error during account deletion: $e');
    }

    try {
      await FFAppState().clearAuthCredentials();
    } catch (e) {
      debugPrint('Local cleanup error during account deletion: $e');
    }
  }

  /// Send a password reset email with a secure reset link.
  Future<void> sendPasswordReset({
    required String email,
    String? turnstileToken,
  }) async {
    try {
      await ApiService.forgotPassword(
        email: email,
        turnstileToken: turnstileToken,
      );
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  /// Confirm a password reset using a secure token sent by email.
  Future<void> confirmPasswordReset({
    required String token,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      await ApiService.resetPassword(
        token: token,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
    } catch (e) {
      throw Exception('Password reset confirmation failed: $e');
    }
  }

  /// Refresh the current session.
  ///
  /// This is called when the access token is about to expire.
  /// Returns the new FARM JWT if successful.
  Future<String?> refreshSession({bool force = false}) async {
    try {
      final refreshed = await RefreshManager().refreshIfNeeded(force: force);
      return refreshed ? FFAppState().accessToken : null;
    } catch (e) {
      debugPrint('Session refresh failed: $e');
      throw Exception('Session refresh failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await ApiService.getSessions();
    final sessions = response['sessions'];
    if (sessions is List) {
      return sessions.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<void> revokeSession({required String sessionId}) async {
    await ApiService.revokeSession(sessionId: sessionId);
  }

  Future<void> revokeOtherSessions() async {
    await ApiService.revokeOtherSessions();
  }

  Future<void> revokeAllSessions() async {
    await ApiService.revokeAllSessions();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await ApiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  /// Verify email with a token from the verification link.
  ///
  /// Called after user clicks the verification link in their email.
  Future<void> verifyEmail({required String token}) async {
    try {
      final response = await ApiService.verifyEmail(token: token);
      if (response['message'] == null) {
        throw Exception('Email verification failed: Invalid response');
      }
    } catch (e) {
      throw Exception('Email verification failed: $e');
    }
  }

  Future<void> resendEmailVerification({required String email}) async {
    try {
      final response = await ApiService.resendEmailVerification(email: email);
      if (response['message'] == null) {
        throw Exception('Resend verification failed: Invalid response');
      }
    } catch (e) {
      throw Exception('Resend verification failed: $e');
    }
  }

  /// Get the current authenticated user.
  dynamic getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Get the current session.
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }

  /// Check if user is authenticated.
  bool isAuthenticated() {
    return _supabase.auth.currentUser != null &&
        _supabase.auth.currentSession != null;
  }

  /// Listen to auth state changes.
  /// Returns a stream that emits AuthState when authentication changes.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
