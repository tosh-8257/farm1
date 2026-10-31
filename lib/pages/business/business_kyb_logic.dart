import '/utils/user_error_message.dart';
import '/backend/services/api_service.dart';

/// UI states for the Didit KYB (business verification) step.
enum KybUiState { notStarted, pending, inReview, verified, declined, actionNeeded }

/// Maps the backend's normalised Didit KYB status to a UI state.
/// The Didit result is advisory: FARM compliance still approves manually.
KybUiState kybStateFor(String? status) {
  switch (status) {
    case 'approved':
      return KybUiState.verified;
    case 'declined':
      return KybUiState.declined;
    case 'in_review':
      return KybUiState.inReview;
    case 'resubmitted':
      return KybUiState.actionNeeded;
    case 'not_started':
    case 'in_progress':
    case 'awaiting_user':
      return KybUiState.pending;
    default:
      // none, abandoned, expired, kyb_expired, unknown → may (re)start.
      return KybUiState.notStarted;
  }
}

String kybTitle(KybUiState s) => const {
      KybUiState.notStarted: 'Verify your business',
      KybUiState.pending: 'Verification in progress',
      KybUiState.inReview: 'Verification under review',
      KybUiState.verified: 'Business verified',
      KybUiState.declined: 'Verification declined',
      KybUiState.actionNeeded: 'More information needed',
    }[s]!;

String kybBody(KybUiState s) => const {
      KybUiState.notStarted:
          'FARM uses Didit to check the company registry, officers, shareholders and beneficial owners, and to run AML screening. It opens in your browser.',
      KybUiState.pending:
          'Finish the Didit steps in your browser. When you are done, come back and tap Refresh.',
      KybUiState.inReview:
          'Didit is reviewing your business. This can take a while; you can continue and submit your application.',
      KybUiState.verified:
          'Didit has verified your business. FARM compliance will still review your application before it is approved.',
      KybUiState.declined:
          'Didit could not verify your business. Check your registry details and try again, or submit and our team will review it.',
      KybUiState.actionNeeded:
          'Didit needs more information. Open verification again to resubmit.',
    }[s]!;

/// Whether the owner may start (or restart) a Didit KYB session.
bool kybCanStart(KybUiState s) =>
    s == KybUiState.notStarted ||
    s == KybUiState.pending ||
    s == KybUiState.declined ||
    s == KybUiState.actionNeeded;

String kybStartLabel(KybUiState s) =>
    s == KybUiState.notStarted ? 'Verify business' : 'Open verification again';

/// Friendly message for errors when starting KYB.
String kybErrorMessage(Object error) {
  if (error is ApiServiceException) {
    if (error.statusCode == 503) {
      return 'Business verification is not available yet. You can still submit your application for manual review.';
    }
    if (error.statusCode == 409) return error.message;
    if (error.statusCode == 429) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (error.statusCode >= 500) {
      return 'Could not reach the verification provider. Please try again.';
    }
    return error.message;
  }
  return userErrorMessage(error,
      fallback: 'Could not start business verification. Please try again.');
}

/// Summary rows for the admin review screen from the stored Didit result.
/// Missing data is shown as "—"; nothing is invented.
Map<String, String> kybAdminSummary(Map<String, dynamic>? kyb) {
  if (kyb == null) return const {'Didit KYB': 'Not started'};
  String s(Object? v) => (v == null || '$v'.isEmpty) ? '—' : '$v';
  final result = kyb['result'] is Map
      ? Map<String, dynamic>.from(kyb['result'] as Map)
      : <String, dynamic>{};
  final decision = result['decision'] is Map
      ? Map<String, dynamic>.from(result['decision'] as Map)
      : <String, dynamic>{};
  String count(String key) {
    final v = decision[key];
    return v is List ? '${v.length}' : '—';
  }

  String featureStatus(String key) {
    final v = decision[key];
    if (v is! List || v.isEmpty) return '—';
    final statuses = v
        .whereType<Map>()
        .map((e) => e['status']?.toString())
        .whereType<String>()
        .toSet();
    return statuses.isEmpty ? '${v.length} item(s)' : statuses.join(', ');
  }

  return {
    'Didit KYB status': s(kyb['status']),
    'Didit entity status': s(kyb['entity_status']),
    'Session ID': s(kyb['session_id']),
    'Last update': s(kyb['updated_at']),
    'Registry checks': featureStatus('registry_checks'),
    'Key people checks': featureStatus('key_people_checks'),
    'AML screenings': featureStatus('aml_screenings'),
    'Documents': count('document_verifications'),
  };
}
