import 'package:flutter/material.dart';
import '/backend/services/api_service.dart';
import '/pages/business/ops/ops_ui.dart';

/// Devices, login history and session management, from the server's real session records.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await ApiService.getSessions();
    final s = r['sessions'] ?? (r['data'] is Map ? (r['data'] as Map)['sessions'] : r['data']);
    return (s as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static bool _active(Map s) {
    final exp = DateTime.tryParse('${s['expires_at'] ?? ''}');
    return s['is_revoked'] != true && (exp == null || exp.isAfter(DateTime.now()));
  }

  static String _device(Map s) {
    final n = '${s['device_name'] ?? ''}'.trim(), os = '${s['device_os'] ?? ''}'.trim();
    if (n.isEmpty && os.isEmpty) return 'Unknown device';
    return [n, os].where((x) => x.isNotEmpty).join(' · ');
  }

  static String _when(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${shortDate(iso)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext c) {
    final key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
    return BizScaffold(
      title: 'Devices & sessions',
      body: BizAsync<List<Map<String, dynamic>>>(
        key: key,
        load: _load,
        isEmpty: (l) => l.isEmpty,
        emptyIcon: Icons.devices_outlined,
        emptyTitle: 'No sessions found',
        emptyMessage: 'Your sign-ins will appear here.',
        builder: (c, list, reload) {
          final active = list.where(_active).toList();
          final devices = <String>{for (final s in active) _device(s)};
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('Signed-in devices', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              if (devices.isEmpty) Text('No active devices.', style: TextStyle(color: mutedColor(c))),
              for (final d in devices)
                BizTile(leading: Icons.smartphone_outlined, title: d, subtitle: '${active.where((s) => _device(s) == d).length} active session(s)'),
              const SizedBox(height: 8),
              if (active.length > 1)
                OutlinedButton(
                  style: secondaryButtonStyle(c),
                  onPressed: () async {
                    if (!await confirmAction(c,
                        title: 'Sign out other devices?', message: 'Every session except this one will be signed out.', confirm: 'Sign out')) return;
                    if (!c.mounted) return;
                    final r = await runBusy(c, ApiService.revokeOtherSessions, success: 'Other devices signed out');
                    if (r != null) reload();
                  },
                  child: const Text('Sign out all other devices'),
                ),
              const SizedBox(height: 20),
              Text('Login history', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              for (final s in list)
                BizTile(
                  leading: _active(s) ? Icons.login_rounded : Icons.history_rounded,
                  title: _device(s),
                  subtitle: [
                    'Signed in ${_when(s['created_at'])}',
                    if (s['ip_address'] != null) 'IP ${s['ip_address']}',
                    if (s['used_at'] != null) 'last used ${_when(s['used_at'])}',
                  ].join(' · '),
                  trailing: _active(s)
                      ? TextButton(
                          onPressed: () async {
                            if (!await confirmAction(c, title: 'Sign out this session?', message: _device(s), confirm: 'Sign out')) return;
                            if (!c.mounted) return;
                            final r = await runBusy(c, () => ApiService.revokeSession(sessionId: '${s['id']}'), success: 'Signed out');
                            if (r != null) reload();
                          },
                          child: Text('Sign out', style: TextStyle(color: fgColor(c))),
                        )
                      : StatusChip(s['is_revoked'] == true ? 'Signed out' : 'Expired'),
                ),
            ]),
          );
        },
      ),
    );
  }
}
