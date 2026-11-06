/// How a farmpay.africa path should be paid.
///
/// `/pay/l/<code>` and `/pay/i/<number>` are business documents. They must not
/// be sent through the merchant QR parser. A QR page is only `/pay/<merchantId>`
/// when that id is long enough to be a merchant id.
enum FarmpayCheckoutKind { paymentLink, invoice, qrMerchant }

class FarmpayCheckoutTarget {
  const FarmpayCheckoutTarget(this.kind, this.ref);
  final FarmpayCheckoutKind kind;
  final String ref;
}

FarmpayCheckoutTarget? classifyFarmpayPath(String path) {
  final parts = path
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(Uri.decodeComponent)
      .toList();
  if (parts.length < 2 || parts.first != 'pay') return null;
  final second = parts[1];
  if ((second == 'l' || second == 'i') && parts.length >= 3) {
    final ref = parts.sublist(2).join('/');
    if (ref.isEmpty) return null;
    return FarmpayCheckoutTarget(
      second == 'l' ? FarmpayCheckoutKind.paymentLink : FarmpayCheckoutKind.invoice,
      ref,
    );
  }
  if (parts.length == 2 &&
      second != 'l' &&
      second != 'i' &&
      second != 'success' &&
      second != 'ANYID' &&
      second.length >= 10) {
    return FarmpayCheckoutTarget(FarmpayCheckoutKind.qrMerchant, second);
  }
  return null;
}

/// In-app route for a document checkout. QR targets stay on the QR flow.
String? farmpayAppLocation(FarmpayCheckoutTarget target) {
  switch (target.kind) {
    case FarmpayCheckoutKind.paymentLink:
      return Uri(path: '/pay-business', queryParameters: {'code': target.ref}).toString();
    case FarmpayCheckoutKind.invoice:
      return Uri(path: '/pay-business', queryParameters: {'invoice': target.ref}).toString();
    case FarmpayCheckoutKind.qrMerchant:
      return null;
  }
}
