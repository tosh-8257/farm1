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
  if (normalizedCode == 'device_id_required') return false;
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
