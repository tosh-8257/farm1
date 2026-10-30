import '/backend/services/api_service.dart';

/// Phase 2 business operations. All money logic and permission checks
/// happen on the server; this class only moves JSON.
class BusinessOpsApi {
  static Future<Map<String, dynamic>> _call(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      ApiService.request(method: method, path: path, body: body);

  static Map<String, dynamic> data(Map<String, dynamic> r) {
    final d = r['data'];
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  static List<Map<String, dynamic>> list(Map<String, dynamic> r) {
    final d = r['data'];
    if (d is! List) return const [];
    return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _q(Map<String, String?> p) {
    final parts = p.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value!)}');
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // Context / dashboard
  static Future<Map<String, dynamic>> context() async =>
      data(await _call('GET', '/business/context'));
  static Future<Map<String, dynamic>> dashboard() async =>
      data(await _call('GET', '/business/dashboard'));
  static Future<Map<String, dynamic>> wallet() async =>
      data(await _call('GET', '/business/wallet'));
  static Future<Map<String, dynamic>> analytics(String range) async =>
      data(await _call('GET', '/business/analytics${_q({'range': range})}'));

  // Transactions
  static Future<List<Map<String, dynamic>>> transactions({String? status, int page = 1}) async =>
      list(await _call('GET', '/business/transactions${_q({'status': status, 'page': '$page', 'limit': '50'})}'));
  static Future<Map<String, dynamic>> transaction(String id) async =>
      data(await _call('GET', '/business/transactions/$id'));

  // Payouts
  static Future<List<Map<String, dynamic>>> payouts() async =>
      list(await _call('GET', '/business/payouts?limit=50'));
  static Future<Map<String, dynamic>> requestPayout(Map<String, dynamic> body) async =>
      data(await _call('POST', '/business/payouts', body));

  // Team
  static Future<Map<String, dynamic>> team() => _call('GET', '/business/team');
  static Future<void> addMember(String identifier, String role, String pin) =>
      _call('POST', '/business/team', {'identifier': identifier, 'role': role, 'pin': pin});
  static Future<void> updateMember(String id, String role, String pin) =>
      _call('PATCH', '/business/team/$id', {'role': role, 'pin': pin});
  static Future<void> removeMember(String id, String pin) =>
      _call('POST', '/business/team/$id/remove', {'pin': pin});

  // Profile
  static Future<Map<String, dynamic>> profile() => _call('GET', '/business/profile');
  static Future<void> updateProfile(Map<String, dynamic> body) =>
      _call('PUT', '/business/profile', body);

  // Customers
  static Future<List<Map<String, dynamic>>> customers({String? search}) async =>
      list(await _call('GET', '/business/customers${_q({'search': search, 'limit': '100'})}'));
  static Future<Map<String, dynamic>> customer(String id) async =>
      data(await _call('GET', '/business/customers/$id'));
  static Future<Map<String, dynamic>> saveCustomer(Map<String, dynamic> body, {String? id}) async =>
      data(await _call(id == null ? 'POST' : 'PUT', '/business/customers${id == null ? '' : '/$id'}', body));

  // Invoices
  static Future<List<Map<String, dynamic>>> invoices({String? status}) async =>
      list(await _call('GET', '/business/invoices${_q({'status': status, 'limit': '100'})}'));
  static Future<Map<String, dynamic>> invoice(String id) async =>
      data(await _call('GET', '/business/invoices/$id'));
  static Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body) async =>
      data(await _call('POST', '/business/invoices', body));
  static Future<Map<String, dynamic>> invoiceAction(String id, String action) async =>
      data(await _call('POST', '/business/invoices/$id/$action'));

  // Payment links
  static Future<List<Map<String, dynamic>>> links() async =>
      list(await _call('GET', '/business/payment-links?limit=100'));
  static Future<Map<String, dynamic>> link(String id) async =>
      data(await _call('GET', '/business/payment-links/$id'));
  static Future<Map<String, dynamic>> createLink(Map<String, dynamic> body) async =>
      data(await _call('POST', '/business/payment-links', body));
  static Future<Map<String, dynamic>> setLinkActive(String id, bool active) async =>
      data(await _call('PATCH', '/business/payment-links/$id', {'is_active': active}));

  // Escrow
  static Future<List<Map<String, dynamic>>> escrows() async =>
      list(await _call('GET', '/business/escrows?limit=100'));
  static Future<Map<String, dynamic>> escrow(String id) async =>
      data(await _call('GET', '/business/escrows/$id'));
  static Future<Map<String, dynamic>> createEscrow(Map<String, dynamic> body) async =>
      data(await _call('POST', '/business/escrows', body));
  static Future<Map<String, dynamic>> escrowAction(String id, String action) async =>
      data(await _call('POST', '/business/escrows/$id/$action'));

  // Payer side
  static Future<Map<String, dynamic>> publicLink(String code) async =>
      data(await _call('GET', '/pay/links/${Uri.encodeComponent(code)}'));
  static Future<Map<String, dynamic>> payLink(String code, String pin) async =>
      data(await _call('POST', '/pay/links/${Uri.encodeComponent(code)}', {'pin': pin}));
  static Future<Map<String, dynamic>> publicInvoice(String number) async =>
      data(await _call('GET', '/pay/invoices/${Uri.encodeComponent(number)}'));
  static Future<Map<String, dynamic>> payInvoice(String number, String pin) async =>
      data(await _call('POST', '/pay/invoices/${Uri.encodeComponent(number)}', {'pin': pin}));
  static Future<Map<String, dynamic>> requestMilestone(String id, int index) async =>
      data(await _call('POST', '/business/escrows/$id/milestones/$index/request-release'));
  static Future<Map<String, dynamic>> releaseMilestone(String id, int index, String pin) async =>
      data(await _call('POST', '/pay/escrows/$id/milestones/$index/release', {'pin': pin}));
  static Future<List<Map<String, dynamic>>> incomingEscrows() async =>
      list(await _call('GET', '/pay/escrows'));
  static Future<Map<String, dynamic>> fundEscrow(String id, String pin) async =>
      data(await _call('POST', '/pay/escrows/$id/fund', {'pin': pin}));

  // Admin
  static Future<Map<String, dynamic>> adminBusinesses({String? status, int page = 1}) =>
      _call('GET', '/admin/businesses${_q({'status': status, 'page': '$page'})}');
  static Future<Map<String, dynamic>> adminBusiness(String id) async =>
      data(await _call('GET', '/admin/businesses/$id'));
  static Future<void> adminReview(String id, String decision, String? notes) =>
      _call('POST', '/admin/businesses/$id/review', {
        'decision': decision,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
}

const businessRoleLabels = {
  'owner': 'Owner',
  'admin': 'Admin',
  'finance': 'Finance',
  'accountant': 'Accountant',
  'operations': 'Operations',
  'developer': 'Developer',
};

String statusLabel(String? s) {
  if (s == null || s.isEmpty) return '—';
  final w = s.replaceAll('_', ' ');
  return w[0].toUpperCase() + w.substring(1);
}
