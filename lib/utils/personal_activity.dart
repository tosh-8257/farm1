import 'transaction_history_utils.dart';

/// QR sales are credited to the owner's personal wallet and stay in this list.
/// Merchant sales still load the same payments separately.
bool isMerchantQr(Map tx) {
  final type = (tx['transaction_type'] ?? tx['type'] ?? '')
      .toString()
      .trim()
      .toLowerCase();
  final source = (tx['source'] ?? '').toString().toLowerCase();
  const qrTypes = {
    'merchant_payment',
    'qr_payment',
    'public_qr',
    'qr',
  };
  if (qrTypes.contains(type) || source == 'qr' || source == 'merchant_qr') {
    return true;
  }
  return (tx['description'] ?? '').toString().toLowerCase().contains('public qr');
}

/// Label used on personal activity for a merchant QR credit or payment.
String? merchantQrTitle(Map tx) => isMerchantQr(tx) ? 'Merchant QR' : null;

bool isPersonalActivity(Object? value) => isVisibleTransactionHistoryItem(value);
