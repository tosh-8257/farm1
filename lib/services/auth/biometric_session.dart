import 'package:flutter/foundation.dart';

import '/app_state.dart';
import 'biometric_reauth.dart';
import 'refresh_manager.dart';
import 'session_token.dart';

/// Turns a local biometric success into a server session.
///
/// The access token is refreshed with the stored refresh token, the rotated
/// refresh token is persisted by [RefreshManager], and a failed refresh does
/// not count as signed-in. Tokens already on the device are kept so the next
/// attempt, or an SMS login, can still use them.
class BiometricSession {
  static Future<bool> renewStoredSession() async {
    final state = FFAppState();
    if (state.refreshToken.trim().isEmpty) {
      debugPrint('[BiometricSession] No refresh token to rotate.');
      state.needsBiometricReauth = true;
      return false;
    }

    var refreshed = false;
    try {
      refreshed = await RefreshManager().refreshIfNeeded(
        force: true,
        endSession: false,
      );
    } catch (e) {
      debugPrint('[BiometricSession] Refresh failed: $e');
    }

    if (refreshed && accessTokenIsLive(state.accessToken)) {
      state.isLoggedIn = true;
      state.needsBiometricReauth = false;
      return true;
    }

    try {
      final reauth = await BiometricReauth.exchange();
      if (reauth != null && accessTokenIsLive(state.accessToken)) {
        state.isLoggedIn = true;
        state.needsBiometricReauth = false;
        return true;
      }
    } catch (e) {
      debugPrint('[BiometricSession] Device re-auth failed: $e');
    }

    state.needsBiometricReauth = true;
    state.isLoggedIn =
        state.refreshToken.trim().isNotEmpty || state.accessToken.trim().isNotEmpty;
    debugPrint(
      '[BiometricSession] Renewal did not produce a live access token.',
    );
    return false;
  }
}
