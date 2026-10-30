import 'package:flutter/material.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';

/// Payer side: pay a business payment link or invoice, or fund an escrow a
/// business requested. Every payment goes through the server with your PIN.
class PayBusinessPage extends StatelessWidget {
  const PayBusinessPage({super.key, this.initialCode, this.initialInvoice});
  static String routeName = 'PayBusiness';
  static String routePath = '/pay-business';
  final String? initialCode;
  final String? initialInvoice;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        initialIndex: (initialInvoice ?? '').isNotEmpty ? 1 : 0,
        child: BizScaffold(
          title: 'Pay a business',
          body: Column(children: [
            TabBar(
              labelColor: fgColor(context),
              unselectedLabelColor: mutedColor(context),
              indicatorColor: fgColor(context),
              tabs: const [Tab(text: 'Link code'), Tab(text: 'Invoice'), Tab(text: 'Escrow')],
            ),
            Expanded(
              child: TabBarView(children: [
                _LookupPay(kind: 'link', initial: initialCode),
                _LookupPay(kind: 'invoice', initial: initialInvoice),
                const _IncomingEscrows(),
              ]),
            ),
          ]),
        ),
      );
}

class _LookupPay extends StatefulWidget {
  const _LookupPay({required this.kind, this.initial});
  final String kind;
  final String? initial;
  @override
  State<_LookupPay> createState() => _LookupPayState();
}

class _LookupPayState extends State<_LookupPay> {
  late final _ctrl = TextEditingController(text: widget.initial ?? '');
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _item;
  String? _paidRef;

  bool get _isLink => widget.kind == 'link';

  @override
  void initState() {
    super.initState();
    if ((widget.initial ?? '').isNotEmpty) _lookup();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _item = null;
      _paidRef = null;
    });
    try {
      final d = _isLink ? await BusinessOpsApi.publicLink(v) : await BusinessOpsApi.publicInvoice(v);
      if (mounted) setState(() => _item = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _payable {
    final i = _item;
    if (i == null) return false;
    return _isLink ? i['state'] == 'active' : ['sent', 'pending', 'overdue'].contains(i['status']);
  }

  Future<void> _pay() async {
    final i = _item!;
    final amount = _isLink ? i['amount'] : i['total'];
    final pin = await confirmWithPin(context,
        title: 'Confirm payment',
        message: 'Pay ${money(amount)} to ${i['business_name']}? A transfer fee may apply.');
    if (pin == null || !mounted) return;
    final res = await runBusy(context, () => _isLink
        ? BusinessOpsApi.payLink(_ctrl.text.trim(), pin)
        : BusinessOpsApi.payInvoice(_ctrl.text.trim(), pin));
    if (res != null && mounted) setState(() => _paidRef = '${res['transaction_reference']}');
  }

  @override
  Widget build(BuildContext context) {
    final i = _item;
    return ListView(padding: const EdgeInsets.all(20), children: [
      TextField(
        controller: _ctrl,
        decoration: bizInput(context, _isLink ? 'Payment link code' : 'Invoice number', hint: _isLink ? 'e.g. a1B2c3D4e5F6' : 'INV-2026-…'),
        onSubmitted: (_) => _lookup(),
      ),
      const SizedBox(height: 12),
      ElevatedButton(style: primaryButtonStyle(context), onPressed: _loading ? null : _lookup, child: const Text('Find')),
      const SizedBox(height: 20),
      if (_loading) const Center(child: CircularProgressIndicator()),
      if (_error != null) BizMessage(icon: Icons.error_outline, title: 'Not found', message: _error!, action: _lookup, actionLabel: 'Retry'),
      if (i != null && _paidRef != null)
        BizMessage(icon: Icons.check_circle_outline, title: 'Payment successful', message: 'Reference $_paidRef'),
      if (i != null && _paidRef == null)
        BizCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i['business_name']}', style: TextStyle(color: mutedColor(context))),
            const SizedBox(height: 4),
            Text(_isLink ? '${i['title']}' : '${i['invoice_number']}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(context))),
            const SizedBox(height: 8),
            Text(money(_isLink ? i['amount'] : i['total']),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fgColor(context))),
            const SizedBox(height: 8),
            if (!_isLink)
              for (final it in ((i['items'] as List?) ?? const []).whereType<Map>())
                KeyValue('${it['description']} ×${it['quantity']}', money(it['amount'])),
            if (_isLink && (i['description'] ?? '').toString().isNotEmpty)
              Text('${i['description']}', style: TextStyle(color: mutedColor(context))),
            const SizedBox(height: 8),
            StatusChip(statusLabel('${_isLink ? i['state'] : i['status']}')),
            const SizedBox(height: 16),
            if (_payable)
              ElevatedButton(style: primaryButtonStyle(context), onPressed: _pay, child: const Text('Pay now'))
            else
              Text('This ${_isLink ? 'link' : 'invoice'} cannot be paid.', style: TextStyle(color: mutedColor(context))),
          ]),
        ),
    ]);
  }
}

class _IncomingEscrows extends StatelessWidget {
  const _IncomingEscrows();
  @override
  Widget build(BuildContext context) => BizAsync<List<Map<String, dynamic>>>(
        load: BusinessOpsApi.incomingEscrows,
        isEmpty: (l) => l.isEmpty,
        emptyIcon: Icons.verified_user_outlined,
        emptyTitle: 'No escrow requests',
        emptyMessage: 'When a business asks you to fund an escrow, it appears here.',
        builder: (c, items, reload) => ListView(padding: const EdgeInsets.all(16), children: [
          for (final e in items)
            BizTile(
              title: '${e['title']}',
              subtitle: '${e['business_name']} · ${money(e['amount'])}',
              trailing: StatusChip(statusLabel('${e['status']}'), filled: e['status'] == 'awaiting_payment'),
              onTap: e['status'] != 'awaiting_payment'
                  ? (((e['milestones'] as List?) ?? const []).isNotEmpty &&
                          ['funded', 'in_progress', 'release_requested'].contains(e['status'])
                      ? () => Navigator.of(c)
                          .push(MaterialPageRoute(builder: (_) => _EscrowMilestonesPage(id: '${e['id']}')))
                          .then((_) => reload())
                      : null)
                  : () async {
                      final pin = await confirmWithPin(c,
                          title: 'Fund escrow',
                          message: '${money(e['amount'])} will be held in escrow for ${e['business_name']} until you release it. An escrow fee may apply.');
                      if (pin == null || !c.mounted) return;
                      final ok = await runBusy(c, () => BusinessOpsApi.fundEscrow('${e['id']}', pin),
                          success: 'Escrow funded. Release or dispute it from Escrow.');
                      if (ok != null) reload();
                    },
            ),
        ]),
      );
}

/** Buyer view: release escrow funds milestone by milestone. Money moves on the server. */
class _EscrowMilestonesPage extends StatelessWidget {
  const _EscrowMilestonesPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Milestones',
        body: BizAsync<Map<String, dynamic>>(
          load: () async {
            final all = await BusinessOpsApi.incomingEscrows();
            return all.firstWhere((e) => '${e['id']}' == id, orElse: () => throw 'This escrow is no longer available');
          },
          isEmpty: (e) => ((e['milestones'] as List?) ?? const []).isEmpty,
          emptyIcon: Icons.flag_outlined,
          emptyTitle: 'No milestones',
          emptyMessage: 'This escrow is released in one payment.',
          builder: (c, e, reload) {
            final ms = ((e['milestones'] as List?) ?? const []).whereType<Map>().toList();
            final open = ['funded', 'in_progress', 'release_requested'].contains(e['status']);
            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e['title']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c))),
                  const SizedBox(height: 8),
                  KeyValue('Business', '${e['business_name']}'),
                  KeyValue('Total', money(e['amount'])),
                  KeyValue('Released', money(e['released_amount'] ?? 0)),
                ]),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < ms.length; i++)
                BizTile(
                  title: '${ms[i]['title']}',
                  subtitle: money(ms[i]['amount']) +
                      (ms[i]['status'] == 'release_requested' ? ' · release requested' : ''),
                  trailing: StatusChip(statusLabel('${ms[i]['status'] ?? 'pending'}'),
                      filled: ms[i]['status'] == 'released'),
                  onTap: !open || !['pending', 'release_requested'].contains(ms[i]['status'] ?? 'pending')
                      ? null
                      : () async {
                          final pin = await confirmWithPin(c,
                              title: 'Release milestone',
                              message:
                                  '${money(ms[i]['amount'])} for "${ms[i]['title']}" will be paid to ${e['business_name']}. This cannot be undone.');
                          if (pin == null || !c.mounted) return;
                          final ok = await runBusy(c, () => BusinessOpsApi.releaseMilestone(id, i, pin),
                              success: 'Milestone released');
                          if (ok != null) reload();
                        },
                ),
            ]);
          },
        ),
      );
}
