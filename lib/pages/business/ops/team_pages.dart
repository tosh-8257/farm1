import 'package:flutter/material.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});
  @override
  State<TeamPage> createState() => _TeamState();
}

class _TeamState extends State<TeamPage> {
  final _key = GlobalKey<BizAsyncState<Map<String, dynamic>>>();
  List<String> _assignable = const [];

  String _name(Map? u) {
    if (u == null) return 'Unknown';
    return '${u['full_name'] ?? u['username'] ?? u['phone'] ?? u['email'] ?? 'Unknown'}';
  }

  Future<String?> _pickRole(String? current) => showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choose role'),
          children: [
            for (final r in _assignable)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, r),
                child: Text('${businessRoleLabels[r]}${r == current ? ' (current)' : ''}'),
              ),
          ],
        ),
      );

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final ident = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add team member'),
        content: TextField(controller: ctrl, autofocus: true, decoration: bizInput(ctx, 'Username, phone or email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Next')),
        ],
      ),
    );
    ctrl.dispose();
    if (ident == null || ident.isEmpty || !mounted) return;
    final role = await _pickRole(null);
    if (role == null || !mounted) return;
    final pin = await confirmWithPin(context,
        title: 'Confirm', message: 'Give $ident the ${businessRoleLabels[role]} role on your business?');
    if (pin == null || !mounted) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.addMember(ident, role, pin);
      return true;
    }, success: 'Team member added');
    if (ok == true) _key.currentState?.reload();
  }

  Future<void> _manage(Map<String, dynamic> m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: const Text('Change role'), onTap: () => Navigator.pop(ctx, 'role')),
          ListTile(title: const Text('Remove from team'), onTap: () => Navigator.pop(ctx, 'remove')),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final id = '${m['id']}';
    final name = _name(m['user'] as Map?);
    if (action == 'role') {
      final role = await _pickRole('${m['role']}');
      if (role == null || role == m['role'] || !mounted) return;
      final pin = await confirmWithPin(context, title: 'Change role', message: 'Make $name ${businessRoleLabels[role]}?');
      if (pin == null || !mounted) return;
      final ok = await runBusy(context, () async {
        await BusinessOpsApi.updateMember(id, role, pin);
        return true;
      }, success: 'Role updated');
      if (ok == true) _key.currentState?.reload();
    } else {
      final pin = await confirmWithPin(context, title: 'Remove member', message: 'Remove $name from your business? They lose access immediately.');
      if (pin == null || !mounted) return;
      final ok = await runBusy(context, () async {
        await BusinessOpsApi.removeMember(id, pin);
        return true;
      }, success: 'Member removed');
      if (ok == true) _key.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Team',
        fab: _assignable.isEmpty ? null : BizFab(label: 'Add member', onPressed: _add),
        body: BizAsync<Map<String, dynamic>>(
          key: _key,
          load: () async {
            final r = await BusinessOpsApi.team();
            final meta = (r['meta'] as Map?) ?? {};
            final a = ((meta['assignable_roles'] as List?) ?? const []).map((e) => '$e').toList();
            if (mounted && a.join() != _assignable.join()) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _assignable = a);
              });
            }
            return r;
          },
          builder: (c, r, _) {
            final members = BusinessOpsApi.list(r);
            return ListView(padding: const EdgeInsets.all(16), children: [
              for (final m in members)
                BizTile(
                  leading: Icons.person_outline,
                  title: _name(m['user'] as Map?),
                  subtitle: '${(m['permissions'] as List?)?.length ?? 0} permissions',
                  trailing: StatusChip(businessRoleLabels['${m['role']}'] ?? '${m['role']}', filled: m['role'] == 'owner'),
                  onTap: m['id'] != null && _assignable.contains('${m['role']}') ? () => _manage(m) : null,
                ),
              if (members.length == 1)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Only you so far. Add teammates and give each the role they need.',
                      style: TextStyle(color: mutedColor(c))),
                ),
            ]);
          },
        ),
      );
}

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});
  @override
  State<BusinessProfilePage> createState() => _ProfileState();
}

class _ProfileState extends State<BusinessProfilePage> {
  final _key = GlobalKey<BizAsyncState<Map<String, dynamic>>>();
  static const _editable = {
    'trading_name': 'Trading name',
    'business_email': 'Business email',
    'business_phone': 'Business phone',
    'website': 'Website',
    'address': 'Address',
    'description': 'Description',
  };

  Future<void> _edit(Map<String, dynamic> b) async {
    final ctrls = {for (final k in _editable.keys) k: TextEditingController(text: '${b[k] ?? ''}')};
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
          for (final e in _editable.entries) ...[
            TextField(controller: ctrls[e.key], decoration: bizInput(ctx, e.value), maxLines: e.key == 'description' ? 3 : 1),
            const SizedBox(height: 10),
          ],
          Text('Legal details can only be changed through a new verification.', style: TextStyle(color: mutedColor(ctx), fontSize: 12)),
          const SizedBox(height: 12),
          ElevatedButton(style: primaryButtonStyle(ctx), onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ]),
      ),
    );
    if (save == true && mounted) {
      final ok = await runBusy(context, () async {
        await BusinessOpsApi.updateProfile({
          for (final e in ctrls.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        });
        return true;
      }, success: 'Profile updated');
      if (ok == true) _key.currentState?.reload();
    }
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Business profile',
        body: BizAsync<Map<String, dynamic>>(
          key: _key,
          load: BusinessOpsApi.profile,
          cacheKey: 'profile',
          builder: (c, r, _) {
            final b = BusinessOpsApi.data(r);
            final canEdit = (r['meta'] as Map?)?['can_edit'] == true;
            String v(String k) => '${b[k] ?? '—'}';
            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(v('trading_name') == '—' ? v('legal_name') : v('trading_name'),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c)))),
                    BusinessStatusBadge(status: b['status']?.toString()),
                  ]),
                  const SizedBox(height: 10),
                  KeyValue('Legal name', v('legal_name')),
                  KeyValue('Registration no.', v('registration_number')),
                  KeyValue('Country', v('registration_country')),
                  KeyValue('Sector', statusLabel(b['sector']?.toString())),
                  KeyValue('Email', v('business_email')),
                  KeyValue('Phone', v('business_phone')),
                  KeyValue('Website', v('website')),
                  KeyValue('Address', v('address')),
                  KeyValue('About', v('description')),
                  KeyValue('Verified on', shortDate(b['approved_at'])),
                ]),
              ),
              if (canEdit) ...[
                const SizedBox(height: 12),
                ElevatedButton(style: primaryButtonStyle(c), onPressed: () => _edit(b), child: const Text('Edit contact details')),
              ],
            ]);
          },
        ),
      );
}
