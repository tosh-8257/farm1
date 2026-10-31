import '/backend/services/api_service.dart';
import 'business_ops_api.dart';

/// V2 Phase 4 investment marketplace. Eligibility, limits, risk disclosure
/// and all money movement are enforced by the server.
class InvestmentsApi {
  static Future<Map<String, dynamic>> _call(String method, String path,
          [Map<String, dynamic>? body]) =>
      ApiService.request(method: method, path: path, body: body);

  static Map<String, dynamic> _d(Map<String, dynamic> r) => BusinessOpsApi.data(r);
  static List<Map<String, dynamic>> _l(Map<String, dynamic> r) => BusinessOpsApi.list(r);

  static String _q(Map<String, String?> p) {
    final parts = p.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}');
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // Marketplace
  static Future<List<Map<String, dynamic>>> projects({String? sector, String? search, String? status}) async =>
      _l(await _call('GET', '/marketplace/projects${_q({'sector': sector, 'search': search, 'status': status})}'));
  static Future<Map<String, dynamic>> project(String id) async =>
      _d(await _call('GET', '/marketplace/projects/$id'));
  static Future<Map<String, dynamic>> eligibility() async =>
      _d(await _call('GET', '/marketplace/eligibility'));
  static Future<Map<String, dynamic>> requestEligibility() async =>
      _d(await _call('POST', '/marketplace/eligibility/request'));
  static Future<Map<String, dynamic>> invest(String id,
          {required double amount, required String pin, required String disclosureVersion}) async =>
      _d(await _call('POST', '/marketplace/projects/$id/invest', {
        'amount': amount,
        'pin': pin,
        'accept_risk': true,
        'disclosure_version': disclosureVersion,
      }));

  // Portfolio
  static Future<Map<String, dynamic>> portfolio() async =>
      _d(await _call('GET', '/marketplace/portfolio'));
  static Future<List<Map<String, dynamic>>> history() async =>
      _l(await _call('GET', '/marketplace/portfolio/history?limit=100'));
  static Future<List<Map<String, dynamic>>> documents() async =>
      _l(await _call('GET', '/marketplace/portfolio/documents'));
  static Future<List<Map<String, dynamic>>> updates() async =>
      _l(await _call('GET', '/marketplace/portfolio/updates'));

  // Business projects
  static Future<List<Map<String, dynamic>>> myProjects() async =>
      _l(await _call('GET', '/business/projects'));
  static Future<Map<String, dynamic>> myProject(String id) async =>
      _d(await _call('GET', '/business/projects/$id'));
  static Future<Map<String, dynamic>> createProject(Map<String, dynamic> body) async =>
      _d(await _call('POST', '/business/projects', body));
  static Future<Map<String, dynamic>> updateProject(String id, Map<String, dynamic> body) async =>
      _d(await _call('PATCH', '/business/projects/$id', body));
  static Future<Map<String, dynamic>> addDocument(String id,
          {required String kind, required String title, required String url, String visibility = 'investors'}) async =>
      _d(await _call('POST', '/business/projects/$id/documents',
          {'kind': kind, 'title': title, 'url': url, 'visibility': visibility}));
  static Future<void> removeDocument(String id, String docId) =>
      _call('DELETE', '/business/projects/$id/documents/$docId');
  static Future<Map<String, dynamic>> submitProject(String id) async =>
      _d(await _call('POST', '/business/projects/$id/submit'));
  static Future<Map<String, dynamic>> postUpdate(String id, String title, String body) async =>
      _d(await _call('POST', '/business/projects/$id/updates', {'title': title, 'body': body}));
  // Phase 5: Algorand tokenization (backend decides everything; disabled until configured)
  static Future<List<Map<String, dynamic>>> myTokens() async => _l(await _call('GET', '/investments/tokens'));
  static Future<Map<String, dynamic>> projectToken(String id) async => await _call('GET', '/business/projects/$id/tokenization');
  /// mode 'on_invest' = minted at listing, delivered to investors as they invest.
  static Future<Map<String, dynamic>> requestToken(String id, String assetName, String unitName, {String? mode}) async =>
      _d(await _call('POST', '/business/projects/$id/tokenization',
          {'asset_name': assetName, 'unit_name': unitName, 'accept_buyback_commitment': true, if (mode != null) 'mode': mode}));
  /// Send tokens to another FARM user (username or phone). No transfer fee.
  static Future<Map<String, dynamic>> sendTokens(String allocationId, String recipient, int units, String pin) async =>
      await _call('POST', '/investments/tokens/$allocationId/send', {'recipient_identifier': recipient, 'units': units, 'pin': pin});
  static Future<List<Map<String, dynamic>>> tokenIncome() async => _l(await _call('GET', '/investments/tokens/income'));
  static Future<List<Map<String, dynamic>>> tokenTransfers() async => _l(await _call('GET', '/investments/tokens/transfers'));
  static Future<List<Map<String, dynamic>>> projectDistributions(String id) async =>
      _l(await _call('GET', '/business/projects/$id/distributions'));
  /// Pay token holders profit or rental income in FARM. Needs FARM approval.
  static Future<Map<String, dynamic>> requestDistribution(String id, num amount, String kind, String description) async =>
      await _call('POST', '/business/projects/$id/distributions',
          {'amount': amount, 'kind': kind, if (description.isNotEmpty) 'description': description});
  /// Sell tokens back to FARM (1 FARM each) from the project's 15% buyback fund. Needs admin approval.
  static Future<Map<String, dynamic>> sellBack(String allocationId, int units) async =>
      await _call('POST', '/investments/tokens/$allocationId/sell-back', {'units': units});
  static Future<Map<String, dynamic>> setMilestones(String id, List<Map<String, dynamic>> items) async =>
      _d(await _call('PATCH', '/business/projects/$id/milestones', {'milestones': items}));
  static Future<Map<String, dynamic>> requestMilestone(String id, String mid,
          {required String evidence, String? evidenceUrl}) async =>
      _d(await _call('POST', '/business/projects/$id/milestones/$mid/request', {
        'evidence': evidence,
        if (evidenceUrl != null && evidenceUrl.isNotEmpty) 'evidence_url': evidenceUrl,
      }));
}

const milestoneStatusLabels = {
  'planned': 'Planned',
  'requested': 'Release requested',
  'returned': 'Returned',
  'released': 'Released',
};

const sectorLabels = {
  'agriculture': 'Agriculture',
  'energy': 'Energy',
  'real_estate': 'Real estate',
  'infrastructure': 'Infrastructure',
  'technology': 'Technology',
  'manufacturing': 'Manufacturing',
  'other': 'Other',
};

const instrumentLabels = {
  'equity': 'Equity',
  'debt': 'Debt',
  'revenue_share': 'Revenue share',
  'asset_backed': 'Asset backed',
  'other': 'Other',
};

const documentKindLabels = {
  'business_plan': 'Business plan',
  'financial_statements': 'Financial statements',
  'financial_projections': 'Financial projections',
  'licence_permit': 'Licence / permit',
  'land_title_lease': 'Land title / lease',
  'pitch_deck': 'Pitch deck',
  'valuation_report': 'Valuation report',
  'legal_agreement': 'Legal agreement',
  'environmental_assessment': 'Environmental assessment',
  'other': 'Other',
};

const projectStatusLabels = {
  'draft': 'Draft',
  'submitted': 'Under review',
  'more_info_required': 'More info needed',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'listed': 'Listed',
  'funded': 'Funded',
  'closed': 'Closed',
  'cancelled': 'Cancelled',
  'committed': 'Held until settlement',
  'active': 'Active',
  'refunded': 'Refunded',
};

const tokenStatusLabels = {
  'requested': 'Requested',
  'creating': 'Creating on Algorand',
  'created': 'Created',
  'failed': 'Failed (FARM will retry)',
  'rejected': 'Rejected',
};

/// Per-investor token allocation status (tokenize-as-you-invest).
const allocationStatusLabels = {
  'held': 'Held by FARM',
  'owed': 'Owed · sent when your wallet is ready',
  'sending': 'Sending to your wallet',
  'delivered': 'In your wallet',
  'clawback_pending': 'Being returned (project cancelled)',
  'clawing': 'Being returned (project cancelled)',
  'clawed_back': 'Returned (project cancelled)',
  'cancelled': 'Cancelled',
  'sold_back': 'Sold back to FARM',
  'incoming': 'Arriving in your wallet',
  'transferred': 'Sent to another user',
};
