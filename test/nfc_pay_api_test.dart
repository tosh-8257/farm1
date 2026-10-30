import 'package:flutter_test/flutter_test.dart';
import 'package:farm/backend/api_requests/nfc_pay_api.dart';

void main() {
  const t = 'farmpay1.11111111-2222-3333-4444-555555555555.1793000000.abcDEF_-123';
  test('extracts tap-to-pay tokens from NFC URI, raw and URL forms', () {
    expect(NfcPayApi.extractToken('farmpay:$t'), t);
    expect(NfcPayApi.extractToken(t), t);
    expect(NfcPayApi.extractToken('https://farm.app/tap-pay?t=$t'), t);
    expect(NfcPayApi.extractToken('FARMWALLETADDRESS'), isNull);
    expect(NfcPayApi.extractToken('farmpay1.not-a-uuid.1.x'), isNull);
  });
}
