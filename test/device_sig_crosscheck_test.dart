import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ed25519 device signature format', () async {
    final algo = Ed25519();
    final kp = await algo.newKeyPairFromSeed(List<int>.filled(32, 7));
    final pub = await kp.extractPublicKey();
    const msg = 'farm-device-login:v1:11111111-1111-4111-8111-111111111111:n0nce:farm-abc';
    final sig = await algo.sign(utf8.encode(msg), keyPair: kp);
    expect(pub.bytes.length, 32);
    expect(sig.bytes.length, 64);
    expect(await algo.verify(utf8.encode(msg), signature: sig), isTrue);
    final out = Platform.environment['XCHK_OUT'];
    if (out != null) {
      File(out).writeAsStringSync(jsonEncode({
        'pub': base64Encode(pub.bytes),
        'sig': base64Encode(sig.bytes),
        'msg': msg,
      }));
    }
  });
}
