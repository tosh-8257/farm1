import '/app_state.dart';

/// Local wipe after explicit logout, account switch, or a revoked session.
///
/// [onBeforeClear] cancels notifications and drops the push token. It is
/// registered by [NotificationService] so this file does not depend on Firebase.
class SessionEnd {
  static Future<void> Function()? onBeforeClear;
  static bool _running = false;

  static Future<void> forceLocalSignOut(String reason) async {
    if (_running) return;
    _running = true;
    try {
      final hook = onBeforeClear;
      if (hook != null) {
        try {
          await hook();
        } catch (_) {}
      }
      await FFAppState().clearAuthCredentials(reason);
    } finally {
      _running = false;
    }
  }
}
