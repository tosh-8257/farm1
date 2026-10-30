import '/backend/services/api_service.dart';

/// KYB statuses as returned by the backend.
class BusinessStatus {
  static const notStarted = 'not_started';
  static const draft = 'draft';
  static const underReview = 'under_review';
  static const moreInfo = 'more_information_required';
  static const approved = 'approved';
  static const rejected = 'rejected';

  static const editable = {draft, moreInfo, rejected};

  static String label(String? s) {
    switch (s) {
      case draft:
        return 'Draft';
      case underReview:
        return 'Under Review';
      case moreInfo:
        return 'More Information Required';
      case approved:
        return 'Approved';
      case rejected:
        return 'Rejected';
      default:
        return 'Not started';
    }
  }
}

class BusinessApiService {
  static Map<String, dynamic> _data(Map<String, dynamic> resp) {
    final d = resp['data'];
    return d is Map ? Map<String, dynamic>.from(d) : resp;
  }

  /// `{business: {...}|null, eligibility: {can_upgrade, reason}}`
  static Future<Map<String, dynamic>> getMine() async =>
      _data(await ApiService.request(method: 'GET', path: '/business/me'));

  static Future<Map<String, dynamic>> upgrade() async => _data(
    await ApiService.request(method: 'POST', path: '/business/upgrade'),
  );

  static Future<Map<String, dynamic>> saveDraft(
    Map<String, dynamic> body,
  ) async => _data(
    await ApiService.request(
      method: 'PUT',
      path: '/business/draft',
      body: body,
    ),
  );

  static Future<Map<String, dynamic>> submit() async =>
      _data(await ApiService.request(method: 'POST', path: '/business/submit'));
}
