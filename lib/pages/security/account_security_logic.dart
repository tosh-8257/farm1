/// Client-side mirror of the backend password policy (registration, reset and
/// change password): at least 12 characters with upper, lower, digit, symbol.
/// The server remains the source of truth.
String? passwordPolicyError(String value) {
  if (value.length < 12) return 'Use at least 12 characters.';
  if (!RegExp(r'[a-z]').hasMatch(value)) return 'Add a lowercase letter.';
  if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Add an uppercase letter.';
  if (!RegExp(r'\d').hasMatch(value)) return 'Add a number.';
  if (!RegExp(r'[^\da-zA-Z]').hasMatch(value)) return 'Add a symbol.';
  return null;
}

/// Validates the whole change-password form; returns the first problem.
String? changePasswordFormError({
  required String current,
  required String next,
  required String confirm,
}) {
  if (current.isEmpty) return 'Enter your current password.';
  final policy = passwordPolicyError(next);
  if (policy != null) return policy;
  if (next != confirm) return 'The new passwords do not match.';
  if (next == current) return 'Choose a password different from your current one.';
  return null;
}

/// Extracts a verification token from a link or raw paste. Tokens are
/// 64 hex characters; anything else returns null.
String? extractVerificationToken(String input) {
  final raw = input.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  final candidate = uri?.queryParameters['token'] ??
      (uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : raw);
  return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(candidate) ? candidate.toLowerCase() : null;
}

/// Maps backend status codes to user-facing copy without leaking internals.
String friendlyAuthError(int? statusCode, String fallback) {
  switch (statusCode) {
    case 401:
      return 'Your current password is incorrect.';
    case 429:
      return 'Too many requests. Please wait a minute and try again.';
    case 503:
      return 'Email delivery is not set up yet, so verification emails cannot be sent right now.';
    default:
      return fallback;
  }
}
