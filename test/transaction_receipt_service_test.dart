import 'package:flutter_test/flutter_test.dart';
import 'package:farm/services/transaction_receipt_service.dart';

void main() {
  group('TransactionReceiptService.transactionLookupId', () {
    test('uses the transaction database id when available', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'id': 'transaction-row-id',
          'transaction_reference': 'display-reference',
        }),
        'transaction-row-id',
      );
    });

    test('falls back to the available transaction reference', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'transaction_reference': 'transaction-reference',
        }),
        'transaction-reference',
      );
    });

    test('uses the transaction reference for a withdrawal history row', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'id': 'withdrawal-row-id',
          'reference': 'transaction-reference',
          'method': 'BANK_TRANSFER',
        }),
        'transaction-reference',
      );
    });

    test('uses the reference for a detailed withdrawal transaction', () {
      expect(
        TransactionReceiptService.transactionLookupId({
          'id': 'transaction-row-id',
          'transaction_reference': 'transaction-reference',
          'transaction_type': 'withdrawal',
        }),
        'transaction-reference',
      );
    });
  });
}
