import 'package:flutter_test/flutter_test.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/pages/business/business_kyb_logic.dart';

void main() {
  group('kybStateFor', () {
    test('maps Didit statuses', () {
      expect(kybStateFor('approved'), KybUiState.verified);
      expect(kybStateFor('declined'), KybUiState.declined);
      expect(kybStateFor('in_review'), KybUiState.inReview);
      expect(kybStateFor('in_progress'), KybUiState.pending);
      expect(kybStateFor('not_started'), KybUiState.pending);
      expect(kybStateFor('resubmitted'), KybUiState.actionNeeded);
      expect(kybStateFor(null), KybUiState.notStarted);
      expect(kybStateFor('none'), KybUiState.notStarted);
      expect(kybStateFor('abandoned'), KybUiState.notStarted);
    });

    test('start allowed only when not verified or in review', () {
      expect(kybCanStart(KybUiState.verified), isFalse);
      expect(kybCanStart(KybUiState.inReview), isFalse);
      expect(kybCanStart(KybUiState.declined), isTrue);
      expect(kybCanStart(KybUiState.notStarted), isTrue);
    });

    test('verified copy is Didit-only', () {
      expect(kybBody(KybUiState.verified), contains('Didit'));
      expect(kybBody(KybUiState.verified).toLowerCase(), isNot(contains('manual')));
      expect(kybBody(KybUiState.declined).toLowerCase(), contains('no manual option'));
      expect(kybAllowsApplicationSubmit(KybUiState.notStarted), isFalse);
      expect(kybAllowsApplicationSubmit(KybUiState.verified), isTrue);
    });
  });

  group('kybErrorMessage', () {
    test('503 explains KYB is not configured, no fake success', () {
      final m = kybErrorMessage(
          const ApiServiceException(statusCode: 503, message: 'x'));
      expect(m, contains('not available yet'));
      expect(m.toLowerCase(), contains('manual kyb is not available'));
    });
    test('409 passes server message', () {
      expect(
          kybErrorMessage(const ApiServiceException(
              statusCode: 409, message: 'already complete')),
          'already complete');
    });
    test('unknown error is generic', () {
      expect(kybErrorMessage(Exception('boom')), contains('Could not start'));
    });
  });

  group('kybAdminSummary', () {
    test('no KYB data', () {
      expect(kybAdminSummary(null), {'Didit KYB': 'Not started'});
    });
    test('summarises decision without inventing data', () {
      final rows = kybAdminSummary({
        'status': 'approved',
        'entity_status': null,
        'session_id': 's1',
        'result': {
          'decision': {
            'registry_checks': [
              {'status': 'Approved'}
            ],
            'aml_screenings': [],
          }
        },
      });
      expect(rows['Didit KYB status'], 'approved');
      expect(rows['Didit entity status'], '—');
      expect(rows['Registry checks'], 'Approved');
      expect(rows['AML screenings'], '—');
      expect(rows['Key people checks'], '—');
      expect(rows['Documents'], '—');
    });
  });
}
