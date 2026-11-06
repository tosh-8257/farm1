import 'package:flutter/material.dart';
import '/services/biometric_lock_service.dart';
import 'package:local_auth/local_auth.dart';
import '/app_state.dart';
import '/services/secure_storage_service.dart';
import '/services/auth/auth_service.dart';
import '/services/auth/biometric_reauth.dart';

/// Service for biometric-based login (fingerprint/face ID).
///
/// Flow:
/// 1. User taps fingerprint button
/// 2. Local authentication challenge (fingerprint/face)
/// 3. On success: Retrieve stored Supabase session
/// 4. Refresh Supabase session
/// 5. Exchange new Supabase token for FARM JWT via backend
/// 6. Store new tokens and route to Dashboard
class BiometricLoginService {
  static final BiometricLoginService _instance =
      BiometricLoginService._internal();

  factory BiometricLoginService() {
    return _instance;
  }

  BiometricLoginService._internal();

  // Local auth handled centrally by BiometricLockService

  /// Check if device supports biometric authentication.
  Future<bool> canUseBiometrics() async {
    try {
      final svc = BiometricLockService();
      return await svc.canUseBiometrics();
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types on this device.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final svc = BiometricLockService();
      return await svc.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if user has a local biometric unlock session available.
  ///
  /// This checks if biometrics are enabled and local backend tokens are stored.
  Future<bool> hasBiometricSession() async {
    try {
      if (!FFAppState().isBiometricAllowed) {
        return false;
      }
      if (FFAppState().refreshToken.isEmpty) {
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking biometric session: $e');
      return false;
    }
  }

  /// Perform biometric authentication and unlock stored Supabase session.
  ///
  /// Returns:
  /// - Success map with tokens and user data if successful
  /// - Throws Exception with error message if fails
  ///
  /// Steps:
  /// 1. Verify fingerprint/face locally
  /// 2. Retrieve stored Supabase session
  /// 3. Refresh Supabase session (get new tokens)
  /// 4. Exchange Supabase token for FARM JWT
  /// 5. Store tokens and return user data
  Future<Map<String, dynamic>> authenticateWithBiometric() async {
    try {
      // Step 1: Authenticate locally via BiometricLockService
      debugPrint('[Biometric] Starting local authentication via BiometricLockService...');
      final biometricService = BiometricLockService();
      final isAuthenticated = await biometricService.authenticate(
        localizedReason: 'Unlock your FARM account with your biometric',
      );

      if (!isAuthenticated) {
        throw Exception('Biometric authentication was cancelled or failed.');
      }

      debugPrint('[Biometric] Local auth succeeded');

      if (!FFAppState().isBiometricAllowed) {
        throw Exception('Biometric login is only available for user accounts.');
      }

      if (FFAppState().refreshToken.isEmpty) {
        throw Exception(
          'No stored refresh token found. Please log in with password first.',
        );
      }

      debugPrint('[Biometric] Refreshing backend session with stored refresh token...');
      String? refreshedToken;
      try {
        refreshedToken = await AuthService().refreshSession(force: true);
      } catch (e) {
        debugPrint('[Biometric] Refresh threw, trying biometric re-auth: $e');
      }
      if (refreshedToken == null || refreshedToken.isEmpty) {
        final reauth = await BiometricReauth.exchange();
        if (reauth != null) {
          refreshedToken = FFAppState().accessToken;
        }
      }
      // A failed refresh must not sign the user out. The local unlock stands.
      if ((refreshedToken == null || refreshedToken.isEmpty) &&
          FFAppState().accessToken.isEmpty &&
          FFAppState().refreshToken.isEmpty) {
        throw Exception(
          'No stored session found. Please log in with your password.',
        );
      }
      FFAppState().isLoggedIn = true;
      FFAppState().needsBiometricReauth = false;

      final farmJwt = FFAppState().accessToken;
      final refreshToken = FFAppState().refreshToken;
      final userData = {
        'id': FFAppState().userId,
        'first_name': FFAppState().firstName,
        'username': FFAppState().userName,
        'phone': FFAppState().phone,
        'kyc_status': FFAppState().kycStatus,
        'role': FFAppState().role,
      };

      if (farmJwt.isEmpty && FFAppState().refreshToken.isEmpty) {
        throw Exception('Failed to restore backend access token.');
      }

      debugPrint('[Biometric] Backend token refresh succeeded');

      if (farmJwt.isNotEmpty) {
        await SecureStorageService.writeAccessToken(farmJwt);
      }
      if (refreshToken.isNotEmpty) {
        await SecureStorageService.writeRefreshToken(refreshToken);
      }
      await BiometricLockService().markVerified();

      debugPrint('[Biometric] Biometric unlock succeeded');

      return {
        'success': true,
        'farmJwt': farmJwt,
        'refreshToken': refreshToken,
        'user': userData,
        'message': 'Biometric login successful',
      };
    } catch (e) {
      debugPrint('[Biometric] Error: $e');
      throw Exception('Biometric login failed: $e');
    }
  }

  /// Get a user-friendly message based on biometric status.
  Future<String> getBiometricButtonLabel() async {
    try {
      final biometrics = await getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        return 'Login with Face ID';
      } else if (biometrics.contains(BiometricType.fingerprint)) {
        return 'Login with Fingerprint';
      } else if (biometrics.contains(BiometricType.iris)) {
        return 'Login with Iris';
      }
      return 'Login with Biometric';
    } catch (_) {
      return 'Login with Biometric';
    }
  }

  /// Disable biometric login (usually called on logout).
  Future<void> disableBiometricLogin() async {
    try {
      FFAppState().biometricsEnabled = false;
      await SecureStorageService.clearBiometricData();
      debugPrint('[Biometric] Login disabled');
    } catch (e) {
      debugPrint('[Biometric] Error disabling: $e');
    }
  }
}
