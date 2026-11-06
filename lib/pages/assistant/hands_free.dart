/// Foreground "Hey Mkulima" parsing. Money movement is never confirmed here.
class HandsFreeUtterance {
  const HandsFreeUtterance({required this.wake, this.command});

  /// True when the phrase is a wake, even with no command yet.
  final bool wake;
  final String? command;

  bool get hasCommand => command != null && command!.trim().isNotEmpty;
}

final _wake = RegExp(
  r'(?:^|\b)(?:hey|hi|okay|ok)\s+mkulima\b[\s,!:.\-]*',
  caseSensitive: false,
);

/// Pulls the command that follows "Hey Mkulima". Other speech is ignored.
HandsFreeUtterance parseHandsFree(String transcript) {
  final text = transcript.trim();
  if (text.isEmpty) return const HandsFreeUtterance(wake: false);
  final match = _wake.firstMatch(text);
  if (match == null) return const HandsFreeUtterance(wake: false);
  final rest = text.substring(match.end).trim();
  return HandsFreeUtterance(wake: true, command: rest.isEmpty ? null : rest);
}

/// Voice must not carry a PIN or biometric bypass into a payment.
bool voiceTextLooksLikeSecret(String text) {
  final lower = text.toLowerCase();
  if (RegExp(r'\bpin\b').hasMatch(lower) && RegExp(r'\d{4,8}').hasMatch(text)) {
    return true;
  }
  return false;
}

/// What the hands-free flag can and cannot do on a phone.
const handsFreeLimits =
    'Hey Mkulima, headset-button capture, and spoken replies work while Mkulima is open and the app is in the foreground. '
    'Android and iOS suspend the microphone when the app is in the background or the screen is locked, so a phone in a pocket will not hear the wake word. '
    'This is not a system-wide always-listening mode. Sending money still asks for your PIN or biometrics.';
