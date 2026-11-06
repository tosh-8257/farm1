import 'package:farm/utils/farmpay_checkout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invoice and link tokens are not sent to the QR parser', () {
    final link = classifyFarmpayPath('/pay/l/abcdefgh');
    expect(link?.kind, FarmpayCheckoutKind.paymentLink);
    expect(link?.ref, 'abcdefgh');
    expect(farmpayAppLocation(link!), '/pay-business?code=abcdefgh');

    final invoice = classifyFarmpayPath('/pay/i/INV-2026-AB12CD34');
    expect(invoice?.kind, FarmpayCheckoutKind.invoice);
    expect(invoice?.ref, 'INV-2026-AB12CD34');
    expect(
      farmpayAppLocation(invoice!),
      '/pay-business?invoice=INV-2026-AB12CD34',
    );

    // path[1] on these URLs is "l" or "i", which the QR page rejects
    // because it is shorter than 10 characters.
    expect(classifyFarmpayPath('/pay/l'), isNull);
    expect(classifyFarmpayPath('/pay/i'), isNull);
    expect(classifyFarmpayPath('/pay/short'), isNull);
  });

  test('a long merchant id is still a QR checkout', () {
    final qr = classifyFarmpayPath('/pay/merchant1234');
    expect(qr?.kind, FarmpayCheckoutKind.qrMerchant);
    expect(qr?.ref, 'merchant1234');
    expect(farmpayAppLocation(qr!), isNull);
  });
}
