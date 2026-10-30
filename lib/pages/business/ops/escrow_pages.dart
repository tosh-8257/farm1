import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';

class BusinessEscrowsPage extends StatefulWidget {
  const BusinessEscrowsPage({super.key});
  @override
  State<BusinessEscrowsPage> createState() => _EscrowsState();
}

class _EscrowsState extends State<BusinessEscrowsPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Business escrow',
        fab: BizFab(
          label: 'New escrow',
          onPressed: () async {
            final ok = await pushPage<bool>(context, const CreateBusinessEscrowPage());
            if (ok == true) _key.currentState?.reload();
          },
        ),
        body: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: BusinessOpsApi.escrows,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.verified_user_outlined,
          emptyTitle: 'No escrows',
          emptyMessage: 'Ask a buyer to fund an escrow before you deliver. Funds are released to you when they confirm.',
          builder: (c, items, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final e in items)
              BizTile(
                title: '${e['title']}',
                subtitle: money(e['amount']),
                trailing: StatusChip(statusLabel('${e['status']}'), filled: e['status'] == 'released'),
                onTap: () async {
                  await pushPage(c, BusinessEscrowDetailPage(id: '${e['id']}'));
                  reload();
                },
              ),
          ]),
        ),
      );
}

class CreateBusinessEscrowPage extends StatefulWidget {
  const CreateBusinessEscrowPage({super.key});
  @override
  State<CreateBusinessEscrowPage> createState() => _CreateEscrowState();
}

class _CreateEscrowState extends State<CreateBusinessEscrowPage> {
  final _form = GlobalKey<FormState>();
  final _buyer = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _milestones = <(TextEditingController, TextEditingController)>[];
  DateTime? _expires;

  @override
  void dispose() {
    for (final c in [_buyer, _title, _desc, _amount]) {
      c.dispose();
    }
    for (final m in _milestones) {
      m.$1.dispose();
      m.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.createEscrow({
        'buyer_identifier': _buyer.text.trim(),
        'title': _title.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'amount': double.parse(_amount.text),
        if (_milestones.isNotEmpty)
          'milestones': [
            for (final m in _milestones) {'title': m.$1.text.trim(), 'amount': double.parse(m.$2.text)}
          ],
        if (_expires != null) 'expires_at': _expires!.toUtc().toIso8601String(),
      });
      return true;
    }, success: 'Escrow created');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  String? _req(String? v) => (v ?? '').trim().isEmpty ? 'Required' : null;
  String? _num(String? v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter an amount';

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'New escrow',
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(controller: _buyer, decoration: bizInput(context, 'Buyer username or phone'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(controller: _title, decoration: bizInput(context, 'Title'), validator: _req),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, maxLines: 3, decoration: bizInput(context, 'Description (optional)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: bizInput(context, 'Amount (FARM)'),
              validator: _num,
            ),
            const SizedBox(height: 16),
            Text('Milestones (optional, must add up to the amount)',
                style: TextStyle(fontWeight: FontWeight.w600, color: fgColor(context))),
            const SizedBox(height: 8),
            for (var i = 0; i < _milestones.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: TextFormField(
                          controller: _milestones[i].$1,
                          decoration: bizInput(context, 'Milestone ${i + 1}'),
                          validator: _req)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: TextFormField(
                          controller: _milestones[i].$2,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: bizInput(context, 'Amount'),
                          validator: _num)),
                  IconButton(
                    icon: Icon(Icons.close, color: mutedColor(context)),
                    onPressed: () => setState(() {
                      final m = _milestones.removeAt(i);
                      m.$1.dispose();
                      m.$2.dispose();
                    }),
                  ),
                ]),
              ),
            if (_milestones.length < 20)
              TextButton.icon(
                onPressed: () => setState(() => _milestones.add((TextEditingController(), TextEditingController()))),
                icon: Icon(Icons.add, color: fgColor(context)),
                label: Text('Add milestone', style: TextStyle(color: fgColor(context))),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now().add(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 90)));
                if (d != null) setState(() => _expires = DateTime(d.year, d.month, d.day, 23, 59));
              },
              child: Text(_expires == null ? 'Funding deadline: none (tap to set)' : 'Fund by ${shortDate(_expires!.toIso8601String())}'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(style: primaryButtonStyle(context), onPressed: _save, child: const Text('Create escrow')),
          ]),
        ),
      );
}

class BusinessEscrowDetailPage extends StatelessWidget {
  const BusinessEscrowDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Escrow',
        body: BizAsync<Map<String, dynamic>>(
          load: () => BusinessOpsApi.escrow(id),
          builder: (c, e, reload) {
            final s = '${e['status']}';
            final ms = ((e['milestones'] as List?) ?? const []).whereType<Map>().toList();
            Future<void> act(String action, String title, String msg, String confirm) async {
              if (!await confirmAction(c, title: title, message: msg, confirm: confirm)) return;
              final ok = await runBusy(c, () async {
                await BusinessOpsApi.escrowAction(id, action);
                return true;
              });
              if (ok == true) reload();
            }

            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${e['title']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(statusLabel(s), filled: s == 'released'),
                  ]),
                  const SizedBox(height: 8),
                  KeyValue('Amount', money(e['amount'])),
                  if (e['expires_at'] != null) KeyValue('Fund by', shortDate(e['expires_at'])),
                  if (e['escrow_contract'] is Map) KeyValue('Escrow ref', '${e['escrow_contract']['reference_code']}'),
                  if ((e['description'] ?? '').toString().isNotEmpty) KeyValue('Description', '${e['description']}'),
                ]),
              ),
              if (ms.isNotEmpty) ...[
                const SizedBox(height: 12),
                BizCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Milestones', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                    if (e['released_amount'] != null && (e['released_amount'] as num) > 0)
                      KeyValue('Released so far', money(e['released_amount'])),
                    for (var i = 0; i < ms.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Expanded(child: KeyValue('${ms[i]['title']}', money(ms[i]['amount']))),
                          const SizedBox(width: 8),
                          if (ms[i]['status'] == 'pending' && (s == 'funded' || s == 'in_progress' || s == 'release_requested'))
                            TextButton(
                              onPressed: () async {
                                if (!await confirmAction(c,
                                    title: 'Request milestone release?',
                                    message: 'The buyer will be asked to release ${money(ms[i]['amount'])} for "${ms[i]['title']}".',
                                    confirm: 'Request')) {
                                  return;
                                }
                                final ok = await runBusy(c, () async {
                                  await BusinessOpsApi.requestMilestone(id, i);
                                  return true;
                                }, success: 'Release requested');
                                if (ok == true) reload();
                              },
                              child: Text('Request', style: TextStyle(color: fgColor(c))),
                            )
                          else
                            StatusChip(statusLabel('${ms[i]['status'] ?? 'pending'}'), filled: ms[i]['status'] == 'released'),
                        ]),
                      ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              if (s == 'created')
                ElevatedButton(
                    style: primaryButtonStyle(c),
                    onPressed: () => act('send', 'Send to buyer?', 'The buyer will be asked to fund ${money(e['amount'])}.', 'Send'),
                    child: const Text('Send to buyer')),
              if (s == 'funded')
                ElevatedButton(
                    style: primaryButtonStyle(c),
                    onPressed: () => act('start', 'Start work?', 'Mark this escrow as in progress.', 'Start'),
                    child: const Text('Mark in progress')),
              if (s == 'funded' || s == 'in_progress') ...[
                const SizedBox(height: 8),
                OutlinedButton(
                    style: secondaryButtonStyle(c),
                    onPressed: () => act('request-release', 'Request release?', 'The buyer will be asked to release the funds to you.', 'Request'),
                    child: const Text('Request release')),
              ],
              if (s == 'created' || s == 'awaiting_payment') ...[
                const SizedBox(height: 8),
                OutlinedButton(
                    style: secondaryButtonStyle(c),
                    onPressed: () => act('cancel', 'Withdraw request?', 'The buyer will no longer be able to fund it.', 'Withdraw'),
                    child: const Text('Withdraw request')),
              ],
              if (s == 'release_requested')
                Text('Waiting for the buyer to release the funds.', style: TextStyle(color: mutedColor(c))),
              if (s == 'disputed')
                Text('This escrow is disputed. Our team will review it.', style: TextStyle(color: mutedColor(c))),
            ]);
          },
        ),
      );
}
