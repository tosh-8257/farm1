import 'dart:math';
import 'package:flutter/material.dart';
import '/backend/api_requests/investments_api.dart';
import '/pages/business/ops/ops_ui.dart';

const _modeLabels = {
  'off': 'Off',
  'monthly': 'Every month',
  'on_deposit': 'On each deposit',
  'period_end': 'At period end',
};

String _key() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 30)}';

/// Project funds timeline: raised, locked, every spend, returns and payouts.
/// The owner also pays invoices / payment links from project funds,
/// deposits returns and sets the payout schedule. All rules run on the server.
class ProjectFundsPage extends StatefulWidget {
  const ProjectFundsPage({super.key, required this.projectId, this.owner = false});
  final String projectId;
  final bool owner;
  @override
  State<ProjectFundsPage> createState() => _ProjectFundsPageState();
}

class _ProjectFundsPageState extends State<ProjectFundsPage> {
  final _key0 = GlobalKey<BizAsyncState<Map<String, dynamic>>>();
  void _reload() => _key0.currentState?.reload();

  Future<void> _pay() async {
    var kind = 'invoice';
    final ref = TextEditingController();
    final tag = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Pay from project funds'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'invoice', label: Text('Invoice')),
                  ButtonSegment(value: 'payment_link', label: Text('Payment link')),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setD(() => kind = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: ref,
                  decoration: bizInput(ctx, kind == 'invoice' ? 'Invoice number' : 'Payment link code')),
              TextField(controller: tag, maxLength: 120, decoration: bizInput(ctx, 'Deliverable (optional)', hint: 'e.g. Greenhouse kit')),
              TextField(controller: note, maxLength: 500, decoration: bizInput(ctx, 'Note (optional)')),
              Text('Only invoices and payment links of other approved FARM businesses. Investors see every payment.',
                  style: TextStyle(fontSize: 12, color: mutedColor(ctx))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      ),
    );
    final r = ref.text.trim(), t = tag.text.trim(), n = note.text.trim();
    ref.dispose();
    tag.dispose();
    note.dispose();
    if (ok != true || r.isEmpty || !mounted) return;
    final pin = await confirmWithPin(context,
        title: 'Confirm payment', message: 'Pay ${kind == 'invoice' ? 'invoice' : 'link'} $r from project funds.');
    if (pin == null || !mounted) return;
    final k = _key();
    final res = await runBusy(context,
        () => InvestmentsApi.spendProjectFunds(widget.projectId, kind: kind, ref: r, pin: pin, tag: t, note: n, key: k),
        success: 'Paid from project funds.');
    if (res != null) _reload();
  }

  Future<void> _deposit() async {
    final amt = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deposit returns'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amt,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: bizInput(ctx, 'Amount in FARM')),
          TextField(controller: note, maxLength: 500, decoration: bizInput(ctx, 'Note (optional)', hint: 'e.g. October rent')),
          Text('Moves FARM from your wallet into the project. Holders are paid on the project schedule, minus a 2% FARM fee.',
              style: TextStyle(fontSize: 12, color: mutedColor(ctx))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    final a = num.tryParse(amt.text.trim());
    final n = note.text.trim();
    amt.dispose();
    note.dispose();
    if (ok != true || !mounted) return;
    if (a == null || a < 1) return bizSnack(context, 'Enter at least 1 FARM');
    final pin = await confirmWithPin(context, title: 'Confirm deposit', message: 'Deposit ${money(a)} into the project.');
    if (pin == null || !mounted) return;
    final res = await runBusy(context, () => InvestmentsApi.depositReturns(widget.projectId, a, pin, note: n),
        success: 'Returns deposited.');
    if (res != null) _reload();
  }

  Future<void> _settings(Map<String, dynamic> s) async {
    var mode = '${s['distribution_mode'] ?? 'off'}';
    var kind = '${s['income_kind'] ?? 'profit'}';
    final pct = TextEditingController(text: '${s['distribution_percent'] ?? 0}');
    DateTime? end = s['distribution_period_end'] != null ? DateTime.tryParse('${s['distribution_period_end']}') : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Holder payout schedule'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButtonFormField<String>(
                value: mode,
                decoration: bizInput(ctx, 'When'),
                items: [for (final e in _modeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setD(() => mode = v ?? 'off'),
              ),
              TextField(
                  controller: pct,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: bizInput(ctx, 'Share of returns to pay out (%)')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'profit', label: Text('Profit')),
                  ButtonSegment(value: 'rental', label: Text('Rental')),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setD(() => kind = v.first),
              ),
              if (mode == 'period_end')
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: end ?? DateTime.now().add(const Duration(days: 30)));
                    if (d != null) setD(() => end = d);
                  },
                  child: Text(end == null ? 'Pick period end' : 'Period ends ${shortDate(end!.toIso8601String())}'),
                ),
              Text('Can be changed until the project is submitted.', style: TextStyle(fontSize: 12, color: mutedColor(ctx))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final p = num.tryParse(pct.text.trim()) ?? 0;
    pct.dispose();
    if (ok != true || !mounted) return;
    final res = await runBusy(
        context,
        () => InvestmentsApi.setFundsSettings(widget.projectId, {
              'distribution_mode': mode,
              'distribution_percent': p,
              'income_kind': kind,
              if (mode == 'period_end' && end != null) 'distribution_period_end': end!.toIso8601String(),
            }),
        success: 'Saved.');
    if (res != null) _reload();
  }

  IconData _icon(String t) => switch (t) {
        'funded' => Icons.savings_outlined,
        'spent' => Icons.shopping_cart_outlined,
        'return' => Icons.trending_up_rounded,
        'distributed' => Icons.payments_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Project funds',
        fab: widget.owner ? BizFab(label: 'Pay from funds', onPressed: _pay) : null,
        body: BizAsync<Map<String, dynamic>>(
          key: _key0,
          load: () => InvestmentsApi.fundsTimeline(widget.projectId, owner: widget.owner),
          builder: (c, d, _) {
            final s = (d['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
            final st = (d['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
            final ev = ((d['events'] as List?) ?? const []).whereType<Map>().toList().reversed.toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              if (d['paused'] == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Payments from this project are paused by FARM.', style: TextStyle(color: mutedColor(c))),
                ),
              BizCard(
                child: Column(children: [
                  KeyValue('Raised', money(s['raised'])),
                  KeyValue('Buyback hold (15%)', money(s['buyback_hold'])),
                  KeyValue('Locked', money(s['locked'])),
                  KeyValue('Spent', money(s['spent'])),
                  KeyValue('Returns', money(s['returns'])),
                  KeyValue('Paid to holders', money(s['distributed'])),
                  KeyValue('Payout schedule',
                      st['distribution_mode'] == 'off' || st['distribution_mode'] == null
                          ? 'Off'
                          : '${_modeLabels[st['distribution_mode']] ?? st['distribution_mode']} · ${st['distribution_percent']}%'),
                ]),
              ),
              if (widget.owner)
                Wrap(spacing: 4, children: [
                  TextButton.icon(
                      onPressed: _deposit,
                      icon: const Icon(Icons.add_card_rounded, size: 18),
                      label: Text('Deposit returns', style: TextStyle(color: fgColor(c)))),
                  TextButton.icon(
                      onPressed: () => _settings(st),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text('Payout schedule', style: TextStyle(color: fgColor(c)))),
                ]),
              const SizedBox(height: 12),
              Text('Timeline', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              if (ev.isEmpty) Text('Nothing yet.', style: TextStyle(color: mutedColor(c))),
              for (final e in ev)
                BizTile(
                  leading: _icon('${e['type']}'),
                  title: '${e['label']}',
                  subtitle: [
                    shortDate(e['at']),
                    if (e['tag'] != null) 'Deliverable: ${e['tag']}',
                    if (e['note'] != null) '${e['note']}',
                    if ((e['fee'] ?? 0) != 0) 'FARM fee ${money(e['fee'])}',
                  ].join('\n'),
                  trailing: Text(money(e['amount']), style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w600)),
                ),
            ]);
          },
        ),
      );
}
