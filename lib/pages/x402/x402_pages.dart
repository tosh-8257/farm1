import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/x402_api.dart';
import '/pages/business/ops/ops_ui.dart';

const _payLabels = {
  'settling': 'Processing',
  'pending': 'Pending',
  'settled': 'Paid',
  'failed': 'Failed',
};
String _pl(dynamic s) => _payLabels['$s'] ?? '$s';

void _copy(BuildContext c, String v) {
  Clipboard.setData(ClipboardData(text: v));
  bizSnack(c, 'Copied');
}

/// Business: APIs that agents pay for per request (x402 on Algorand).
class X402ResourcesPage extends StatelessWidget {
  const X402ResourcesPage({super.key});
  @override
  Widget build(BuildContext c) {
    final key = GlobalKey<BizAsyncState<(Map<String, dynamic>, List<Map<String, dynamic>>)>>();
    return BizScaffold(
      title: 'Paid APIs (x402)',
      actions: [
        IconButton(
            tooltip: 'Payments',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => pushPage(c, const X402PaymentsPage())),
      ],
      body: BizAsync<(Map<String, dynamic>, List<Map<String, dynamic>>)>(
        key: key,
        load: () async {
          final s = await X402Api.status();
          if (s['enabled'] != true) return (s, <Map<String, dynamic>>[]);
          return (s, await X402Api.resources());
        },
        builder: (c, d, reload) {
          final (s, list) = d;
          if (s['enabled'] != true) {
            return _Empty(
              icon: Icons.lock_outline,
              title: 'x402 payments are not enabled yet',
              message: 'Paid APIs turn on once the platform finishes setting up on-chain payments.',
            );
          }
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
              Text(
                'Agents pay per request in ${(s['assets'] as List? ?? []).join(' or ')} on Algorand. '
                'They are charged only when your API answers successfully.',
                style: TextStyle(color: mutedColor(c)),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _Empty(icon: Icons.api_outlined, title: 'No paid APIs yet', message: 'Add an HTTPS endpoint and set a price per call.'),
              for (final r in list)
                BizTile(
                  leading: Icons.api_outlined,
                  title: '${r['name']}',
                  subtitle: '${r['price']} ${r['asset']} per call · ${r['method']}',
                  trailing: StatusChip(r['status'] == 'active' ? 'Active' : 'Paused', filled: r['status'] == 'active'),
                  onTap: () async {
                    await pushPage(c, X402ResourcePage(id: '${r['id']}'));
                    reload();
                  },
                ),
            ]),
          );
        },
      ),
      fab: BizFab(
          label: 'New paid API',
          onPressed: () async {
            await pushPage(c, const _NewResourcePage());
            key.currentState?.reload();
          }),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          Icon(icon, size: 40, color: mutedColor(c)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: mutedColor(c))),
        ]),
      );
}

class _NewResourcePage extends StatefulWidget {
  const _NewResourcePage();
  @override
  State<_NewResourcePage> createState() => _NewResourcePageState();
}

class _NewResourcePageState extends State<_NewResourcePage> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _url = TextEditingController();
  final _price = TextEditingController();
  String _asset = 'FARM';
  String _method = 'GET';
  @override
  void dispose() {
    for (final t in [_name, _desc, _url, _price]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    final price = _price.text.trim();
    if (_name.text.trim().isEmpty) return bizSnack(context, 'Enter a name');
    if (!url.startsWith('https://')) return bizSnack(context, 'The endpoint must start with https://');
    if ((num.tryParse(price) ?? 0) <= 0) return bizSnack(context, 'Enter a price above 0');
    final r = await runBusy(
        context,
        () => X402Api.create({
              'name': _name.text.trim(),
              if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
              'upstream_url': url,
              'method': _method,
              'asset': _asset,
              'price': price,
            }));
    if (r == null || !mounted) return;
    final secret = '${r['signing_secret'] ?? ''}';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save your signing secret'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Use it to check the x-farm-x402-signature header on calls to your API. It is shown only once.'),
          const SizedBox(height: 12),
          SelectableText(secret, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => _copy(ctx, secret), child: Text('Copy', style: TextStyle(color: fgColor(ctx)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Widget _choice(String label, List<String> opts, String v, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: mutedColor(context)))),
          Wrap(spacing: 8, children: [
            for (final o in opts)
              ChoiceChip(
                label: Text(o),
                selected: v == o,
                selectedColor: fgColor(context),
                labelStyle: TextStyle(color: v == o ? Theme.of(context).scaffoldBackgroundColor : fgColor(context)),
                onSelected: (_) => setState(() => on(o)),
              ),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'New paid API',
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: bizInput(c, 'Name', hint: 'Crop price feed')),
          const SizedBox(height: 12),
          TextField(controller: _desc, decoration: bizInput(c, 'Description (optional)')),
          const SizedBox(height: 12),
          TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: bizInput(c, 'Your API endpoint', hint: 'https://api.example.com/prices')),
          const SizedBox(height: 12),
          TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: bizInput(c, 'Price per call')),
          const SizedBox(height: 12),
          _choice('Asset', const ['FARM', 'USDC'], _asset, (v) => _asset = v),
          _choice('Method', const ['GET', 'POST', 'ANY'], _method, (v) => _method = v),
          const SizedBox(height: 8),
          ElevatedButton(style: primaryButtonStyle(c), onPressed: _save, child: const Text('Create')),
        ]),
      );
}

class X402ResourcePage extends StatelessWidget {
  const X402ResourcePage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Paid API',
        body: BizAsync<Map<String, dynamic>>(
          load: () => X402Api.resource(id),
          builder: (c, r, reload) {
            final active = r['status'] == 'active';
            final url = X402Api.gatewayUrl('${r['gateway_path']}');
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['name']}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(active ? 'Active' : 'Paused', filled: active),
                  ]),
                  const Divider(),
                  KeyValue('Price', '${r['price']} ${r['asset']} per call'),
                  KeyValue('Method', '${r['method']}'),
                  KeyValue('Your endpoint', '${r['upstream_url']}'),
                  Row(children: [
                    Expanded(child: KeyValue('Pay-per-call URL', url)),
                    IconButton(icon: Icon(Icons.copy, size: 18, color: mutedColor(c)), onPressed: () => _copy(c, url)),
                  ]),
                  KeyValue('Paid to', '${r['pay_to']}'),
                  KeyValue('Created', shortDate(r['created_at'])),
                ]),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () async {
                  if (active &&
                      !await confirmAction(c,
                          title: 'Pause this API?', message: 'Agents will get "not found" until you turn it back on.', confirm: 'Pause')) {
                    return;
                  }
                  if (!c.mounted) return;
                  final x = await runBusy(c, () => X402Api.update(id, {'status': active ? 'paused' : 'active'}),
                      success: active ? 'Paused' : 'Active');
                  if (x != null) reload();
                },
                child: Text(active ? 'Pause' : 'Turn on'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: secondaryButtonStyle(c),
                onPressed: () => pushPage(c, X402PaymentsPage(resourceId: id)),
                child: const Text('View payments'),
              ),
            ]);
          },
        ),
      );
}

class X402PaymentsPage extends StatelessWidget {
  const X402PaymentsPage({super.key, this.resourceId});
  final String? resourceId;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'x402 payments',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: () => X402Api.payments(resourceId: resourceId),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.receipt_long_outlined,
          emptyTitle: 'No payments yet',
          emptyMessage: 'Payments appear here once agents pay for calls.',
          builder: (c, list, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final p in list)
                BizTile(
                  leading: Icons.bolt_outlined,
                  title: '${p['amount']} ${p['asset']}',
                  subtitle: '${shortDate(p['created_at'])} · ${'${p['transaction']}'.substring(0, 8)}…'
                      '${p['source'] == 'facilitator' ? ' · Facilitator' : ''}'
                      '${p['error'] != null ? ' · ${p['error']}' : ''}',
                  trailing: StatusChip(_pl(p['status']), filled: p['status'] == 'settled'),
                  onTap: () => _copy(c, '${p['transaction']}'),
                ),
            ]),
          ),
        ),
      );
}
