/// A project can be sent for tokenization once the fields the form requires
/// are present. The server still accepts or rejects the request.
bool projectIsFilled(Map<dynamic, dynamic> project) {
  final name = '${project['project_name'] ?? ''}'.trim();
  final target = num.tryParse('${project['target_amount'] ?? ''}') ?? 0;
  final summary = '${project['summary'] ?? ''}'.trim();
  final description = '${project['description'] ?? ''}'.trim();
  return name.length >= 3 && target > 0 && (summary.isNotEmpty || description.isNotEmpty);
}

const submitForTokenizationLabel = 'Submit for tokenization';
