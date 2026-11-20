/// A project can be saved as a draft once the name is present. The server
/// still checks every field again.
bool projectIsFilled(Map<dynamic, dynamic> project) {
  final name = '${project['project_name'] ?? ''}'.trim();
  final target = num.tryParse('${project['target_amount'] ?? ''}') ?? 0;
  final summary = '${project['summary'] ?? ''}'.trim();
  final description = '${project['description'] ?? ''}'.trim();
  return name.length >= 3 && target > 0 && (summary.isNotEmpty || description.isNotEmpty);
}

const submitForTokenizationLabel = 'Submit for tokenization';

/// Owners can discard only their own draft. Submitted and later states stay.
bool projectCanDiscard(String status) => status == 'draft';

/// The application is complete when the server would accept a review submit:
/// narrative, funding, milestones that add up, and the required documents.
bool projectApplicationComplete(Map<dynamic, dynamic> project) {
  if (!projectIsFilled(project)) return false;
  bool text(String key) => '${project[key] ?? ''}'.trim().isNotEmpty;
  if (!text('description') ||
      !text('use_of_funds') ||
      !text('risk_factors') ||
      !text('location') ||
      !text('sector') ||
      !text('instrument_type')) {
    return false;
  }
  final target = num.tryParse('${project['target_amount'] ?? ''}') ?? 0;
  final minimum = num.tryParse('${project['minimum_investment'] ?? ''}') ?? 0;
  if (minimum <= 0 || minimum > target) return false;
  final maxRaw = '${project['maximum_investment'] ?? ''}'.trim();
  if (maxRaw.isNotEmpty) {
    final maximum = num.tryParse(maxRaw) ?? 0;
    if (maximum < minimum) return false;
  }
  final milestones = ((project['milestones'] as List?) ?? const []).whereType<Map>().toList();
  if (milestones.isEmpty) return false;
  final sum = milestones.fold<num>(0, (total, row) => total + (num.tryParse('${row['amount']}') ?? 0));
  if ((sum - target).abs() > 0.005) return false;
  final required = ((project['required_documents'] as List?) ?? const ['business_plan', 'financial_statements'])
      .map((kind) => '$kind')
      .where((kind) => kind.isNotEmpty)
      .toSet();
  final have = ((project['documents'] as List?) ?? const [])
      .whereType<Map>()
      .map((doc) => '${doc['kind']}')
      .toSet();
  return required.every(have.contains);
}

/// An uploaded cover wins. A website typed into the cover field is not sent
/// as the photo, so the upload still saves.
String? coverUrlForSave({required String typed, String? uploaded}) {
  final photo = (uploaded ?? '').trim();
  final text = typed.trim();
  if (photo.isNotEmpty &&
      _httpsImage(photo) &&
      (text.isEmpty || text == photo || !_httpsImage(text))) {
    return photo;
  }
  if (_httpsImage(text)) return text;
  return null;
}

bool looksLikeCoverImage(String url) => _httpsImage(url.trim());

bool _httpsImage(String url) {
  if (!url.toLowerCase().startsWith('https://')) return false;
  final path = url.toLowerCase().split('?').first;
  return path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.contains('cloudinary') ||
      path.contains('/image/upload/');
}

/// Follows the backend flag. A missing flag does not block Mainnet.
/// An explicit false does.
bool backendAllowsTokenization(Map<dynamic, dynamic> status, {required bool funded}) {
  final enabled = status.containsKey('enabled') ? status['enabled'] == true : null;
  final onInvest = status.containsKey('on_invest_enabled') ? status['on_invest_enabled'] == true : null;
  if (funded) return enabled != false;
  if (onInvest == true || enabled == true) return true;
  if (onInvest == null && enabled == null) return true;
  return false;
}

String tokenizationTitle(Map<dynamic, dynamic> status) {
  final raw = '${status['network'] ?? status['algorand_network'] ?? ''}'.toLowerCase();
  if (raw.contains('test')) return 'Tokenization (Algorand TestNet)';
  return 'Tokenization (Algorand Mainnet)';
}

/// Submit for tokenization only after a complete application (or a funded
/// project) and only when the backend flag allows it.
bool showTokenizationSubmit({
  required String projectStatus,
  required bool applicationComplete,
  required Map<dynamic, dynamic> tokenization,
}) {
  final funded = projectStatus == 'funded' || projectStatus == 'closed';
  if (funded) {
    return backendAllowsTokenization(tokenization, funded: true);
  }
  const ready = {'', 'draft', 'more_info_required', 'approved'};
  if (!ready.contains(projectStatus)) return false;
  if (!applicationComplete) return false;
  return backendAllowsTokenization(tokenization, funded: false);
}

/// What the business sees. `submitted` is not the same as `under review`.
String projectLifecycleLabel(String status) {
  switch (status) {
    case '':
    case 'draft':
      return 'Draft';
    case 'submitted':
      return 'Submitted';
    case 'under_review':
    case 'in_review':
      return 'Under review';
    case 'approved':
      return 'Approved';
    case 'listed':
      return 'Listed';
    case 'rejected':
      return 'Rejected';
    case 'more_info_required':
      return 'More info needed';
    case 'discarded':
      return 'Discarded';
    default:
      return status.replaceAll('_', ' ');
  }
}
