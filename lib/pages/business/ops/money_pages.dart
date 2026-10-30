import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';

class BusinessWalletPage extends StatelessWidget {
  const BusinessWalletPage({super.key});
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Business wallet',
        body: BizAsync<Map<String, dynamic>>(
          load: BusinessOpsApi.wallet,
          builder: (c, w, _) => ListView(padding: const EdgeInsets.all(20), children: [
            BizCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Available', style: TextStyle(color: mutedColor(c))),
                Text(money(w['available_balance'], '${w['currency'] ?? 'FARM'}'),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: fgColor(c))),
                const SizedBox(height: 12),
                KeyValue('Total balance', money(w['balance'])),
                KeyValue('Locked in escrow', money(w['locked_balance'])),
                KeyValue('Wallet address', '${w['wallet_address'] ?? '—'}'),
                if (w['is_frozen'] == true) const KeyValue('Status', 'Frozen — contact support'),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              'Your business wallet is the settlement wallet of the account owner. '
              'Payments from links and invoices land here.',
              style: TextStyle(color: mutedColor(c), height: 1.5),
            ),
          ]),
        ),
      );
}

const txFilters = ['all', 'pending', 'processing', 'successful', 'failed', 'cancelled', 'refunded'];

class BusinessTransactionsPage extends StatefulWidget {
  const BusinessTransactionsPage({super.key});
  @override
  State<BusinessTransactionsPage> createState() => _TxState();
}

class _TxState extends State<BusinessTransactionsPage> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Transactions',
        body: Column(children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in txFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: StatusChip(statusLabel(f), filled: _filter == f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BizAsync<List<Map<String, dynamic>>>(
              key: ValueKey(_filter),
              load: () => BusinessOpsApi.transactions(status: _filter == 'all' ? null : _filter),
              isEmpty: (l) => l.isEmpty,
              emptyTitle: 'No transactions',
              emptyMessage: 'Business payments and transfers will appear here.',
              builder: (c, items, _) => ListView(padding: const EdgeInsets.all(16), children: [
                for (final t in items)
                  BizTile(
                    leading: t['direction'] == 'in' ? Icons.south_west_rounded : Icons.north_east_rounded,
                    title: '${t['direction'] == 'in' ? '+' : '−'}${money(t['amount'], '${t['currency'] ?? 'FARM'}')}',
                    subtitle: '${t['description'] ?? statusLabel('${t['type']}')} · ${shortDate(t['created_at'])}',
                    trailing: StatusChip(statusLabel('${t['status']}'), filled: t['status'] == 'successful'),
                    onTap: () => pushPage(c, TransactionDetailPage(id: '${t['id']}')),
                  ),
              ]),
            ),
          ),
        ]),
      );
}

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Transaction',
        body: BizAsync<Map<String, dynamic>>(
          load: () => BusinessOpsApi.transaction(id),
          builder: (c, t, _) => ListView(padding: const EdgeInsets.all(20), children: [
            BizCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(money(t['amount'], '${t['currency'] ?? 'FARM'}'),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fgColor(c))),
                  ),
                  StatusChip(statusLabel('${t['status']}'), filled: t['status'] == 'successful'),
                ]),
                const SizedBox(height: 12),
                KeyValue('Reference', '${t['reference']}'),
                KeyValue('Direction', t['direction'] == 'in' ? 'Received' : 'Sent'),
                KeyValue('Type', statusLabel('${t['type']}')),
                KeyValue('Fee', money(t['fee'])),
                KeyValue('Description', '${t['description'] ?? '—'}'),
                KeyValue('Created', shortDate(t['created_at'])),
                KeyValue('Processed', shortDate(t['processed_at'])),
                if (t['business_payment'] is Map)
                  KeyValue('Source', statusLabel('${t['business_payment']['source']}')),
              ]),
            ),
          ]),
        ),
      );
}

class PayoutsPage extends StatefulWidget {
  const PayoutsPage({super.key});
  @override
  State<PayoutsPage> createState() => _PayoutsState();
}

class _PayoutsState extends State<PayoutsPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Payouts',
        fab: BizFab(
          label: 'Request payout',
          onPressed: () async {
            final ok = await pushPage<bool>(context, const RequestPayoutPage());
            if (ok == true) _key.currentState?.reload();
          },
        ),
        body: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: BusinessOpsApi.payouts,
          isEmpty: (l) => l.isEmpty,
          emptyTitle: 'No payouts yet',
          emptyMessage: 'Withdraw your business balance to a bank or mobile money account.',
          builder: (c, items, _) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final p in items)
              BizTile(
                title: money(p['amount']),
                subtitle: '${p['payout_method']} · ${p['account_name']} · ${shortDate(p['created_at'])}',
                trailing: StatusChip(statusLabel('${p['status']}'), filled: p['status'] == 'successful'),
              ),
          ]),
        ),
      );
}

class RequestPayoutPage extends StatefulWidget {
  const RequestPayoutPage({super.key});
  @override
  State<RequestPayoutPage> createState() => _RequestPayoutState();
}

class _RequestPayoutState extends State<RequestPayoutPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _name = TextEditingController();
  final _number = TextEditingController();
  String _method = 'bank_transfer';

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.parse(_amount.text);
    final pin = await confirmWithPin(context,
        title: 'Confirm payout',
        message: 'Request a payout of ${money(amount)} to ${_name.text.trim()} (${_number.text.trim()})?');
    if (pin == null || !mounted) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.requestPayout({
        'amount': amount,
        'payout_method': _method,
        'account_name': _name.text.trim(),
        'account_number': _number.text.trim(),
        'pin': pin,
      });
      return true;
    }, success: 'Payout requested');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Request payout',
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: bizInput(context, 'Amount (FARM)'),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) >= 1 ? null : 'Enter at least 1',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: bizInput(context, 'Method'),
              items: const [
                DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'mobile_money', child: Text('Mobile money')),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: bizInput(context, 'Account name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              decoration: bizInput(context, _method == 'mobile_money' ? 'Phone number' : 'Account number'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(style: primaryButtonStyle(context), onPressed: _submit, child: const Text('Continue')),
          ]),
        ),
      );
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<AnalyticsPage> {
  String _range = '30d';
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Analytics',
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              for (final r in const ['7d', '30d', '90d', '1y'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _range = r),
                    child: StatusChip(r.toUpperCase(), filled: _range == r),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: BizAsync<Map<String, dynamic>>(
              key: ValueKey(_range),
              load: () => BusinessOpsApi.analytics(_range),
              isEmpty: (d) => d['empty'] == true,
              emptyIcon: Icons.insights_outlined,
              emptyTitle: 'No activity in this period',
              emptyMessage: 'Charts appear once your business receives or sends payments.',
              builder: (c, d, _) {
                final totals = (d['totals'] as Map?) ?? {};
                final series = ((d['series'] as List?) ?? const []).whereType<Map>().toList();
                final maxV = series.fold<double>(1, (m, s) {
                  final r = (s['received'] as num?)?.toDouble() ?? 0;
                  return r > m ? r : m;
                });
                return ListView(padding: const EdgeInsets.all(16), children: [
                  BizCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      KeyValue('Received', money(totals['received'])),
                      KeyValue('Sent', money(totals['sent'])),
                      KeyValue('Payments in', '${totals['payments'] ?? 0}'),
                      KeyValue('Invoices paid', '${totals['invoices_paid'] ?? 0}'),
                      KeyValue('Link payments', '${totals['payment_link_payments'] ?? 0}'),
                      KeyValue('New customers', '${totals['new_customers'] ?? 0}'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text('Received per ${d['bucket']}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                  const SizedBox(height: 10),
                  for (final s in series)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        SizedBox(
                            width: 84,
                            child: Text(shortDate(s['period']),
                                style: TextStyle(fontSize: 12, color: mutedColor(c)))),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (_, box) => Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                height: 14,
                                width: box.maxWidth * (((s['received'] as num?)?.toDouble() ?? 0) / maxV),
                                decoration: BoxDecoration(
                                    color: fgColor(c), borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                            width: 90,
                            child: Text(money(s['received'], ''),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, color: fgColor(c)))),
                      ]),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}
