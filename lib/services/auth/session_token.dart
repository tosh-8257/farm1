import 'dart:convert';

/// Access-token checks shared by routing and biometric renewal.
///
/// A JWT whose `exp` is in the past is dead. Any other non-empty token is
/// treated as usable: tests and older responses are not JWTs, and a JWT
/// without `exp` cannot be proven dead on the device.
bool accessTokenIsLive(String token, {DateTime? now}) {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return false;
  final expiry = jwtExpiry(trimmed);
  if (expiry == null) return true;
  final clock = now ?? DateTime.now().toUtc();
  return expiry.isAfter(clock.add(const Duration(seconds: 30)));
}

DateTime? jwtExpiry(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    var normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    final decoded = utf8.decode(base64Url.decode(normalized));
    final map = jsonDecode(decoded);
    if (map is! Map) return null;
    final exp = map['exp'];
    final seconds = exp is int ? exp : exp is String ? int.tryParse(exp) : null;
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// Login, registration, and the phone-code screen stay available while a
/// biometric session still needs a live token.
bool smsSignInPath(String path) {
  const paths = [
    '/login',
    '/loginpage',
    '/otp',
    '/otppage',
    '/register',
    '/registerpage',
    '/forgot-password',
    '/forgotPasswordPage',
    '/reset-password',
  ];
  return paths.any((entry) => path == entry || path.startsWith('$entry/'));
}

/// Biometric installs must not paint a signed-in screen on a dead access token.
bool mustRenewBiometricSession({
  required bool biometricsAllowed,
  required bool needsBiometricReauth,
  required String accessToken,
  required String refreshToken,
  DateTime? now,
}) {
  if (!biometricsAllowed) return false;
  if (refreshToken.trim().isEmpty && accessToken.trim().isEmpty) return false;
  if (needsBiometricReauth) return true;
  return !accessTokenIsLive(accessToken, now: now);
}

Map<String, dynamic>? asStringKeyMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

/// Walks `data` wrappers until the token fields are visible.
Map<String, dynamic> refreshTokenPayload(dynamic body) {
  var current = asStringKeyMap(body) ?? <String, dynamic>{};
  for (var depth = 0; depth < 3; depth++) {
    final nested = asStringKeyMap(current['data']);
    if (nested == null) break;
    current = nested;
    if (current['access_token'] is String || current['accessToken'] is String) {
      break;
    }
  }
  return current;
}

String stringField(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
