import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Native NFC glue. Android only: HCE emits, nfc_manager reads.
/// Everything else (iOS, web, NFC off/unsupported) uses the QR fallback.
class TapPayPlatform {
  static const _ch = MethodChannel('farm.tap_pay');
  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Can this phone emit a tap-to-pay request over NFC right now?
  static Future<bool> canEmit() async {
    if (!_android) return false;
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('supported');
      return r?['hce'] == true && r?['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> startEmit(String token, DateTime expiresAt) async {
    if (!_android) return;
    try {
      await _ch.invokeMethod('start', {'token': token, 'expiresAtMs': expiresAt.millisecondsSinceEpoch});
    } catch (_) {}
  }

  static Future<void> stopEmit() async {
    if (!_android) return;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }

  static Future<bool> canRead() async {
    if (!_android) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Reads one NDEF URI record and returns its text (e.g. "farmpay:<token>").
  static Future<String?> readOnce({Duration timeout = const Duration(seconds: 60)}) async {
    final done = Completer<String?>();
    await NfcManager.instance.startSession(onDiscovered: (tag) async {
      String? out;
      try {
        final ndef = Ndef.from(tag);
        final msg = ndef?.cachedMessage ?? await ndef?.read();
        for (final r in msg?.records ?? const <NdefRecord>[]) {
          if (r.payload.isEmpty) continue;
          // URI record: first byte is the prefix code (0 = none).
          out = utf8.decode(r.payload.sublist(1), allowMalformed: true);
          break;
        }
      } catch (_) {}
      await NfcManager.instance.stopSession();
      if (!done.isCompleted) done.complete(out);
    });
    return done.future.timeout(timeout, onTimeout: () async {
      await NfcManager.instance.stopSession();
      return null;
    });
  }

  static Future<void> cancelRead() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
