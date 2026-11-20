import 'dart:convert';

/// Pure rules for session-bound push delivery.
///
/// The signed-in user id is compared with any account id in the payload.
/// Payloads are not logged. Tokens are not read here.
const pushTokenPrefsKey = 'fcm_device_token';
const pushSessionActiveKey = 'push_session_active';
const pushBoundUserKey = 'push_bound_user_id';

const _accountIdKeys = <String>[
  'user_id',
  'userId',
  'account_id',
  'accountId',
  'target_user_id',
  'targetUserId',
  'recipient_id',
  'recipientId',
  'owner_id',
  'ownerId',
];

/// `android` or `ios` for the device-token API. Other platforms are omitted.
String? pushPlatformName({required bool isWeb, required String platformName}) {
  if (isWeb) return null;
  switch (platformName.toLowerCase()) {
    case 'android':
      return 'android';
    case 'ios':
      return 'ios';
    default:
      return null;
  }
}

/// Account id the payload is addressed to, when the sender included one.
String? targetAccountId(Map<String, dynamic> payload) {
  final direct = _readAccountId(payload);
  if (direct != null) return direct;
  for (final key in const ['metadata', 'data']) {
    final nested = payload[key];
    if (nested is Map) {
      final found = _readAccountId(Map<String, dynamic>.from(nested));
      if (found != null) return found;
    } else if (nested is String && nested.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(nested);
        if (decoded is Map) {
          final found = _readAccountId(Map<String, dynamic>.from(decoded));
          if (found != null) return found;
        }
      } catch (_) {}
    }
  }
  return null;
}

String? _readAccountId(Map<String, dynamic> payload) {
  for (final key in _accountIdKeys) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// Foreground and tap handling. Logged-out sessions drop every type.
/// A payload that names an account is shown only to that account.
bool shouldPresentPush({
  required bool loggedIn,
  required String currentUserId,
  required Map<String, dynamic> payload,
}) {
  if (!loggedIn) return false;
  final target = targetAccountId(payload);
  if (target == null || target.isEmpty) return true;
  if (currentUserId.isEmpty) return false;
  return target == currentUserId;
}

/// Background isolate. [sessionActive] is null until this install has
/// registered or signed out; only an explicit `false` means logged out.
bool shouldClearBackgroundPush({
  required bool? sessionActive,
  required String boundUserId,
  required Map<String, dynamic> data,
}) {
  if (sessionActive == false) return true;
  final target = targetAccountId(data);
  if (target == null || target.isEmpty) return false;
  if (boundUserId.isEmpty) return false;
  return target != boundUserId;
}

/// Refresh and API 401s that mean this session can no longer be used.
/// A generic unauthorized response is not terminal: biometric unlock keeps
/// the locally stored session until the server says it was revoked or expired.
bool isTerminalSessionFailure(String message, {String? code}) {
  final normalizedCode = (code ?? '').toLowerCase().replaceAll('-', '_');
  if (normalizedCode == 'device_id_required' || normalizedCode == 'access_expired') {
    return false;
  }
  const terminalCodes = {
    'session_revoked',
    'token_revoked',
    'session_expired',
    'refresh_reuse',
  };
  if (terminalCodes.contains(normalizedCode)) return true;

  final lower = message.toLowerCase();
  if (lower.contains('already in progress') ||
      lower.contains('retry with the latest')) {
    return false;
  }
  if (lower.contains('device id') && lower.contains('refresh')) return false;
  return lower.contains('revoked') ||
      lower.contains('compromised') ||
      lower.contains('session not found') ||
      lower.contains('session expired') ||
      lower.contains('expired session') ||
      lower.contains('not valid on this device') ||
      lower.contains('session not valid');
}

/// Local sign-out is only for a real auth failure.
///
/// A failed upload, a 403, and a transient error (network, timeout, 5xx)
/// keep the session. When biometrics are on, the app does not sign out at
/// all: the install keeps the session until the user logs out or the app
/// is uninstalled.
bool shouldForceLocalSignOut({
  required int? statusCode,
  required String message,
  String? code,
  bool? sessionInvalid,
  bool upload = false,
  bool biometricsOn = false,
  bool transientFailure = false,
}) {
  if (biometricsOn || upload || transientFailure) return false;
  if (statusCode == null || statusCode == 403) return false;
  if (statusCode == 408 || statusCode == 429 || statusCode >= 500) {
    return false;
  }
  if (statusCode != 401) return false;
  final normalizedCode = (code ?? '').toLowerCase().replaceAll('-', '_');
  if (normalizedCode == 'access_expired') return false;
  if (sessionInvalid == false) return false;
  if (sessionInvalid == true) return true;
  return isTerminalSessionFailure(message, code: code);
}

/// `session_invalid` from the current error JSON. Null when an older server
/// did not send the field.
bool? sessionInvalidFlag(Map<dynamic, dynamic>? body) {
  if (body == null || !body.containsKey('session_invalid')) return null;
  return body['session_invalid'] == true;
}

class SessionErrorBody {
  const SessionErrorBody({required this.message, this.code, this.sessionInvalid});
  final String message;
  final String? code;
  final bool? sessionInvalid;
}

SessionErrorBody readSessionError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final message = map['message'];
      final text = message is String
          ? message
          : message is List
              ? message.map((part) => '$part').join(' ')
              : '';
      final code = map['code'];
      return SessionErrorBody(
        message: text,
        code: code is String ? code : null,
        sessionInvalid: sessionInvalidFlag(map),
      );
    }
  } catch (_) {}
  return SessionErrorBody(message: body);
}
