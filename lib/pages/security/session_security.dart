/// Presentation helpers for Devices & sessions. No I/O.
bool sessionIsActive(Map<dynamic, dynamic> session, {DateTime? now}) {
  if (session['is_revoked'] == true) return false;
  if (session['is_expired'] == true) return false;
  final clock = now ?? DateTime.now();
  final expires = DateTime.tryParse('${session['expires_at'] ?? ''}');
  if (expires != null && !expires.isAfter(clock)) return false;
  return true;
}

String sessionDeviceLabel(Map<dynamic, dynamic> session) {
  final name = '${session['device_name'] ?? ''}'.trim();
  final os = '${session['device_os'] ?? ''}'.trim();
  if (name.isEmpty && os.isEmpty) return 'Unknown device';
  return [name, os].where((part) => part.isNotEmpty).join(' · ');
}

/// `Unrecognized`, `Suspicious`, or `New` for an active session that is not
/// the one on this phone. Revoked and expired rows are history, not alerts.
String? sessionAttention(
  Map<dynamic, dynamic> session, {
  Map<dynamic, dynamic>? current,
  DateTime? now,
}) {
  if (session['is_current'] == true) return null;
  if (!sessionIsActive(session, now: now)) return null;
  final name = '${session['device_name'] ?? ''}'.trim().toLowerCase();
  if (name.isEmpty || name == 'unknown' || name == 'unknown device') {
    return 'Unrecognized';
  }
  final clock = now ?? DateTime.now();
  final created = DateTime.tryParse('${session['created_at'] ?? ''}');
  if (created != null &&
      !clock.isBefore(created) &&
      clock.difference(created) < const Duration(hours: 24)) {
    final currentIp = '${current?['ip_address'] ?? ''}'.trim();
    final ip = '${session['ip_address'] ?? ''}'.trim();
    if (currentIp.isNotEmpty && ip.isNotEmpty && ip != currentIp) {
      return 'Suspicious';
    }
    return 'New';
  }
  return null;
}

String formatSessionWhen(dynamic iso) {
  final parsed = DateTime.tryParse('${iso ?? ''}');
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

List<Map<String, dynamic>> mapsFromResponse(
  dynamic root, {
  List<String> keys = const ['sessions', 'devices', 'data'],
}) {
  dynamic node = root;
  if (node is Map && node['data'] != null) {
    final data = node['data'];
    if (data is List) {
      node = data;
    } else if (data is Map) {
      node = data;
    }
  }
  if (node is Map) {
    for (final key in keys) {
      final value = node[key];
      if (value is List) {
        node = value;
        break;
      }
    }
  }
  if (node is! List) return const [];
  return node
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}

Map<String, dynamic>? currentSession(List<Map<String, dynamic>> sessions) {
  for (final session in sessions) {
    if (session['is_current'] == true) return session;
  }
  return null;
}

String pushDeviceLabel(Map<String, dynamic> device) {
  final platform = '${device['platform'] ?? ''}'.trim();
  final session = device['session'];
  if (session is Map) {
    final label = sessionDeviceLabel(Map<String, dynamic>.from(session));
    if (platform.isEmpty) return label;
    return '$label · ${platform.toLowerCase()}';
  }
  if (platform.isEmpty) return 'Push device';
  return platform.toLowerCase();
}
