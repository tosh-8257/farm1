import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/agent_payments_api.dart';
import '/pages/business/ops/ops_ui.dart';

const _labels = {
  'requires_payment': 'Awaiting payment',
  'processing': 'Processing',
  'succeeded': 'Paid',
  'partially_refunded': 'Partly refunded',
  'refunded': 'Refunded',
  'canceled': 'Canceled',
  'expired': 'Expired',
  'pending': 'Needs approval',
  'confirmed': 'Paid',
  'rejected': 'Rejected',
  'failed': 'Failed',
  'active': 'Active',
  'revoked': 'Revoked',
};
String _l(dynamic s) => _labels['$s'] ?? '$s';
final _uuid = RegExp(r'^[0-9a-fA-F-]{36}$');

/// Hub: pay a request, agent permissions, pending agent requests. Disabled state when the server flag is off.
class AgentPaymentsHomePage extends StatelessWidget {
  const AgentPaymentsHomePage({super.key});
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Agent payments',
        body: BizAsync<Map<String, dynamic>>(
          load: AgentPaymentsApi.status,
          builder: (c, s, _) {
            if (s['enabled'] != true) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Agent payments are not available yet.',
                      textAlign: TextAlign.center, style: TextStyle(color: mutedColor(c))),
                ),
              );
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              Text('Businesses and their AI agents can ask you to pay. Nothing is paid until you confirm with your PIN.',
                  style: TextStyle(color: mutedColor(c))),
              const SizedBox(height: 12),
              BizTile(
                  leading: Icons.qr_code_2,
                  title: 'Pay a payment request',
                  subtitle: 'Enter the payment ID a business gave you',
                  onTap: () => pushPage(c, const _EnterIntentPage())),
              BizTile(
                  leading: Icons.pending_actions_outlined,
                  title: 'Agent requests',
                  subtitle: 'Approve or reject payments agents asked for',
                  onTap: () => pushPage(c, const AgentRequestsPage())),
              BizTile(
                  leading: Icons.verified_user_outlined,
                  title: 'Agent permissions',
                  subtitle: 'Which businesses may ask, and your limits',
                  onTap: () => pushPage(c, const AgentMandatesPage())),
            ]);
          },
        ),
      );
}

class _EnterIntentPage extends StatefulWidget {
  const _EnterIntentPage();
  @override
  State<_EnterIntentPage> createState() => _EnterIntentPageState();
}

class _EnterIntentPageState extends State<_EnterIntentPage> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Pay a request',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _ctrl, decoration: bizInput(c, 'Payment ID', hint: 'xxxxxxxx-xxxx-…')),
          const SizedBox(height: 12),
          ElevatedButton(
            style: primaryButtonStyle(c),
            onPressed: () {
              final id = _ctrl.text.trim();
              if (!_uuid.hasMatch(id)) return bizSnack(c, 'Enter a valid payment ID');
              pushPage(c, PayIntentPage(id: id));
            },
            child: const Text('Continue'),
          ),
        ]),
      );
}

/// Review a business payment request and pay it with the PIN.
class PayIntentPage extends StatelessWidget {
  const PayIntentPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Payment request',
        body: BizAsync<Map<String, dynamic>>(
          load: () => AgentPaymentsApi.intent(id),
          builder: (c, i, reload) {
            final payable = i['status'] == 'requires_payment';
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${i['business_name'] ?? 'Business'}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(_l(i['status']), filled: i['status'] == 'succeeded'),
                  ]),
                  const Divider(),
                  KeyValue('Amount', '${money(i['amount'])}'),
                  if (i['description'] != null) KeyValue('For', '${i['description']}'),
                  if (i['reference'] != null) KeyValue('Reference', '${i['reference']}'),
                  KeyValue('Expires', shortDate(i['expires_at'])),
                ]),
              ),
              const SizedBox(height: 16),
              if (payable)
                ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () async {
                    final pin = await confirmWithPin(c,
                        title: 'Confirm payment',
                        message: 'Pay ${money(i['amount'])} to ${i['business_name']}?');
                    if (pin == null || !c.mounted) return;
                    final r = await runBusy(c, () => AgentPaymentsApi.pay(id, pin), success: 'Payment sent');
                    if (r != null) reload();
                  },
                  child: const Text('Pay with PIN'),
                ),
            ]);
          },
        ),
      );
}

class AgentRequestsPage extends StatelessWidget {
  const AgentRequestsPage({super.key});
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Agent requests',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: AgentPaymentsApi.requests,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.pending_actions_outlined,
          emptyTitle: 'No requests',
          emptyMessage: 'When an agent you allowed asks you to pay, it appears here.',
          builder: (c, list, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final r in list) _RequestCard(r, reload),
            ]),
          ),
        ),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.r, this.reload);
  final Map<String, dynamic> r;
  final Future<void> Function() reload;
  @override
  Widget build(BuildContext c) {
    final pending = r['status'] == 'pending';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${r['business_name'] ?? 'Business'}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
            StatusChip(_l(r['status']), filled: r['status'] == 'confirmed'),
          ]),
          const SizedBox(height: 6),
          KeyValue('Amount', '${money(r['amount'])}'),
          if (r['description'] != null) KeyValue('For', '${r['description']}'),
          KeyValue('Asked', shortDate(r['created_at'])),
          if (r['transaction_reference'] != null) KeyValue('Reference', '${r['transaction_reference']}'),
          if (r['failure_reason'] != null)
            Text('${r['failure_reason']}', style: TextStyle(color: mutedColor(c), fontSize: 12)),
          if (pending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: secondaryButtonStyle(c),
                  onPressed: () async {
                    final ok = await runBusy(c, () => AgentPaymentsApi.rejectRequest('${r['id']}'), success: 'Rejected');
                    if (ok != null) reload();
                  },
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () async {
                    final pin = await confirmWithPin(c,
                        title: 'Approve payment',
                        message: 'Pay ${money(r['amount'])} to ${r['business_name']}?\n\nAn agent asked for this. Only your PIN sends it.');
                    if (pin == null || !c.mounted) return;
                    final ok = await runBusy(c, () => AgentPaymentsApi.confirmRequest('${r['id']}', pin), success: 'Payment sent');
                    if (ok != null) reload();
                  },
                  child: const Text('Approve with PIN'),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class AgentMandatesPage extends StatelessWidget {
  const AgentMandatesPage({super.key});
  @override
  Widget build(BuildContext c) {
    final key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
    return BizScaffold(
      title: 'Agent permissions',
      fab: BizFab(
          label: 'Allow a business',
          onPressed: () async {
            await pushPage(c, const _NewMandatePage());
            key.currentState?.reload();
          }),
      body: BizAsync<List<Map<String, dynamic>>>(
        key: key,
        load: AgentPaymentsApi.mandates,
        isEmpty: (l) => l.isEmpty,
        emptyIcon: Icons.verified_user_outlined,
        emptyTitle: 'No agents allowed',
        emptyMessage: 'Allow a business’s agent to ask you for payments, within limits you set.',
        builder: (c, list, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
            for (final m in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BizCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                          child: Text('${m['business_name'] ?? m['label'] ?? 'Business'}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                      StatusChip(_l(m['status']), filled: m['status'] == 'active'),
                    ]),
                    const SizedBox(height: 6),
                    if (m['label'] != null) KeyValue('Label', '${m['label']}'),
                    KeyValue('Per payment', money(m['per_tx_cap'])),
                    KeyValue('Today', '${money(m['used_today'] ?? 0)} / ${money(m['daily_cap'])}'),
                    KeyValue('This month', '${money(m['used_this_month'] ?? 0)} / ${money(m['monthly_cap'])}'),
                    KeyValue('Expires', shortDate(m['expires_at'])),
                    if (m['status'] == 'active')
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            if (!await confirmAction(c,
                                title: 'Revoke permission?',
                                message: 'The agent can no longer ask you to pay. Pending requests are canceled.',
                                confirm: 'Revoke')) {
                              return;
                            }
                            if (!c.mounted) return;
                            final ok = await runBusy(c, () => AgentPaymentsApi.revokeMandate('${m['id']}'), success: 'Revoked');
                            if (ok != null) reload();
                          },
                          child: Text('Revoke', style: TextStyle(color: fgColor(c))),
                        ),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NewMandatePage extends StatefulWidget {
  const _NewMandatePage();
  @override
  State<_NewMandatePage> createState() => _NewMandatePageState();
}

class _NewMandatePageState extends State<_NewMandatePage> {
  final _biz = TextEditingController();
  final _label = TextEditingController();
  final _tx = TextEditingController();
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _days = TextEditingController(text: '30');
  @override
  void dispose() {
    for (final x in [_biz, _label, _tx, _day, _month, _days]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final id = _biz.text.trim();
    final tx = num.tryParse(_tx.text), day = num.tryParse(_day.text), month = num.tryParse(_month.text);
    final days = int.tryParse(_days.text);
    if (!_uuid.hasMatch(id)) return bizSnack(context, 'Enter the business ID');
    if (tx == null || day == null || month == null || tx <= 0) return bizSnack(context, 'Enter all three limits');
    if (tx > day || day > month) return bizSnack(context, 'Limits must go per payment ≤ daily ≤ monthly');
    if (days == null || days < 1 || days > 365) return bizSnack(context, 'Duration must be 1–365 days');
    final pin = await confirmWithPin(context,
        title: 'Allow agent payments',
        message: 'Let this business’s agent ask you for up to ${money(tx)} per payment. You still approve each one with your PIN.');
    if (pin == null || !mounted) return;
    final r = await runBusy(
        context,
        () => AgentPaymentsApi.createMandate({
              'business_id': id,
              if (_label.text.trim().isNotEmpty) 'label': _label.text.trim(),
              'per_tx_cap': tx,
              'daily_cap': day,
              'monthly_cap': month,
              'expires_in_days': days,
              'pin': pin,
            }),
        success: 'Permission added');
    if (r != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) {
    final numFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return BizScaffold(
      title: 'Allow a business',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _biz, decoration: bizInput(c, 'Business ID', hint: 'Given by the business')),
        const SizedBox(height: 8),
        TextField(controller: _label, decoration: bizInput(c, 'Label (optional)')),
        const SizedBox(height: 8),
        TextField(controller: _tx, keyboardType: TextInputType.number, inputFormatters: numFmt, decoration: bizInput(c, 'Max per payment (FARM)')),
        const SizedBox(height: 8),
        TextField(controller: _day, keyboardType: TextInputType.number, inputFormatters: numFmt, decoration: bizInput(c, 'Max per day (FARM)')),
        const SizedBox(height: 8),
        TextField(controller: _month, keyboardType: TextInputType.number, inputFormatters: numFmt, decoration: bizInput(c, 'Max per month (FARM)')),
        const SizedBox(height: 8),
        TextField(controller: _days, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: bizInput(c, 'Valid for (days)')),
        const SizedBox(height: 16),
        ElevatedButton(style: primaryButtonStyle(c), onPressed: _save, child: const Text('Confirm with PIN')),
      ]),
    );
  }
}

/// Business dashboard: payment intents (create, cancel, refund with PIN).
class BusinessIntentsPage extends StatelessWidget {
  const BusinessIntentsPage({super.key});
  @override
  Widget build(BuildContext c) {
    final key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
    return BizScaffold(
      title: 'Payment requests',
      fab: BizFab(
          label: 'New request',
          onPressed: () async {
            await pushPage(c, const _NewIntentPage());
            key.currentState?.reload();
          }),
      body: BizAsync<List<Map<String, dynamic>>>(
        key: key,
        load: AgentPaymentsApi.businessIntents,
        isEmpty: (l) => l.isEmpty,
        emptyIcon: Icons.request_page_outlined,
        emptyTitle: 'No payment requests',
        emptyMessage: 'Create one and share its ID with a customer or their agent.',
        builder: (c, list, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
            for (final i in list)
              BizTile(
                leading: Icons.request_page_outlined,
                title: '${money(i['amount'])}${i['description'] != null ? ' · ${i['description']}' : ''}',
                subtitle: '${shortDate(i['created_at'])}${i['live_mode'] == false ? ' · Test' : ''}',
                trailing: StatusChip(_l(i['status']), filled: i['status'] == 'succeeded'),
                onTap: () async {
                  await pushPage(c, BusinessIntentPage(id: '${i['id']}'));
                  reload();
                },
              ),
          ]),
        ),
      ),
    );
  }
}

class _NewIntentPage extends StatefulWidget {
  const _NewIntentPage();
  @override
  State<_NewIntentPage> createState() => _NewIntentPageState();
}

class _NewIntentPageState extends State<_NewIntentPage> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _ref = TextEditingController();
  final _key = AgentPaymentsApi.newKey();
  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _ref.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = num.tryParse(_amount.text);
    if (a == null || a < 1) return bizSnack(context, 'Enter an amount of at least 1 FARM');
    final r = await runBusy(
        context,
        () => AgentPaymentsApi.createIntent({
              'amount': a,
              if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
              if (_ref.text.trim().isNotEmpty) 'reference': _ref.text.trim(),
            }, _key),
        success: 'Request created');
    if (r != null && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'New payment request',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: bizInput(c, 'Amount (FARM)')),
          const SizedBox(height: 8),
          TextField(controller: _desc, decoration: bizInput(c, 'Description (optional)')),
          const SizedBox(height: 8),
          TextField(controller: _ref, decoration: bizInput(c, 'Your reference (optional)')),
          const SizedBox(height: 16),
          ElevatedButton(style: primaryButtonStyle(c), onPressed: _save, child: const Text('Create')),
        ]),
      );
}

class BusinessIntentPage extends StatelessWidget {
  const BusinessIntentPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Payment request',
        body: BizAsync<Map<String, dynamic>>(
          load: () => AgentPaymentsApi.businessIntent(id),
          builder: (c, i, reload) {
            final status = '${i['status']}';
            final paid = num.tryParse('${i['amount']}') ?? 0;
            final refunded = num.tryParse('${i['amount_refunded'] ?? 0}') ?? 0;
            final refundable = (status == 'succeeded' || status == 'partially_refunded') && refunded < paid;
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${money(i['amount'])}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(_l(status), filled: status == 'succeeded'),
                  ]),
                  const Divider(),
                  Row(children: [
                    Expanded(child: KeyValue('Payment ID', id)),
                    IconButton(
                        icon: Icon(Icons.copy, size: 18, color: mutedColor(c)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: id));
                          bizSnack(c, 'Copied');
                        }),
                  ]),
                  if (i['description'] != null) KeyValue('Description', '${i['description']}'),
                  if (i['reference'] != null) KeyValue('Reference', '${i['reference']}'),
                  if (refunded > 0) KeyValue('Refunded', money(refunded)),
                  if (i['transaction_reference'] != null) KeyValue('Transaction', '${i['transaction_reference']}'),
                  KeyValue('Mode', i['live_mode'] == false ? 'Test' : 'Live'),
                  KeyValue('Created', shortDate(i['created_at'])),
                  KeyValue('Expires', shortDate(i['expires_at'])),
                ]),
              ),
              const SizedBox(height: 16),
              if (status == 'requires_payment')
                OutlinedButton(
                  style: secondaryButtonStyle(c),
                  onPressed: () async {
                    if (!await confirmAction(c, title: 'Cancel request?', message: 'The customer will no longer be able to pay it.')) return;
                    if (!c.mounted) return;
                    final r = await runBusy(c, () => AgentPaymentsApi.cancelIntent(id), success: 'Canceled');
                    if (r != null) reload();
                  },
                  child: const Text('Cancel request'),
                ),
              if (refundable)
                ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () async {
                    final ok = await _refund(c, paid - refunded);
                    if (ok) reload();
                  },
                  child: const Text('Refund'),
                ),
            ]);
          },
        ),
      );

  Future<bool> _refund(BuildContext c, num max) async {
    final amt = TextEditingController(text: '$max');
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: const Text('Refund'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amt, keyboardType: TextInputType.number, decoration: bizInput(ctx, 'Amount (max ${money(max)})')),
          const SizedBox(height: 8),
          TextField(controller: reason, decoration: bizInput(ctx, 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Next', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    final a = num.tryParse(amt.text);
    final why = reason.text.trim();
    amt.dispose();
    reason.dispose();
    if (go != true || !c.mounted) return false;
    if (a == null || a <= 0 || a > max) {
      bizSnack(c, 'Enter an amount up to ${money(max)}');
      return false;
    }
    final key = AgentPaymentsApi.newKey();
    final pin = await confirmWithPin(c, title: 'Confirm refund', message: 'Refund ${money(a)} from the business wallet?');
    if (pin == null || !c.mounted) return false;
    final r = await runBusy(c, () => AgentPaymentsApi.refund(id, {'amount': a, if (why.isNotEmpty) 'reason': why, 'pin': pin}, key),
        success: 'Refunded');
    return r != null;
  }
}
