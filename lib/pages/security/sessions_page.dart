import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/backend/services/api_service.dart';
import '/pages/devices/trusted_devices_page.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/security/session_security.dart';
import '/services/auth/session_end.dart';

class _SecuritySnapshot {
  const _SecuritySnapshot({
    required this.sessions,
    required this.pushDevices,
    required this.trustedDevices,
  });

  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> pushDevices;
  final List<Map<String, dynamic>> trustedDevices;
}

/// Active logins, push registrations, and trusted phones.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  Future<_SecuritySnapshot> _load() async {
    final results = await Future.wait<dynamic>([
      ApiService.getSessions(),
      ApiService.getPushDevices().catchError((_) => <String, dynamic>{}),
      ApiService.listTrustedDevices().catchError((_) => <String, dynamic>{}),
    ]);
    return _SecuritySnapshot(
      sessions: mapsFromResponse(results[0], keys: const ['sessions']),
      pushDevices: mapsFromResponse(results[1], keys: const ['devices']),
      trustedDevices: mapsFromResponse(
        results[2],
        keys: const ['devices', 'data'],
      ),
    );
  }

  Future<void> _afterCurrentSessionEnded(BuildContext context) async {
    await SessionEnd.forceLocalSignOut('revoked current session');
    if (!context.mounted) return;
    final router = GoRouter.maybeOf(context);
    if (router != null) router.go('/loginpage');
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Devices & sessions',
      body: BizAsync<_SecuritySnapshot>(
        load: _load,
        isEmpty: (snapshot) =>
            snapshot.sessions.isEmpty &&
            snapshot.pushDevices.isEmpty &&
            snapshot.trustedDevices.isEmpty,
        emptyIcon: Icons.devices_outlined,
        emptyTitle: 'No sessions found',
        emptyMessage: 'Your sign-ins will appear here.',
        builder: (context, snapshot, reload) {
          final current = currentSession(snapshot.sessions);
          final active =
              snapshot.sessions.where(sessionIsActive).toList(growable: false);
          final others = active.where((session) => session['is_current'] != true);
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'This device',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (current == null)
                  Text(
                    'This sign-in is not listed yet. Pull to refresh.',
                    style: TextStyle(color: mutedColor(context)),
                  )
                else
                  _SessionTile(
                    session: current,
                    current: current,
                    onSignOut: () => _signOutSession(context, current, reload),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Other active sessions',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (others.isEmpty)
                  Text(
                    'No other devices are signed in.',
                    style: TextStyle(color: mutedColor(context)),
                  ),
                for (final session in others)
                  _SessionTile(
                    session: session,
                    current: current,
                    onSignOut: () => _signOutSession(context, session, reload),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('sign-out-other-devices'),
                  style: secondaryButtonStyle(context),
                  onPressed: others.isEmpty
                      ? null
                      : () async {
                          final confirmed = await confirmAction(
                            context,
                            title: 'Sign out other devices?',
                            message:
                                'Every session except this one will be signed out and will stop receiving your notifications.',
                            confirm: 'Sign out',
                          );
                          if (!confirmed || !context.mounted) return;
                          final result = await runBusy(
                            context,
                            ApiService.revokeOtherSessions,
                            success: 'Other devices signed out',
                          );
                          if (result != null) reload();
                        },
                  child: const Text('Sign out all other devices'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('sign-out-everywhere'),
                  style: secondaryButtonStyle(context),
                  onPressed: () async {
                    final confirmed = await confirmAction(
                      context,
                      title: 'Sign out everywhere?',
                      message:
                          'This phone and every other device will be signed out. You will need to sign in again.',
                      confirm: 'Sign out everywhere',
                    );
                    if (!confirmed || !context.mounted) return;
                    final result = await runBusy(
                      context,
                      ApiService.revokeAllSessions,
                      success: 'Signed out everywhere',
                    );
                    if (result != null && context.mounted) {
                      await _afterCurrentSessionEnded(context);
                    }
                  },
                  child: const Text('Sign out everywhere'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Push notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (snapshot.pushDevices.isEmpty)
                  Text(
                    'No push devices are registered to this account.',
                    style: TextStyle(color: mutedColor(context)),
                  ),
                for (final device in snapshot.pushDevices)
                  BizTile(
                    leading: Icons.notifications_outlined,
                    title: pushDeviceLabel(device),
                    subtitle: _pushSubtitle(device),
                    trailing: StatusChip(
                      device['is_active'] == true ? 'Push on' : 'Push off',
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Trusted devices',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                if (snapshot.trustedDevices.isEmpty)
                  Text(
                    'No trusted phones yet.',
                    style: TextStyle(color: mutedColor(context)),
                  ),
                for (final device in snapshot.trustedDevices)
                  BizTile(
                    leading: Icons.phonelink_lock_outlined,
                    title: _trustedTitle(device),
                    subtitle: _trustedSubtitle(device),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrustedDevicesPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Manage trusted devices',
                      style: TextStyle(color: fgColor(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Login history',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                for (final session in snapshot.sessions)
                  _SessionTile(
                    session: session,
                    current: current,
                    onSignOut: null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOutSession(
    BuildContext context,
    Map<String, dynamic> session,
    Future<void> Function() reload,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Sign out this session?',
      message: sessionDeviceLabel(session),
      confirm: 'Sign out',
    );
    if (!confirmed || !context.mounted) return;
    final endedHere = session['is_current'] == true;
    final result = await runBusy(
      context,
      () => ApiService.revokeSession(sessionId: '${session['id']}'),
      success: endedHere ? 'Signed out' : 'Session signed out',
    );
    if (result == null || !context.mounted) return;
    if (endedHere) {
      await _afterCurrentSessionEnded(context);
      return;
    }
    reload();
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.current,
    required this.onSignOut,
  });

  final Map<String, dynamic> session;
  final Map<String, dynamic>? current;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final active = sessionIsActive(session);
    final attention = sessionAttention(session, current: current);
    final currentHere = session['is_current'] == true;
    final pushOn = session['push_registered'] == true;
    final lastActive = session['last_active_at'] ?? session['used_at'];
    final ip = '${session['ip_address'] ?? ''}'.trim();
    final subtitle = [
      if (currentHere) 'This device',
      if (ip.isNotEmpty) 'IP $ip',
      if (lastActive != null) 'Active ${formatSessionWhen(lastActive)}',
      pushOn ? 'Push on' : 'Push off',
    ].join(' · ');
    return BizTile(
      leading: currentHere
          ? Icons.smartphone_rounded
          : active
              ? Icons.login_rounded
              : Icons.history_rounded,
      title: sessionDeviceLabel(session),
      subtitle: subtitle,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (currentHere) const StatusChip('Current'),
          if (attention != null) ...[
            const SizedBox(height: 4),
            StatusChip(attention),
          ],
          if (!active)
            StatusChip(session['is_revoked'] == true ? 'Signed out' : 'Expired'),
          if (active && onSignOut != null)
            TextButton(
              key: Key('revoke-session-${session['id']}'),
              onPressed: () => onSignOut!(),
              child: Text('Sign out', style: TextStyle(color: fgColor(context))),
            ),
        ],
      ),
    );
  }
}

String _pushSubtitle(Map<String, dynamic> device) {
  final seen = device['last_seen'];
  final session = device['session'];
  final current = session is Map && session['is_current'] == true;
  return [
    if (current) 'This device',
    if (seen != null) 'Last seen ${formatSessionWhen(seen)}',
    if (device['is_active'] != true) 'Not receiving notifications',
  ].join(' · ');
}

String _trustedTitle(Map<String, dynamic> device) {
  final name = '${device['name'] ?? device['device_name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  final platform = '${device['platform'] ?? device['os'] ?? ''}'.trim();
  return platform.isEmpty ? 'Trusted phone' : platform;
}

String _trustedSubtitle(Map<String, dynamic> device) {
  final status = '${device['status'] ?? device['state'] ?? ''}'.trim();
  final seen = device['last_seen'] ?? device['last_used_at'];
  return [
    if (status.isNotEmpty) status,
    if (seen != null) 'Last seen ${formatSessionWhen(seen)}',
  ].join(' · ');
}
