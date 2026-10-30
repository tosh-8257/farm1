import '/components/fee_line.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';

// ---------------- Payment links ----------------
class PaymentLinksPage extends StatefulWidget {
  const PaymentLinksPage({super.key});
  @override
  State<PaymentLinksPage> createState() => _LinksState();
}

class _LinksState extends State<PaymentLinksPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Payment links',
        fab: BizFab(
          label: 'New link',
          onPressed: () async {
            final ok = await pushPage<bool>(context, const CreatePaymentLinkPage());
            if (ok == true) _key.currentState?.reload();
          },
        ),
        body: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: BusinessOpsApi.links,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.link_rounded,
          emptyTitle: 'No payment links',
          emptyMessage: 'Create a link with a fixed amount and share its code so Farm users can pay you.',
          builder: (c, items, reload) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final l in items)
              BizTile(
                title: '${l['title']}',
                subtitle: '${money(l['amount'])} · code ${l['code']} · ${l['use_count']} paid',
                trailing: StatusChip(statusLabel('${l['state']}'), filled: l['state'] == 'active'),
                onTap: () async {
                  await pushPage(c, PaymentLinkDetailPage(id: '${l['id']}'));
                  reload();
                },
              ),
          ]),
        ),
      );
}

class CreatePaymentLinkPage extends StatefulWidget {
  const CreatePaymentLinkPage({super.key});
  @override
  State<CreatePaymentLinkPage> createState() => _CreateLinkState();
}

class _CreateLinkState extends State<CreatePaymentLinkPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  final _maxUses = TextEditingController();
  DateTime? _expires;

  @override
  void dispose() {
    for (final c in [_title, _desc, _amount, _maxUses]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.createLink({
        'title': _title.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'amount': double.parse(_amount.text),
        if (_maxUses.text.isNotEmpty) 'max_uses': int.parse(_maxUses.text),
        if (_expires != null) 'expires_at': _expires!.toUtc().toIso8601String(),
      });
      return true;
    }, success: 'Payment link created');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'New payment link',
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
                controller: _title,
                decoration: bizInput(context, 'Title'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _desc, maxLines: 3, decoration: bizInput(context, 'Description (optional)')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: bizInput(context, 'Amount (FARM)'),
              onChanged: (_) => setState(() {}),
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Enter an amount',
            ),
            FeeLine(
                feeKey: 'merchant',
                amount: double.tryParse(_amount.text.trim()) ?? 0,
                payerPays: false,
                label: 'Merchant fee'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxUses,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: bizInput(context, 'Maximum payments (optional)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now().add(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _expires = DateTime(d.year, d.month, d.day, 23, 59));
              },
              child: Text(_expires == null ? 'No expiry (tap to set)' : 'Expires ${shortDate(_expires!.toIso8601String())}'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(style: primaryButtonStyle(context), onPressed: _save, child: const Text('Create link')),
          ]),
        ),
      );
}

class PaymentLinkDetailPage extends StatelessWidget {
  const PaymentLinkDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Payment link',
        body: BizAsync<Map<String, dynamic>>(
          load: () => BusinessOpsApi.link(id),
          builder: (c, l, reload) {
            final payments = ((l['payments'] as List?) ?? const []).whereType<Map>().toList();
            final active = l['is_active'] == true;
            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${l['title']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(statusLabel('${l['state']}'), filled: l['state'] == 'active'),
                  ]),
                  const SizedBox(height: 10),
                  KeyValue('Amount', money(l['amount'])),
                  KeyValue('Code', '${l['code']}'),
                  KeyValue('Payments', '${l['use_count']}${l['max_uses'] != null ? ' of ${l['max_uses']}' : ''}'),
                  KeyValue('Expires', l['expires_at'] == null ? 'Never' : shortDate(l['expires_at'])),
                  if ((l['description'] ?? '').toString().isNotEmpty) KeyValue('Description', '${l['description']}'),
                ]),
              ),
              const SizedBox(height: 12),
              if ((l['url'] ?? '').toString().isNotEmpty) ...[
                ElevatedButton.icon(
                  style: primaryButtonStyle(c),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share payment link'),
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text: 'Pay ${l['title'] ?? ''} (${money(l['amount'])}): ${l['url']}')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: secondaryButtonStyle(c),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Copy link'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${l['url']}'));
                    bizSnack(c, 'Link copied. Anyone can pay it, with or without the FARM app.');
                  },
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                style: secondaryButtonStyle(c),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy payment code'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: '${l['code']}'));
                  bizSnack(c, 'Code copied. Customers pay it from Pay a business.');
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  if (active &&
                      !await confirmAction(c,
                          title: 'Disable link?',
                          message: 'Customers will no longer be able to pay with this code.',
                          confirm: 'Disable')) {
                    return;
                  }
                  final ok = await runBusy(c, () async {
                    await BusinessOpsApi.setLinkActive(id, !active);
                    return true;
                  });
                  if (ok == true) reload();
                },
                child: Text(active ? 'Disable link' : 'Enable link'),
              ),
              const SizedBox(height: 20),
              Text('Payments', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                Text('No payments yet.', style: TextStyle(color: mutedColor(c)))
              else
                for (final p in payments)
                  BizTile(title: money(p['amount']), subtitle: '${p['transaction_reference']} · ${shortDate(p['created_at'])}'),
            ]);
          },
        ),
      );
}

// ---------------- Customers ----------------
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});
  @override
  State<CustomersPage> createState() => _CustomersState();
}

class _CustomersState extends State<CustomersPage> {
  String _search = '';
  int _rev = 0;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Customers',
        fab: BizFab(
          label: 'Add customer',
          onPressed: () async {
            final ok = await pushPage<bool>(context, const CustomerFormPage());
            if (ok == true) setState(() => _rev++);
          },
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: bizInput(context, 'Search name, email or phone'),
              onSubmitted: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: BizAsync<List<Map<String, dynamic>>>(
              key: ValueKey('$_search-$_rev'),
              load: () => BusinessOpsApi.customers(search: _search),
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.people_outline,
              emptyTitle: _search.isEmpty ? 'No customers yet' : 'No matches',
              emptyMessage: _search.isEmpty ? 'Add customers to invoice them faster.' : '',
              builder: (c, items, reload) => ListView(padding: const EdgeInsets.all(16), children: [
                for (final cu in items)
                  BizTile(
                    leading: Icons.person_outline,
                    title: '${cu['name']}',
                    subtitle: [cu['email'], cu['phone']].where((e) => e != null && '$e'.isNotEmpty).join(' · '),
                    onTap: () async {
                      await pushPage(c, CustomerDetailPage(id: '${cu['id']}'));
                      reload();
                    },
                  ),
              ]),
            ),
          ),
        ]),
      );
}

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.customer});
  final Map<String, dynamic>? customer;
  @override
  State<CustomerFormPage> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?['name'] ?? '');
  late final _email = TextEditingController(text: widget.customer?['email'] ?? '');
  late final _phone = TextEditingController(text: widget.customer?['phone'] ?? '');
  late final _notes = TextEditingController(text: widget.customer?['notes'] ?? '');

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.saveCustomer({
        'name': _name.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      }, id: widget.customer?['id']?.toString());
      return true;
    }, success: 'Customer saved');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: widget.customer == null ? 'Add customer' : 'Edit customer',
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            TextFormField(
                controller: _name,
                decoration: bizInput(context, 'Name'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: bizInput(context, 'Email (optional)'),
                validator: (v) => (v ?? '').isEmpty || RegExp(r'^\S+@\S+\.\S+$').hasMatch(v!) ? null : 'Invalid email'),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: bizInput(context, 'Phone (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: bizInput(context, 'Notes (optional)')),
            const SizedBox(height: 24),
            ElevatedButton(style: primaryButtonStyle(context), onPressed: _save, child: const Text('Save')),
          ]),
        ),
      );
}

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Customer',
        body: BizAsync<Map<String, dynamic>>(
          load: () => BusinessOpsApi.customer(id),
          builder: (c, cu, reload) {
            final invoices = ((cu['invoices'] as List?) ?? const []).whereType<Map>().toList();
            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${cu['name']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c))),
                  const SizedBox(height: 8),
                  KeyValue('Email', '${cu['email'] ?? '—'}'),
                  KeyValue('Phone', '${cu['phone'] ?? '—'}'),
                  KeyValue('Notes', '${cu['notes'] ?? '—'}'),
                ]),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  final ok = await pushPage<bool>(c, CustomerFormPage(customer: cu));
                  if (ok == true) reload();
                },
                child: const Text('Edit'),
              ),
              const SizedBox(height: 20),
              Text('Invoices', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              if (invoices.isEmpty)
                Text('No invoices for this customer yet.', style: TextStyle(color: mutedColor(c)))
              else
                for (final i in invoices)
                  BizTile(
                    title: '${i['invoice_number']}',
                    subtitle: money(i['total']),
                    trailing: StatusChip(statusLabel('${i['status']}'), filled: i['status'] == 'paid'),
                    onTap: () => pushPage(c, InvoiceDetailPage(id: '${i['id']}')),
                  ),
            ]);
          },
        ),
      );
}

// ---------------- Invoices ----------------
const invoiceFilters = ['all', 'draft', 'sent', 'pending', 'paid', 'overdue', 'cancelled'];

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});
  @override
  State<InvoicesPage> createState() => _InvoicesState();
}

class _InvoicesState extends State<InvoicesPage> {
  String _filter = 'all';
  int _rev = 0;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Invoices',
        fab: BizFab(
          label: 'New invoice',
          onPressed: () async {
            final ok = await pushPage<bool>(context, const CreateInvoicePage());
            if (ok == true) setState(() => _rev++);
          },
        ),
        body: Column(children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final f in invoiceFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                        onTap: () => setState(() => _filter = f),
                        child: StatusChip(statusLabel(f), filled: _filter == f)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: BizAsync<List<Map<String, dynamic>>>(
              key: ValueKey('$_filter-$_rev'),
              load: () => BusinessOpsApi.invoices(status: _filter == 'all' ? null : _filter),
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.receipt_long_outlined,
              emptyTitle: 'No invoices',
              emptyMessage: 'Create an invoice, issue it, and your customer pays it from Pay a business.',
              builder: (c, items, reload) => ListView(padding: const EdgeInsets.all(16), children: [
                for (final i in items)
                  BizTile(
                    title: '${i['invoice_number']}',
                    subtitle: '${(i['customer'] as Map?)?['name'] ?? 'No customer'} · ${money(i['total'])}'
                        '${i['due_date'] != null ? ' · due ${shortDate(i['due_date'])}' : ''}',
                    trailing: StatusChip(statusLabel('${i['status']}'), filled: i['status'] == 'paid'),
                    onTap: () async {
                      await pushPage(c, InvoiceDetailPage(id: '${i['id']}'));
                      reload();
                    },
                  ),
              ]),
            ),
          ),
        ]),
      );
}

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});
  @override
  State<CreateInvoicePage> createState() => _CreateInvoiceState();
}

class _Line {
  final desc = TextEditingController();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  double get amount => (int.tryParse(qty.text) ?? 0) * (double.tryParse(price.text) ?? 0);
  void dispose() {
    desc.dispose();
    qty.dispose();
    price.dispose();
  }
}

class _CreateInvoiceState extends State<CreateInvoicePage> {
  final _form = GlobalKey<FormState>();
  final _lines = <_Line>[_Line()];
  final _notes = TextEditingController();
  List<Map<String, dynamic>>? _customers;
  String? _customerId;
  DateTime? _due;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final l = await BusinessOpsApi.customers();
      if (mounted) setState(() => _customers = l);
    } catch (e) {
      if (mounted) setState(() => _loadError = friendlyError(e));
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0, (s, l) => s + l.amount);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runBusy(context, () async {
      await BusinessOpsApi.createInvoice({
        if (_customerId != null) 'customer_id': _customerId,
        'items': [
          for (final l in _lines)
            {
              'description': l.desc.text.trim(),
              'quantity': int.parse(l.qty.text),
              'unit_price': double.parse(l.price.text),
            }
        ],
        if (_due != null) 'due_date': shortDate(_due!.toIso8601String()),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      return true;
    }, success: 'Invoice saved as draft');
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'New invoice',
        body: Form(
          key: _form,
          onChanged: () => setState(() {}),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (_loadError != null)
              BizTile(title: 'Could not load customers', subtitle: _loadError, trailing: TextButton(onPressed: _loadCustomers, child: const Text('Retry')))
            else if (_customers == null)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<String?>(
                initialValue: _customerId,
                decoration: bizInput(context, 'Customer (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No customer')),
                  for (final c in _customers!) DropdownMenuItem(value: '${c['id']}', child: Text('${c['name']}')),
                ],
                onChanged: (v) => setState(() => _customerId = v),
              ),
            const SizedBox(height: 16),
            for (var i = 0; i < _lines.length; i++) ...[
              BizCard(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                        child: Text('Item ${i + 1}',
                            style: TextStyle(fontWeight: FontWeight.w600, color: fgColor(context)))),
                    if (_lines.length > 1)
                      IconButton(
                        icon: Icon(Icons.close, color: mutedColor(context)),
                        onPressed: () => setState(() => _lines.removeAt(i).dispose()),
                      ),
                  ]),
                  TextFormField(
                      controller: _lines[i].desc,
                      decoration: bizInput(context, 'Description'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _lines[i].qty,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: bizInput(context, 'Qty'),
                        validator: (v) => (int.tryParse(v ?? '') ?? 0) >= 1 ? null : '≥1',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: bizInput(context, 'Unit price (FARM)'),
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Required',
                      ),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
            ],
            if (_lines.length < 50)
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_Line())),
                icon: Icon(Icons.add, color: fgColor(context)),
                label: Text('Add item', style: TextStyle(color: fgColor(context))),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _due = d);
              },
              child: Text(_due == null ? 'No due date (tap to set)' : 'Due ${shortDate(_due!.toIso8601String())}'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, maxLines: 3, decoration: bizInput(context, 'Notes (optional)')),
            const SizedBox(height: 16),
            Text('Estimated total ${money(_total)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fgColor(context))),
            Text('The final total is calculated by the server.', style: TextStyle(fontSize: 12, color: mutedColor(context))),
            FeeLine(feeKey: 'merchant', amount: _total, payerPays: false, label: 'Merchant fee'),
            const SizedBox(height: 20),
            ElevatedButton(style: primaryButtonStyle(context), onPressed: _save, child: const Text('Save draft')),
          ]),
        ),
      );
}

class InvoiceDetailPage extends StatelessWidget {
  const InvoiceDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Invoice',
        body: BizAsync<Map<String, dynamic>>(
          load: () => BusinessOpsApi.invoice(id),
          builder: (c, inv, reload) {
            final status = '${inv['status']}';
            final items = ((inv['items'] as List?) ?? const []).whereType<Map>().toList();
            Future<void> act(String action, String title, String msg, String confirm) async {
              if (!await confirmAction(c, title: title, message: msg, confirm: confirm)) return;
              final ok = await runBusy(c, () async {
                await BusinessOpsApi.invoiceAction(id, action);
                return true;
              });
              if (ok == true) reload();
            }

            return ListView(padding: const EdgeInsets.all(20), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${inv['invoice_number']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(statusLabel(status), filled: status == 'paid'),
                  ]),
                  const SizedBox(height: 8),
                  KeyValue('Customer', '${(inv['customer'] as Map?)?['name'] ?? '—'}'),
                  KeyValue('Due', shortDate(inv['due_date'])),
                  KeyValue('Issued', shortDate(inv['sent_at'])),
                  if (inv['paid_at'] != null) KeyValue('Paid', shortDate(inv['paid_at'])),
                  if (inv['transaction_reference'] != null) KeyValue('Payment ref', '${inv['transaction_reference']}'),
                ]),
              ),
              const SizedBox(height: 12),
              BizCard(
                child: Column(children: [
                  for (final it in items)
                    KeyValue('${it['description']} ×${it['quantity']}', money(it['amount'])),
                  Divider(color: borderColor(c)),
                  KeyValue('Total', money(inv['total'])),
                ]),
              ),
              if ((inv['notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${inv['notes']}', style: TextStyle(color: mutedColor(c))),
              ],
              const SizedBox(height: 16),
              if (status == 'draft')
                ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () => act('send', 'Issue invoice?', 'After issuing, the invoice can no longer be edited. If the customer has an email address, we email them a pay link.', 'Issue'),
                  child: const Text('Issue invoice'),
                ),
              if (['sent', 'pending', 'overdue'].contains(status) &&
                  (inv['pay_url'] ?? '').toString().isNotEmpty) ...[
                ElevatedButton.icon(
                  style: primaryButtonStyle(c),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share pay link'),
                  onPressed: () => SharePlus.instance.share(ShareParams(
                      text: 'Invoice ${inv['invoice_number']} (${money(inv['total'])}): ${inv['pay_url']}')),
                ),
                const SizedBox(height: 8),
                if ((inv['customer']?['email'] ?? '').toString().isNotEmpty) ...[
                  OutlinedButton.icon(
                    style: secondaryButtonStyle(c),
                    icon: const Icon(Icons.email_outlined),
                    label: Text(inv['last_emailed_at'] == null
                        ? 'Email invoice'
                        : 'Email again (last sent ${shortDate(inv['last_emailed_at'])})'),
                    onPressed: () => act('resend', 'Email invoice?',
                        'We will email ${inv['customer']['email']} a link to pay this invoice.', 'Send'),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (['sent', 'pending', 'overdue'].contains(status))
                OutlinedButton.icon(
                  style: secondaryButtonStyle(c),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy invoice number'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: '${inv['invoice_number']}'));
                    bizSnack(c, 'Invoice number copied');
                  },
                ),
              if (['draft', 'sent', 'pending', 'overdue'].contains(status)) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: secondaryButtonStyle(c),
                  onPressed: () => act('cancel', 'Cancel invoice?', 'The customer will no longer be able to pay it. This cannot be undone.', 'Cancel invoice'),
                  child: const Text('Cancel invoice'),
                ),
              ],
            ]);
          },
        ),
      );
}
