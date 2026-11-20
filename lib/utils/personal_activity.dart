import 'transaction_history_utils.dart';

/// Channel stored on a merchant transaction. Reads the new `channel` field
/// and the older hints (`source`, metadata `business_document`) so labels
/// work before and after the backend change.
String? paymentChannel(Map tx) {
  final values = <String>[
    _text(tx['channel']),
    _text(tx['payment_channel']),
    _text(tx['source']),
    ..._nestedChannel(tx['metadata']),
    ..._nestedChannel(tx['business_payment']),
    ..._nestedChannel(tx['business_payments']),
    ..._nestedChannel(tx['business_document']),
  ];
  for (final value in values) {
    final normalized = _normalizeChannel(value);
    if (normalized != null) return normalized;
  }
  final type = _text(tx['transaction_type'] ?? tx['type']);
  final fromType = _normalizeChannel(type);
  if (fromType != null && fromType != 'qr') return fromType;
  final description = _text(tx['description']).toLowerCase();
  if (description.contains('payment link')) return 'payment_link';
  if (description.contains('invoice')) return 'invoice';
  if (description.contains('public qr') || description.contains('merchant qr')) {
    return 'qr';
  }
  if (fromType == 'qr') return 'qr';
  return null;
}

bool isMerchantQr(Map tx) => paymentChannel(tx) == 'qr';

/// Activity label for a merchant collection. QR, payment link, and invoice
/// stay distinct. A merchant payment with no channel is not called QR.
String? merchantQrTitle(Map tx) {
  switch (paymentChannel(tx)) {
    case 'qr':
      return 'Merchant QR';
    case 'payment_link':
      return 'Payment link';
    case 'invoice':
      final ref = _invoiceRef(tx);
      return ref == null ? 'Invoice' : 'Invoice $ref';
    case 'nfc':
      return 'Tap to pay';
    case 'p2p':
      return 'Transfer';
    case 'chain_deposit':
      return 'Crypto deposit';
    case 'nowpayments':
      return 'Crypto deposit';
    case 'paystack':
      return 'Deposit';
    default:
      return null;
  }
}

bool isPersonalActivity(Object? value) => isVisibleTransactionHistoryItem(value);

String _text(Object? value) => value?.toString().trim() ?? '';

List<String> _nestedChannel(Object? raw) {
  if (raw is! Map) return const [];
  final map = Map<String, dynamic>.from(raw);
  return [
    _text(map['channel']),
    _text(map['payment_channel']),
    _text(map['source']),
    _text(map['business_document']),
    _text(map['kind']),
    _text(map['type']),
  ];
}

String? _invoiceRef(Map tx) {
  final direct = _text(tx['invoice_number'] ?? tx['invoice_no']);
  if (direct.isNotEmpty) return direct;
  final meta = tx['metadata'];
  if (meta is Map) {
    final ref = _text(meta['invoice_number'] ?? meta['invoice_no'] ?? meta['reference']);
    if (ref.isNotEmpty) return ref;
  }
  return null;
}

String? _normalizeChannel(String raw) {
  final value = raw.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  switch (value) {
    case 'qr':
    case 'merchant_qr':
    case 'public_qr':
    case 'qr_payment':
      return 'qr';
    case 'payment_link':
    case 'pay_link':
    case 'paymentlink':
      return 'payment_link';
    case 'invoice':
    case 'invoice_payment':
    case 'invoice_pay':
      return 'invoice';
    case 'nfc':
    case 'tap_to_pay':
      return 'nfc';
    case 'p2p':
      return 'p2p';
    case 'chain_deposit':
    case 'nowpayments':
    case 'paystack':
      return value;
    default:
      return null;
  }
}
