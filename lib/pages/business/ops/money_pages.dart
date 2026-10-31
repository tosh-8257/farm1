import '/components/farm_coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';
import '/backend/api_requests/chain_wallet_api.dart';
import '/pages/chain_wallet/wallet_address_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BusinessWalletPage extends StatefulWidget {
  const BusinessWalletPage({super.key});
  @override
  State<BusinessWalletPage> createState() => _BusinessWalletPageState();
}

class _BusinessWalletPageState extends State<BusinessWalletPage> {
  Key _key = UniqueKey();

  Future<void> _moveToPersonal(Map<String, dynamic> w) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Move to personal'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: bizInput(c, 'Amount (FARM)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, double.tryParse(ctrl.text)),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (amount == null || amount <= 0 || !mounted) return;
    final pin = await confirmWithPin(context,
        title: 'Move to personal',
        message: 'Move ${money(amount)} from your business wallet to your personal wallet? No fee.');
    if (pin == null || !mounted) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.moveToPersonal(amount, pin);
      return true;
    }, success: 'Moved to your personal wallet');
    if (ok == true && mounted) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Business wallet',
        body: BizAsync<Map<String, dynamic>>(
          key: _key,
          load: BusinessOpsApi.wallet,
          builder: (c, w, _) {
            final separate = w['separate_from_personal'] == true;
            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Business balance available', style: TextStyle(color: mutedColor(c))),
                  Row(children: [
                    if ('${w['currency'] ?? 'FARM'}' == 'FARM') ...[const FarmCoinIcon(size: 28), const SizedBox(width: 10)],
                    Flexible(child: Text(money(w['available_balance'], '${w['currency'] ?? 'FARM'}'),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: goldOn(c)))),
                  ]),
                  const SizedBox(height: 12),
                  KeyValue('Total balance', money(w['balance'])),
                  KeyValue('Locked in escrow', money(w['locked_balance'])),
                  if (w['is_frozen'] == true) const KeyValue('Status', 'Frozen — contact support'),
                  if (w['can_move_to_personal'] == true) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _moveToPersonal(w),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Move to personal'),
                      ),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              // The on-chain address belongs to the owner's personal wallet,
              // so it's only shown while the business still settles there.
              if (!separate) ...[
                const _AlgorandAddressCard(),
                const SizedBox(height: 12),
              ],
              Text(
                separate
                    ? 'This is your business (merchant) wallet, separate from your personal wallet. '
                        'QR payments, invoices, payment links and escrow releases land here. '
                        'Payouts are paid from it, and moving money to personal is free.'
                    : 'Your business wallet is the settlement wallet of the account owner. '
                        'Payments from links and invoices land here.',
                style: TextStyle(color: mutedColor(c), height: 1.5),
              ),
            ]);
          },
        ),
      );
}

/// The owner's on-chain receiving address (ALGO, USDC, FARM on Algorand).
class _AlgorandAddressCard extends StatelessWidget {
  const _AlgorandAddressCard();
  @override
  Widget build(BuildContext context) => BizCard(
        child: SizedBox(
          height: 330,
          child: BizAsync<Map<String, dynamic>>(
            load: ChainWalletApi.mine,
            isEmpty: (r) => r['data'] is! Map,
            emptyIcon: Icons.qr_code_2,
            emptyTitle: 'Algorand address not available yet',
            emptyMessage: 'It appears here once on-chain receiving is switched on.',
            builder: (c, r, reload) {
              final w = Map<String, dynamic>.from(r['data'] as Map);
              final ready = w['ready'] == true;
              final addr = '${w['address']}';
              return ListView(children: [
                Text('Receive on Algorand', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                const SizedBox(height: 4),
                Text('Receive ALGO, USDC and FARM to this address on the Algorand network.',
                    style: TextStyle(fontSize: 12, color: mutedColor(c))),
                const SizedBox(height: 8),
                if (ready)
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(6),
                      child: QrImageView(data: addr, size: 120, backgroundColor: Colors.white),
                    ),
                  ),
                const SizedBox(height: 6),
                SelectableText(addr, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: fgColor(c))),
                Text(
                  ready
                      ? 'Only send on Algorand; other networks or tokens may be lost. ALGO and USDC convert to FARM at the live rate; FARM is credited 1:1.'
                      : 'Setting up this address. Do not send funds yet.',
                  style: TextStyle(fontSize: 11, color: mutedColor(c)),
                ),
                Row(children: [
                  TextButton.icon(
                    onPressed: ready
                        ? () async {
                            await Clipboard.setData(ClipboardData(text: addr));
                            if (c.mounted) bizSnack(c, 'Address copied');
                          }
                        : null,
                    icon: Icon(Icons.copy, size: 16, color: fgColor(c)),
                    label: Text('Copy', style: TextStyle(color: fgColor(c))),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(c)
                        .push(MaterialPageRoute(builder: (_) => const WalletAddressPage())),
                    child: Text('Open', style: TextStyle(color: fgColor(c))),
                  ),
                ]),
              ]);
            },
          ),
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
          label: 'New payout',
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
                subtitle: '${p['payout_method'] ?? p['method'] ?? ''}${p['automatic'] == true ? ' · automatic' : ''} · ${p['account_name'] ?? ''} · ${shortDate(p['created_at'])}',
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
        message: 'Send ${money(amount)} to ${_name.text.trim()} (${_number.text.trim()})?');
    if (pin == null || !mounted) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.requestPayout({
        'amount': amount,
        'method': _method == 'mobile_money' ? 'MOBILE_MONEY' : 'BANK_TRANSFER',
        'account_name': _name.text.trim(),
        if (_method == 'mobile_money') 'phone_number': _number.text.trim().replaceAll(' ', ''),
        if (_method != 'mobile_money') 'account_number': _number.text.trim(),
        'pin': pin,
      });
      return true;
    }, success: 'Payout sent');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'New payout',
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
            const SizedBox(height: 12),
            Text('Payouts are processed automatically. Only the Owner and Finance roles can send them, and your PIN is required.',
                style: TextStyle(fontSize: 12, color: mutedColor(context))),
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
