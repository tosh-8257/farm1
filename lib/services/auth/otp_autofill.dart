import 'package:flutter/foundation.dart';
import 'package:smart_auth/smart_auth.dart';

/// Android SMS autofill. iOS uses AutofillHints.oneTimeCode on the field.
class OtpAutofill {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// SMS Retriever (no prompt) for SMS ending with our app hash, e.g. FARM
  /// device-recovery codes.
  static Future<String?> retriever() async {
    if (!supported) return null;
    final r = await SmartAuth.instance.getSmsWithRetrieverApi();
    return _code(r.data?.code);
  }

  /// SMS User Consent (one-tap prompt) for any SMS, e.g. Firebase codes.
  static Future<String?> userConsent() async {
    if (!supported) return null;
    final r = await SmartAuth.instance.getSmsWithUserConsentApi();
    return _code(r.data?.code);
  }

  static Future<void> cancel() async {
    if (!supported) return;
    await SmartAuth.instance.removeSmsRetrieverApiListener();
    await SmartAuth.instance.removeUserConsentApiListener();
  }

  /// The 11-character hash the backend appends (ANDROID_SMS_APP_HASH).
  static Future<String?> appHash() async {
    if (!supported) return null;
    return (await SmartAuth.instance.getAppSignature()).data;
  }

  static String? _code(String? c) {
    final m = RegExp(r'\d{6}').firstMatch(c ?? '');
    return m?.group(0);
  }
}
