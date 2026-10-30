import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_requests/developer_api.dart';
import '/core/config/app_config.dart';
import 'ops_ui.dart';

String _modeLabel(String m) => m == 'live' ? 'Live' : 'Sandbox';

class _ModeBanner extends StatelessWidget {
  const _ModeBanner(this.mode);
  final String mode;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: mode == 'live' ? fgColor(context) : Colors.transparent,
          border: Border.all(color: fgColor(context)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          mode == 'live'
              ? 'LIVE MODE · real money moves with these keys'
              : 'SANDBOX MODE · test data only, no real funds move',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: mode == 'live'
                  ? Theme.of(context).scaffoldBackgroundColor
                  : fgColor(context)),
        ),
      );
}

Future<void> _showSecret(BuildContext c, String title, String secret) => showDialog(
      context: c,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Copy it now. For security it will not be shown again.'),
          const SizedBox(height: 12),
          SelectableText(secret, style: const TextStyle(fontFamily: 'monospace')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: secret)).then((_) {
                    if (ctx.mounted) bizSnack(ctx, 'Copied');
                  }),
              child: Text('Copy', style: TextStyle(color: fgColor(ctx)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('I saved it', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
        ],
      ),
    );

// ---------------- Home ----------------
class DeveloperHomePage extends StatefulWidget {
  const DeveloperHomePage({super.key});
  @override
  State<DeveloperHomePage> createState() => _DevHomeState();
}

class _DevHomeState extends State<DeveloperHomePage> {
  String _mode = 'sandbox';
  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Developer API',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'sandbox', label: Text('Sandbox')),
            ButtonSegment(value: 'live', label: Text('Live')),
          ],
          selected: {_mode},
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
                ? Theme.of(context).scaffoldBackgroundColor
                : fgColor(context)),
            backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? fgColor(context) : Colors.transparent),
          ),
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 12),
        _ModeBanner(_mode),
        SizedBox(
          height: 150,
          child: BizAsync<Map<String, dynamic>>(
            key: ValueKey('ov$_mode'),
            load: () => DeveloperApi.overview(_mode),
            builder: (c, d, _) => GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 1.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _stat(c, 'Active keys', d['active_keys']),
                _stat(c, 'Webhooks', d['active_webhooks']),
                _stat(c, 'Requests 24h', d['requests_24h']),
                _stat(c, 'Errors 24h', d['errors_24h']),
                _stat(c, 'Failed deliveries', d['failed_deliveries']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        BizTile(leading: Icons.key_outlined, title: 'API keys', subtitle: 'Create, rotate and revoke ${_modeLabel(_mode).toLowerCase()} keys',
            onTap: () => pushPage(context, ApiKeysPage(mode: _mode))),
        BizTile(leading: Icons.webhook_outlined, title: 'Webhooks', subtitle: 'Signed event deliveries and logs',
            onTap: () => pushPage(context, WebhooksPage(mode: _mode))),
        BizTile(leading: Icons.bar_chart_rounded, title: 'Usage', subtitle: 'Requests and error rate',
            onTap: () => pushPage(context, ApiUsagePage(mode: _mode))),
        BizTile(leading: Icons.list_alt_rounded, title: 'Request logs', subtitle: 'Every API call made with your keys',
            onTap: () => pushPage(context, RequestLogsPage(mode: _mode))),
        BizTile(leading: Icons.lock_outline, title: 'Permissions', subtitle: 'Key scopes and what your role can grant',
            onTap: () => pushPage(context, const ApiPermissionsPage())),
        BizTile(leading: Icons.menu_book_outlined, title: 'API docs', subtitle: 'Authentication, endpoints and webhook signatures',
            onTap: () => pushPage(context, const ApiDocsPage())),
      ]),
    );
  }

  Widget _stat(BuildContext c, String l, dynamic v) => BizCard(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${v ?? 0}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fgColor(c))),
          Text(l, style: TextStyle(fontSize: 11, color: mutedColor(c))),
        ]),
      );
}

// ---------------- Keys ----------------
class ApiKeysPage extends StatefulWidget {
  const ApiKeysPage({super.key, required this.mode});
  final String mode;
  @override
  State<ApiKeysPage> createState() => _KeysState();
}

class _KeysState extends State<ApiKeysPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();

  Future<void> _create() async {
    final meta = await runBusy(context, DeveloperApi.meta);
    if (meta == null || !mounted) return;
    final scopes = ((meta['scopes'] as List?) ?? const []).whereType<Map>().toList();
    final chosen = scopes.where((s) => s['default'] == true && s['grantable'] == true).map((s) => '${s['scope']}').toSet();
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('New ${_modeLabel(widget.mode).toLowerCase()} key'),
          content: SizedBox(
            width: 400,
            child: ListView(shrinkWrap: true, children: [
              TextField(controller: name, decoration: bizInput(ctx, 'Key name', hint: 'e.g. Checkout server')),
              const SizedBox(height: 8),
              for (final s in scopes)
                CheckboxListTile(
                  dense: true,
                  activeColor: fgColor(ctx),
                  checkColor: Theme.of(ctx).scaffoldBackgroundColor,
                  value: chosen.contains('${s['scope']}'),
                  onChanged: s['grantable'] == true
                      ? (v) => set(() => v == true ? chosen.add('${s['scope']}') : chosen.remove('${s['scope']}'))
                      : null,
                  title: Text('${s['scope']}'),
                  subtitle: s['grantable'] == true ? null : const Text('Your role cannot grant this'),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
            TextButton(
                onPressed: () { if (name.text.trim().isNotEmpty && chosen.isNotEmpty) Navigator.pop(ctx, true); },
                child: Text('Create', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runBusy(context, () => DeveloperApi.createKey(name.text.trim(), widget.mode, chosen.toList()));
    if (r == null || !mounted) return;
    await _showSecret(context, 'Your new API key', '${r['secret']}');
    _key.currentState?.reload();
  }

  Future<void> _open(Map<String, dynamic> k) async {
    final active = k['status'] == 'active';
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
          Text('${k['name'] ?? 'API key'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(ctx))),
          const SizedBox(height: 8),
          KeyValue('Key', '${k['prefix']}••••••••'),
          KeyValue('Mode', _modeLabel('${k['mode']}')),
          KeyValue('Status', '${k['status']}'),
          KeyValue('Scopes', ((k['scopes'] as List?) ?? const []).join(', ')),
          KeyValue('Last used', k['last_used_at'] == null ? 'Never' : shortDate(k['last_used_at'])),
          KeyValue('Created', shortDate(k['created_at'])),
          if (active) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final pin = await confirmWithPin(context, title: 'Rotate key', message: 'A new key is created and this one stops working immediately.');
                if (pin == null || !mounted) return;
                final r = await runBusy(context, () => DeveloperApi.rotateKey('${k['id']}', pin));
                if (r == null || !mounted) return;
                await _showSecret(context, 'Your rotated API key', '${r['secret']}');
                _key.currentState?.reload();
              },
              child: Text('Rotate', style: TextStyle(color: fgColor(ctx))),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final pin = await confirmWithPin(context, title: 'Revoke key', message: 'Apps using this key will stop working. This cannot be undone.');
                if (pin == null || !mounted) return;
                await runBusy(context, () => DeveloperApi.revokeKey('${k['id']}', pin), success: 'Key revoked');
                _key.currentState?.reload();
              },
              child: Text('Revoke', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: '${_modeLabel(widget.mode)} keys',
        fab: BizFab(label: 'New key', onPressed: _create),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _ModeBanner(widget.mode),
            Expanded(
              child: BizAsync<List<Map<String, dynamic>>>(
                key: _key,
                load: () => DeveloperApi.keys(widget.mode),
                isEmpty: (l) => l.isEmpty,
                emptyIcon: Icons.key_off_outlined,
                emptyTitle: 'No ${_modeLabel(widget.mode).toLowerCase()} keys yet',
                emptyMessage: 'Create a key to call the FARM API.',
                builder: (c, l, _) => ListView(children: [
                  for (final k in l)
                    BizTile(
                      title: '${k['name'] ?? 'API key'}',
                      subtitle: '${k['prefix']}•••• · ${k['last_used_at'] == null ? 'never used' : 'used ${shortDate(k['last_used_at'])}'}',
                      trailing: StatusChip(k['status'] == 'active' ? 'Active' : 'Revoked', filled: k['status'] == 'active'),
                      onTap: () => _open(k),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ---------------- Webhooks ----------------
class WebhooksPage extends StatefulWidget {
  const WebhooksPage({super.key, required this.mode});
  final String mode;
  @override
  State<WebhooksPage> createState() => _HooksState();
}

class _HooksState extends State<WebhooksPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();

  Future<void> _create() async {
    final meta = await runBusy(context, DeveloperApi.meta);
    if (meta == null || !mounted) return;
    final events = ((meta['webhook_events'] as List?) ?? const []).map((e) => '$e').toList();
    final chosen = <String>{...events.where((e) => e != 'webhook.test')};
    final url = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Add webhook endpoint'),
          content: SizedBox(
            width: 400,
            child: ListView(shrinkWrap: true, children: [
              TextField(controller: url, keyboardType: TextInputType.url, decoration: bizInput(ctx, 'HTTPS URL', hint: 'https://example.com/farm/webhooks')),
              const SizedBox(height: 8),
              TextField(controller: desc, decoration: bizInput(ctx, 'Description (optional)')),
              for (final e in events)
                CheckboxListTile(
                  dense: true,
                  activeColor: fgColor(ctx),
                  checkColor: Theme.of(ctx).scaffoldBackgroundColor,
                  value: chosen.contains(e),
                  onChanged: (v) => set(() => v == true ? chosen.add(e) : chosen.remove(e)),
                  title: Text(e),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: mutedColor(ctx)))),
            TextButton(
                onPressed: () { if (url.text.trim().startsWith('https://') && chosen.isNotEmpty) Navigator.pop(ctx, true); },
                child: Text('Add', style: TextStyle(color: fgColor(ctx), fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final r = await runBusy(context, () => DeveloperApi.createWebhook({
          'url': url.text.trim(),
          'mode': widget.mode,
          if (desc.text.trim().isNotEmpty) 'description': desc.text.trim(),
          'events': chosen.toList(),
        }));
    if (r == null || !mounted) return;
    await _showSecret(context, 'Signing secret', '${r['signing_secret']}');
    _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: '${_modeLabel(widget.mode)} webhooks',
        fab: BizFab(label: 'Add endpoint', onPressed: _create),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _ModeBanner(widget.mode),
            Expanded(
              child: BizAsync<List<Map<String, dynamic>>>(
                key: _key,
                load: () => DeveloperApi.webhooks(widget.mode),
                isEmpty: (l) => l.isEmpty,
                emptyIcon: Icons.webhook_outlined,
                emptyTitle: 'No webhook endpoints',
                emptyMessage: 'Add an HTTPS endpoint to receive signed events.',
                builder: (c, l, _) => ListView(children: [
                  for (final w in l)
                    BizTile(
                      title: '${w['url']}',
                      subtitle: ((w['events'] as List?) ?? const []).join(', '),
                      trailing: StatusChip(w['is_active'] == true ? 'Active' : 'Disabled', filled: w['is_active'] == true),
                      onTap: () async {
                        await pushPage(context, WebhookDetailPage(endpoint: w));
                        _key.currentState?.reload();
                      },
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

class WebhookDetailPage extends StatefulWidget {
  const WebhookDetailPage({super.key, required this.endpoint});
  final Map<String, dynamic> endpoint;
  @override
  State<WebhookDetailPage> createState() => _HookDetailState();
}

class _HookDetailState extends State<WebhookDetailPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
  late Map<String, dynamic> e = widget.endpoint;
  String get id => '${e['id']}';

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Webhook',
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'test') {
                await runBusy(context, () => DeveloperApi.testWebhook(id), success: 'Test event sent');
                _key.currentState?.reload();
              } else if (v == 'toggle') {
                final r = await runBusy(context, () => DeveloperApi.updateWebhook(id, {'is_active': e['is_active'] != true}));
                if (r != null) setState(() => e = r);
              } else if (v == 'roll') {
                final pin = await confirmWithPin(context, title: 'Replace signing secret', message: 'Your server must switch to the new secret.');
                if (pin == null || !mounted) return;
                final r = await runBusy(context, () => DeveloperApi.rollSecret(id, pin));
                if (r != null && mounted) await _showSecret(context, 'New signing secret', '${r['signing_secret']}');
              } else if (v == 'delete') {
                final pin = await confirmWithPin(context, title: 'Delete endpoint', message: 'Deliveries and logs for this endpoint are deleted too.');
                if (pin == null || !mounted) return;
                final ok = await runBusy(context, () async { await DeveloperApi.deleteWebhook(id, pin); return true; }, success: 'Endpoint deleted');
                if (ok == true && mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'test', child: Text('Send test event')),
              PopupMenuItem(value: 'toggle', child: Text(e['is_active'] == true ? 'Disable' : 'Enable')),
              const PopupMenuItem(value: 'roll', child: Text('Replace signing secret')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KeyValue('URL', '${e['url']}'),
            KeyValue('Mode', _modeLabel('${e['mode']}')),
            KeyValue('Events', ((e['events'] as List?) ?? const []).join(', ')),
            KeyValue('Status', e['is_active'] == true ? 'Active' : 'Disabled'),
            const SizedBox(height: 12),
            Text('Delivery log', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
            const SizedBox(height: 8),
            Expanded(
              child: BizAsync<List<Map<String, dynamic>>>(
                key: _key,
                load: () => DeveloperApi.deliveries(id),
                isEmpty: (l) => l.isEmpty,
                emptyTitle: 'No deliveries yet',
                emptyMessage: 'Events sent to this endpoint will appear here.',
                builder: (c, l, reload) => ListView(children: [
                  for (final d in l)
                    BizTile(
                      title: '${d['event_type']}',
                      subtitle: '${shortDate(d['created_at'])} · attempts ${d['attempts']}'
                          '${d['response_status'] != null ? ' · HTTP ${d['response_status']}' : ''}'
                          '${d['error'] != null ? ' · ${d['error']}' : ''}',
                      trailing: d['status'] == 'succeeded'
                          ? const StatusChip('Delivered', filled: true)
                          : TextButton(
                              onPressed: () async {
                                await runBusy(c, () => DeveloperApi.retryDelivery('${d['id']}'), success: 'Retried');
                                reload();
                              },
                              child: Text('${d['status'] == 'failed' ? 'Failed' : 'Retrying'} · Retry', style: TextStyle(color: fgColor(c))),
                            ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ---------------- Usage ----------------
class ApiUsagePage extends StatefulWidget {
  const ApiUsagePage({super.key, required this.mode});
  final String mode;
  @override
  State<ApiUsagePage> createState() => _UsageState();
}

class _UsageState extends State<ApiUsagePage> {
  String _range = '7d';
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: '${_modeLabel(widget.mode)} usage',
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              for (final r in ['24h', '7d', '30d'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r),
                    selected: _range == r,
                    selectedColor: fgColor(context),
                    labelStyle: TextStyle(color: _range == r ? Theme.of(context).scaffoldBackgroundColor : fgColor(context)),
                    onSelected: (_) => setState(() => _range = r),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: BizAsync<Map<String, dynamic>>(
                key: ValueKey('u$_range'),
                load: () => DeveloperApi.usage(widget.mode, _range),
                isEmpty: (d) => (d['total'] ?? 0) == 0,
                emptyIcon: Icons.bar_chart_rounded,
                emptyTitle: 'No API requests in this period',
                emptyMessage: 'Usage appears once your keys make calls.',
                builder: (c, d, _) {
                  final series = ((d['series'] as List?) ?? const []).whereType<Map>().toList();
                  final peak = series.fold<int>(1, (m, s) => (s['total'] as num).toInt() > m ? (s['total'] as num).toInt() : m);
                  return ListView(children: [
                    KeyValue('Requests', '${d['total']}'),
                    KeyValue('Errors', '${d['errors']} (${d['error_rate']}%)'),
                    const SizedBox(height: 12),
                    for (final s in series)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          SizedBox(width: 90, child: Text(shortDate(s['bucket']), style: TextStyle(fontSize: 12, color: mutedColor(c)))),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (s['total'] as num) / peak,
                              minHeight: 10,
                              color: fgColor(c),
                              backgroundColor: borderColor(c),
                            ),
                          ),
                          SizedBox(width: 60, child: Text('  ${s['total']}', style: TextStyle(color: fgColor(c)))),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    Text('By key', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                    for (final k in ((d['by_key'] as List?) ?? const []).whereType<Map>())
                      KeyValue('${k['name'] ?? 'Deleted key'}', '${k['requests']} requests'),
                  ]);
                },
              ),
            ),
          ]),
        ),
      );
}

// ---------------- Request logs ----------------
class RequestLogsPage extends StatefulWidget {
  const RequestLogsPage({super.key, required this.mode});
  final String mode;
  @override
  State<RequestLogsPage> createState() => _LogsState();
}

class _LogsState extends State<RequestLogsPage> {
  bool _errors = false;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: '${_modeLabel(widget.mode)} request logs',
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            SwitchListTile(
              value: _errors,
              activeThumbColor: fgColor(context),
              title: const Text('Errors only'),
              onChanged: (v) => setState(() => _errors = v),
            ),
            Expanded(
              child: BizAsync<List<Map<String, dynamic>>>(
                key: ValueKey('l$_errors'),
                load: () => DeveloperApi.requests(widget.mode, errorsOnly: _errors),
                isEmpty: (l) => l.isEmpty,
                emptyIcon: Icons.list_alt_rounded,
                emptyTitle: 'No requests logged',
                emptyMessage: 'Calls made with your API keys appear here.',
                builder: (c, l, _) => ListView(children: [
                  for (final r in l)
                    BizTile(
                      title: '${r['method']} ${r['path']}',
                      subtitle: '${shortDate(r['created_at'])} · ${r['duration_ms']} ms · ${(r['api_key'] as Map?)?['name'] ?? 'deleted key'}',
                      trailing: StatusChip('${r['status_code']}', filled: (r['status_code'] as num) >= 400),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ---------------- Permissions ----------------
class ApiPermissionsPage extends StatelessWidget {
  const ApiPermissionsPage({super.key});
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'API permissions',
        body: BizAsync<Map<String, dynamic>>(
          load: DeveloperApi.meta,
          builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: [
            Text('Each key only gets the scopes chosen when it is created. A key can never do more than the person who created it. '
                'Only Owners, Admins and Developers can manage keys.',
                style: TextStyle(color: mutedColor(c))),
            const SizedBox(height: 12),
            for (final s in ((d['scopes'] as List?) ?? const []).whereType<Map>())
              BizTile(
                title: '${s['scope']}',
                subtitle: s['default'] == true ? 'Included by default' : 'Must be chosen explicitly',
                trailing: StatusChip(s['grantable'] == true ? 'You can grant' : 'Not for your role', filled: s['grantable'] == true),
              ),
          ]),
        ),
      );
}

// ---------------- Docs ----------------
class ApiDocsPage extends StatelessWidget {
  const ApiDocsPage({super.key});
  static String get docsUrl => '${AppConfig.baseUrl}/api/developer/docs';
  static String get openApiUrl => '${AppConfig.baseUrl}/api/developer/openapi.json';
  static String get base => '${AppConfig.baseUrl}/api/v1/farm';

  @override
  Widget build(BuildContext context) {
    Widget h(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fgColor(context))));
    Widget code(String t) => BizCard(
        padding: const EdgeInsets.all(12),
        child: SelectableText(t, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: fgColor(context))));
    return BizScaffold(
      title: 'API docs',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        OutlinedButton.icon(
          icon: Icon(Icons.open_in_new, color: fgColor(context)),
          label: Text('Open interactive docs', style: TextStyle(color: fgColor(context))),
          onPressed: () => launchUrl(Uri.parse(docsUrl), mode: LaunchMode.externalApplication),
        ),
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: openApiUrl)).then((_) {
            if (context.mounted) bizSnack(context, 'OpenAPI URL copied');
          }),
          child: Text('Copy OpenAPI JSON URL', style: TextStyle(color: mutedColor(context))),
        ),
        h('Base URL'),
        code(base),
        h('Authentication'),
        code('Authorization: Bearer farm_sk_test_…   (sandbox)\nAuthorization: Bearer farm_sk_live_…   (live)'),
        Text('Sandbox keys only touch test data. No real funds ever move in sandbox.', style: TextStyle(color: mutedColor(context))),
        h('Endpoints'),
        code('GET  /account\nGET  /transactions, /transactions/{id}\nGET  /payments\n'
            'GET/POST /payment-links, POST /payment-links/{id}/deactivate\n'
            'GET/POST /invoices, POST /invoices/{id}/send|cancel\n'
            'GET/POST /escrows, POST /escrows/{id}/send|cancel\n'
            'GET/POST /payouts\nGET  /projects (coming soon)\nGET  /webhook-events\n'
            'POST /sandbox/{payment-links|invoices|escrows}/{id}/simulate-payment'),
        h('Webhook signatures'),
        Text('Each delivery has a Farm-Signature header: t=<unix seconds>,v1=<hex>. '
            'Compute HMAC-SHA256 of "<t>.<raw body>" with your signing secret and compare. '
            'Reject events older than 5 minutes. Failed deliveries retry after 1m, 5m, 30m, 2h and 6h.',
            style: TextStyle(color: fgColor(context))),
      ]),
    );
  }
}
