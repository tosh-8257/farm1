import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_requests/business_ops_api.dart';
import '/pages/business/business_kyb_logic.dart';

/// Admin KYB review for Business accounts. Black/white/grey only.
class BusinessReviewPage extends StatefulWidget {
  const BusinessReviewPage({super.key, this.onGoBack});
  final VoidCallback? onGoBack;
  @override
  State<BusinessReviewPage> createState() => _BusinessReviewPageState();
}

const _filters = {
  'under_review': 'Under review',
  'more_information_required': 'More info',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'draft': 'Draft',
  'all': 'All',
};

class _BusinessReviewPageState extends State<BusinessReviewPage> {
  String _filter = 'under_review';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await BusinessOpsApi.adminBusinesses(status: _filter == 'all' ? null : _filter);
      if (mounted) setState(() => _items = BusinessOpsApi.list(r));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(children: [
            if (widget.onGoBack != null)
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: widget.onGoBack),
            const Expanded(
                child: Text('Business KYB',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black))),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _load),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
            for (final f in _filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.value),
                  selected: _filter == f.key,
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.black26),
                  labelStyle: TextStyle(color: _filter == f.key ? Colors.white : Colors.black),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _filter = f.key);
                    _load();
                  },
                ),
              ),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: Colors.black))),
        ]),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No businesses in this state.', style: TextStyle(color: Colors.black54)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final b = _items[i];
          final owner = (b['owner'] as Map?) ?? {};
          return InkWell(
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BusinessReviewDetail(id: '${b['id']}')));
              _load();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${b['legal_name'] ?? 'Unnamed business'}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                    const SizedBox(height: 4),
                    Text('@${owner['username'] ?? '—'} · ${b['registration_country'] ?? '—'} · submitted ${_d(b['submitted_at'])}',
                        style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  ]),
                ),
                _chip(statusLabel('${b['status']}')),
              ]),
            ),
          );
        },
      ),
    );
  }
}

String _d(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? '—' : d.toLocal().toString().substring(0, 16);
}

Widget _chip(String s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.black45)),
      child: Text(s, style: const TextStyle(fontSize: 12, color: Colors.black)),
    );

class _BusinessReviewDetail extends StatefulWidget {
  const _BusinessReviewDetail({required this.id});
  final String id;
  @override
  State<_BusinessReviewDetail> createState() => _DetailState();
}

class _DetailState extends State<_BusinessReviewDetail> {
  Map<String, dynamic>? _b;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = await BusinessOpsApi.adminBusiness(widget.id);
      if (mounted) setState(() => _b = b);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _decide(String decision) async {
    final labels = {'approve': 'Approve', 'request_info': 'Request more information', 'reject': 'Reject'};
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${labels[decision]}?'),
        content: TextField(
          controller: notes,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: decision == 'approve' ? 'Notes (optional)' : 'Reason shown to the applicant (required)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.black54))),
          TextButton(
            onPressed: () {
              if (decision != 'approve' && notes.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(labels[decision]!, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final text = notes.text.trim();
    notes.dispose();
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await BusinessOpsApi.adminReview(widget.id, decision, text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${labels[decision]} saved')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _kv(String k, dynamic v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 170, child: Text(k, style: const TextStyle(color: Colors.black54))),
          Expanded(child: SelectableText('${v ?? '—'}', style: const TextStyle(color: Colors.black))),
        ]),
      );

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.black12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final b = _b;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(b?['legal_name']?.toString() ?? 'Business'),
      ),
      body: _error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, style: const TextStyle(color: Colors.black54)),
              TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: Colors.black))),
            ]))
          : b == null
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : ListView(padding: const EdgeInsets.all(20), children: [
                  _section('Status', [
                    _kv('Status', statusLabel('${b['status']}')),
                    _kv('Submitted', _d(b['submitted_at'])),
                    _kv('Reviewed', _d(b['reviewed_at'])),
                    _kv('Review notes', b['review_notes']),
                    _kv('Merchant', (b['merchant'] as Map?)?['business_name']),
                    _kv('Merchant status', (b['merchant'] as Map?)?['status']),
                  ]),
                  _section('Didit KYB (advisory — approve manually)', [
                    for (final e in kybAdminSummary(
                      b['didit_kyb'] is Map ? Map<String, dynamic>.from(b['didit_kyb'] as Map) : null,
                    ).entries)
                      _kv(e.key, e.value),
                  ]),
                  _section('Business', [
                    for (final k in const [
                      'legal_name', 'trading_name', 'registration_number', 'registration_country', 'incorporation_date',
                      'business_type', 'sector', 'tax_id', 'country', 'city', 'address', 'postal_code',
                      'business_email', 'business_phone', 'website', 'description',
                    ])
                      _kv(statusLabel(k), b[k]),
                  ]),
                  _section('Owner', [
                    for (final e in ((b['owner'] as Map?) ?? {}).entries) _kv(statusLabel('${e.key}'), e.value),
                  ]),
                  _section('People', [
                    for (final p in ((b['persons'] as List?) ?? const []).whereType<Map>())
                      _kv(statusLabel('${p['role']}'),
                          '${p['full_name']}${p['ownership_percent'] != null ? ' · ${p['ownership_percent']}%' : ''}${p['nationality'] != null ? ' · ${p['nationality']}' : ''}'),
                  ]),
                  _section('Documents', [
                    for (final d in ((b['documents'] as List?) ?? const []).whereType<Map>())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            '${d['file_url']}'.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                            color: Colors.black),
                        title: Text(statusLabel('${d['doc_type']}'), style: const TextStyle(color: Colors.black)),
                        subtitle: Text('${d['file_name'] ?? ''}', style: const TextStyle(color: Colors.black54)),
                        trailing: const Icon(Icons.open_in_new, color: Colors.black54),
                        onTap: () {
                          final u = Uri.tryParse('${d['file_url']}');
                          if (u != null && u.scheme == 'https') launchUrl(u, mode: LaunchMode.externalApplication);
                        },
                      ),
                  ]),
                  if (b['status'] == 'under_review') ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent, foregroundColor: AppTheme.onAccent, minimumSize: const Size.fromHeight(50)),
                      onPressed: _busy ? null : () => _decide('approve'),
                      child: const Text('Approve'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
                      onPressed: _busy ? null : () => _decide('request_info'),
                      child: const Text('Request more information'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.black, minimumSize: const Size.fromHeight(50)),
                      onPressed: _busy ? null : () => _decide('reject'),
                      child: const Text('Reject'),
                    ),
                  ] else
                    const Text('Decisions are only possible while the application is under review.',
                        style: TextStyle(color: Colors.black54)),
                ]),
    );
  }
}
