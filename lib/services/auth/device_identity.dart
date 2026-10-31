import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '/backend/services/api_service.dart';

/// Device binding identity.
///
/// An Ed25519 keypair is generated on first use. The private seed is written
/// only to flutter_secure_storage (Android Keystore-wrapped
/// EncryptedSharedPreferences / iOS Keychain, this-device-only) and never
/// leaves the phone; only the public key and signatures are sent.
class DeviceIdentity {
  DeviceIdentity._();
  static final DeviceIdentity instance = DeviceIdentity._();

  static const _kDeviceId = 'farm_device_id_v1';
  static const _kSeed = 'farm_device_ed25519_seed_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final _algo = Ed25519();
  String? _deviceId;
  SimpleKeyPair? _keyPair;
  String? _publicKeyB64;

  Future<String> deviceId() async {
    await _ensure();
    return _deviceId!;
  }

  Future<void> _ensure() async {
    if (_keyPair != null && _deviceId != null) return;
    var id = await _storage.read(key: _kDeviceId);
    var seedB64 = await _storage.read(key: _kSeed);
    if (id == null || seedB64 == null) {
      final rnd = Random.secure();
      id =
          'farm-${List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      final seed = List<int>.generate(32, (_) => rnd.nextInt(256));
      seedB64 = base64Encode(seed);
      await _storage.write(key: _kSeed, value: seedB64);
      await _storage.write(key: _kDeviceId, value: id);
    }
    _deviceId = id;
    _keyPair = await _algo.newKeyPairFromSeed(base64Decode(seedB64));
    final pub = await _keyPair!.extractPublicKey();
    _publicKeyB64 = base64Encode(pub.bytes);
  }

  Future<String> _sign(String message) async {
    await _ensure();
    final sig = await _algo.sign(utf8.encode(message), keyPair: _keyPair!);
    return base64Encode(sig.bytes);
  }

  static String _platform() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  Future<String> _deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) return 'Web browser';
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final i = await info.iosInfo;
        return i.name.isNotEmpty ? i.name : i.model;
      }
      final a = await info.androidInfo;
      return '${a.manufacturer} ${a.model}'.trim();
    } catch (_) {
      return 'Phone';
    }
  }

  /// Fetches a server nonce and returns the `device` login proof, or null if
  /// the backend has no device-binding endpoint (older server).
  Future<Map<String, dynamic>?> loginProof() async {
    try {
      await _ensure();
      final res = await ApiService.deviceChallenge(deviceId: _deviceId!);
      final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final challengeId = data['challenge_id']?.toString() ?? '';
      final nonce = data['nonce']?.toString() ?? '';
      if (challengeId.isEmpty || nonce.isEmpty) return null;
      final message = 'farm-device-login:v1:$challengeId:$nonce:${_deviceId!}';
      final name = await _deviceName();
      return {
        'device_id': _deviceId,
        'public_key': _publicKeyB64,
        'key_alg': 'ed25519',
        'challenge_id': challengeId,
        'signature': await _sign(message),
        'platform': _platform(),
        'name': name.length > 100 ? name.substring(0, 100) : name,
      };
    } catch (e) {
      debugPrint('[DeviceIdentity] proof unavailable: $e');
      return null;
    }
  }
}

/// Thrown by login when the backend says this phone is not trusted yet.
class NewDeviceRequiredException implements Exception {
  NewDeviceRequiredException(this.pendingDeviceId);
  final String pendingDeviceId;
  @override
  String toString() => 'This is a new device. Approval is required.';
}
