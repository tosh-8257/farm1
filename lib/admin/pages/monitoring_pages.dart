import 'package:flutter/material.dart';
import '/backend/api_requests/business_ops_api.dart';
import '/backend/services/api_service.dart';
import '/pages/business/ops/ops_ui.dart';

/// Gap fix: admin review/monitoring for projects & listings, tokenization, and agent / x402 payments.
Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
  final r = await ApiService.request(method: 'POST', path: path, body: body);
  return r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
}

class _AdminFrame extends StatelessWidget {
  const _AdminFrame({required this.title, this.onGoBack, required this.filters, required this.filter, required this.onFilter, required this.child});
  final String title;
  final VoidCallback? onGoBack;
  final Map<String, String> filters;
  final String filter;
  final ValueChanged<String> onFilter;
  final Widget child;
  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Theme.of(c).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(c).scaffoldBackgroundColor,
          foregroundColor: fgColor(c),
          leading: onGoBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onGoBack),
          title: Text(title, style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700)),
        ),
        body: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              for (final e in filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(e.value), selected: filter == e.key, onSelected: (_) => onFilter(e.key)),
                ),
            ]),
          ),
          Expanded(child: child),
        ]),
      );
}

Future<String?> _notes(BuildContext c, String title, {bool required = false}) async {
  final t = TextEditingController();
  final ok = await showDialog<bool>(
    context: c,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: t, maxLines: 3, decoration: bizInput(d, required ? 'Notes (required, audited)' : 'Notes (optional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        ElevatedButton(style: primaryButtonStyle(d), onPressed: () => Navigator.pop(d, true), child: const Text('Submit')),
      ],
    ),
  );
  final v = t.text.trim();
  t.dispose();
  if (ok != true) return null;
  if (required && v.isEmpty) {
    if (c.mounted) bizSnack(c, 'Notes are required');
    return null;
  }
  return v;
}

// ---------------- Projects & listings ----------------
const _projectActions = {
  'submitted': ['request_info', 'approve', 'reject'],
  'more_info_required': ['reject'],
  'approved': ['list', 'reject', 'cancel'],
  'listed': ['unlist', 'close', 'cancel'],
  'funded': ['close', 'cancel'],
};
const _actionLabels = {
  'request_info': 'Request info', 'approve': 'Approve', 'reject': 'Reject', 'list': 'List on marketplace',
  'unlist': 'Unlist', 'close': 'Close', 'cancel': 'Cancel',
};

class ProjectsReviewPage extends StatefulWidget {
  const ProjectsReviewPage({super.key, this.onGoBack});
  final VoidCallback? onGoBack;
  @override
  State<ProjectsReviewPage> createState() => _ProjectsReviewPageState();
}

class _ProjectsReviewPageState extends State<ProjectsReviewPage> {
  String _f = 'submitted';
  int _gen = 0;
  Future<void> _act(BuildContext c, Map p, String action) async {
    final notes = await _notes(c, '${_actionLabels[action]}: ${p['project_name'] ?? 'project'}', required: action == 'request_info' || action == 'reject');
    if (notes == null || !c.mounted) return;
    final r = await runBusy(c, () => _post('/admin/projects/${p['id']}/review', {'action': action, if (notes.isNotEmpty) 'notes': notes}), success: 'Done');
    if (r != null) setState(() => _gen++);
  }

  @override
  Widget build(BuildContext c) => _AdminFrame(
        title: 'Projects & listings',
        onGoBack: widget.onGoBack,
        filters: const {'submitted': 'Submitted', 'more_info_required': 'Info requested', 'approved': 'Approved', 'listed': 'Listed', 'rejected': 'Rejected'},
        filter: _f,
        onFilter: (v) => setState(() => _f = v),
        child: BizAsync<List<Map<String, dynamic>>>(
          key: ValueKey('$_f$_gen'),
          load: () async => BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/admin/projects?status=$_f&limit=50')),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.agriculture_outlined,
          emptyTitle: 'Nothing here',
          emptyMessage: 'Projects in this state appear here.',
          builder: (c, list, _) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BizCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${p['project_name'] ?? 'Project'}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                      StatusChip('${p['status']}', filled: p['status'] == 'listed'),
                    ]),
                    const SizedBox(height: 6),
                    KeyValue('Business', '${(p['business'] as Map?)?['trading_name'] ?? (p['business'] as Map?)?['legal_name'] ?? '-'}'),
                    KeyValue('Business status', '${(p['business'] as Map?)?['status'] ?? '-'}'),
                    KeyValue('Target', '${money(p['target_amount'])}'),
                    KeyValue('Raised', '${money(p['raised_amount'])}'),
                    KeyValue('Sector', '${p['sector'] ?? '-'}'),
                    if (p['review_notes'] != null) KeyValue('Review notes', '${p['review_notes']}'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final a in _projectActions['${p['status']}'] ?? const <String>[])
                        OutlinedButton(style: secondaryButtonStyle(c), onPressed: () => _act(c, p, a), child: Text(_actionLabels[a]!)),
                    ]),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

// ---------------- Tokenization ----------------
class TokenizationReviewPage extends StatefulWidget {
  const TokenizationReviewPage({super.key, this.onGoBack});
  final VoidCallback? onGoBack;
  @override
  State<TokenizationReviewPage> createState() => _TokenizationReviewPageState();
}

class _TokenizationReviewPageState extends State<TokenizationReviewPage> {
  String _f = 'requested';
  int _gen = 0;
  @override
  Widget build(BuildContext c) => _AdminFrame(
        title: 'Tokenization',
        onGoBack: widget.onGoBack,
        filters: const {'requested': 'Requested', 'confirmed': 'Minted', 'failed': 'Failed', 'rejected': 'Rejected', '': 'All'},
        filter: _f,
        onFilter: (v) => setState(() => _f = v),
        child: BizAsync<List<Map<String, dynamic>>>(
          key: ValueKey('$_f$_gen'),
          load: () async => BusinessOpsApi.list(await ApiService.request(method: 'GET', path: '/admin/tokenization${_f.isEmpty ? '' : '?status=$_f'}')),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.token_outlined,
          emptyTitle: 'Nothing here',
          emptyMessage: 'Tokenization requests appear here.',
          builder: (c, list, _) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final t in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BizCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${(t['project'] as Map?)?['project_name'] ?? t['asset_name'] ?? 'Token'}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                      StatusChip('${t['status']}', filled: t['status'] == 'confirmed'),
                    ]),
                    const SizedBox(height: 6),
                    KeyValue('Asset', '${t['asset_name'] ?? '-'} (${t['unit_name'] ?? '-'})'),
                    KeyValue('Units', '${t['total_units'] ?? '-'}'),
                    KeyValue('Unit price', '${money(t['unit_price'])}'),
                    KeyValue('Network', '${t['network'] ?? '-'}'),
                    if (t['asset_id'] != null) KeyValue('Asset id', '${t['asset_id']}'),
                    if (t['error'] != null) KeyValue('Error', '${t['error']}'),
                    if (t['status'] == 'requested') ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: secondaryButtonStyle(c),
                            onPressed: () async {
                              final n = await _notes(c, 'Reject tokenization', required: true);
                              if (n == null || !c.mounted) return;
                              final r = await runBusy(c, () => _post('/admin/tokenization/${t['id']}/reject', {'notes': n}), success: 'Rejected');
                              if (r != null) setState(() => _gen++);
                            },
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: primaryButtonStyle(c),
                            onPressed: () async {
                              if (!await confirmAction(c,
                                  title: 'Approve and mint?',
                                  message: 'This creates the project token on ${t['network'] ?? 'the configured network'}. It cannot be undone.',
                                  confirm: 'Approve & mint')) return;
                              if (!c.mounted) return;
                              final r = await runBusy(c, () => _post('/admin/tokenization/${t['id']}/approve'), success: 'Submitted');
                              if (r != null) setState(() => _gen++);
                            },
                            child: const Text('Approve & mint'),
                          ),
                        ),
                      ]),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
      );
}

// ---------------- Payments monitor (read-only) ----------------
class PaymentsMonitorPage extends StatefulWidget {
  const PaymentsMonitorPage({super.key, this.onGoBack});
  final VoidCallback? onGoBack;
  @override
  State<PaymentsMonitorPage> createState() => _PaymentsMonitorPageState();
}

class _PaymentsMonitorPageState extends State<PaymentsMonitorPage> {
  String _f = 'intents';
  @override
  Widget build(BuildContext c) => _AdminFrame(
        title: 'Payments monitor',
        onGoBack: widget.onGoBack,
        filters: const {'intents': 'Payment requests', 'agent_requests': 'Agent payments', 'x402': 'x402'},
        filter: _f,
        onFilter: (v) => setState(() => _f = v),
        child: BizAsync<Map<String, dynamic>>(
          key: ValueKey(_f),
          load: () async {
            final r = await ApiService.request(method: 'GET', path: '/admin/payments-monitor?kind=$_f');
            return r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : r;
          },
          builder: (c, d, reload) {
            final counts = Map<String, dynamic>.from((d['counts'] as Map?)?[_f] as Map? ?? {});
            final rows = ((d[_f] as List?) ?? const []).whereType<Map>().toList();
            return RefreshIndicator(
              onRefresh: reload,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in counts.entries) StatusChip('${e.key}: ${e.value}'),
                  if (counts.isEmpty) Text('No records yet.', style: TextStyle(color: mutedColor(c))),
                ]),
                const SizedBox(height: 12),
                for (final p in rows)
                  BizTile(
                    leading: Icons.payments_outlined,
                    title: _f == 'x402' ? '${p['amount']} ${p['asset']}' : '${money(p['amount'])}',
                    subtitle: [
                      shortDate(p['created_at']),
                      'business ${'${p['business_id'] ?? '-'}'.split('-').first}',
                      if (p['transaction'] != null) 'tx ${'${p['transaction']}'.substring(0, 8)}…',
                      if (p['failure_reason'] != null) '${p['failure_reason']}',
                      if (p['error'] != null) '${p['error']}',
                    ].join(' · '),
                    trailing: StatusChip('${p['status']}'),
                  ),
              ]),
            );
          },
        ),
      );
}
