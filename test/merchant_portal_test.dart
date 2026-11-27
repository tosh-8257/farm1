import 'package:farm/pages/assistant/hands_free.dart';
import 'package:farm/pages/merchant_portal/merchant_portal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merchant portal keeps every current area and personal-wallet QR', () {
    final text = merchantPortalAreas.map((a) => '${a.title} ${a.detail}').join('\n');
    expect(text, contains('Dashboard'));
    expect(text, contains('Sales history'));
    expect(text, contains('personal FARM balance'));
    expect(text, contains('Profile and verification'));
    expect(text, contains('Notifications'));
    expect(text, contains('Help'));
    expect(text, contains('Dropshipping'));
    expect(text, contains('cargo'));
  });

  test('hands-free stays foreground only and cannot send money', () {
    expect(handsFreeLimits, contains('foreground'));
    expect(handsFreeLimits, contains('not a system-wide'));
    expect(handsFreeLimits, contains('PIN or biometrics'));
    expect(parseHandsFree('hey mkulima show my balance').hasCommand, isTrue);
    expect(voiceTextLooksLikeSecret('my pin is 1234'), isTrue);
  });
}
