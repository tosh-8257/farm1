import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_requests/investments_api.dart';
import '/pages/business/ops/ops_ui.dart';

String _label(Map<String, String> m, dynamic k) => m['$k'] ?? '${k ?? '—'}';

/// Multi-sector marketplace body (used by the existing marketplace page).
class MarketplaceBody extends StatefulWidget {
  const MarketplaceBody({super.key});
  @override
  State<MarketplaceBody> createState() => _MarketplaceBodyState();
}

class _MarketplaceBodyState extends State<MarketplaceBody> {
  String _sector = 'all';
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            for (final s in ['all', ...sectorLabels.keys])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s == 'all' ? 'All' : sectorLabels[s]!),
                  selected: _sector == s,
                  selectedColor: fgColor(context),
                  labelStyle: TextStyle(
                      color: _sector == s ? Theme.of(context).scaffoldBackgroundColor : fgColor(context)),
                  onSelected: (_) {
                    setState(() => _sector = s);
                    _key.currentState?.reload();
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: () => InvestmentsApi.projects(sector: _sector == 'all' ? null : _sector),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.storefront_outlined,
          emptyTitle: 'No projects listed yet',
          emptyMessage: 'Projects appear here after FARM has reviewed and listed them.',
          builder: (c, list, reload) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _RiskBanner(),
              const SizedBox(height: 12),
              for (final p in list) ProjectCard(p, onTap: () => pushPage(c, ProjectDetailPage(id: '${p['id']}'))),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner();
  @override
  Widget build(BuildContext context) => BizCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.info_outline, color: fgColor(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Investing is risky. You can lose money and returns are never guaranteed.',
                style: TextStyle(fontSize: 13, color: mutedColor(context))),
          ),
        ]),
      );
}

class ProjectCard extends StatelessWidget {
  const ProjectCard(this.p, {super.key, this.onTap});
  final Map<String, dynamic> p;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final progress = ((p['funding_progress'] as num?) ?? 0).toDouble().clamp(0, 100) / 100;
    final img = '${p['banner_image'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: BizCard(
          padding: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (img.startsWith('https://'))
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, //
                    0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0,
                  ]),
                  child: Image.network(img, height: 140, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusChip(_label(sectorLabels, p['sector'])),
                  const SizedBox(width: 8),
                  if (p['instrument_type'] != null) StatusChip(_label(instrumentLabels, p['instrument_type'])),
                  const Spacer(),
                  if (p['status'] != 'listed') StatusChip(_label(projectStatusLabels, p['status']), filled: true),
                ]),
                const SizedBox(height: 10),
                Text('${p['project_name'] ?? 'Untitled'}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fgColor(context))),
                if (p['business_name'] != null)
                  Text('by ${p['business_name']}', style: TextStyle(color: mutedColor(context))),
                if ((p['summary'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${p['summary']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedColor(context))),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 6,
                    color: fgColor(context),
                    backgroundColor: borderColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${money(p['raised_amount'])} of ${money(p['target_amount'])}'
                    '${p['minimum_investment'] != null ? ' · min ${money(p['minimum_investment'])}' : ''}',
                    style: TextStyle(fontSize: 13, color: mutedColor(context))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> openDoc(BuildContext c, String url) async {
  final u = Uri.tryParse(url);
  if (u == null || u.scheme != 'https') return bizSnack(c, 'This document link is not available');
  await launchUrl(u, mode: LaunchMode.externalApplication);
}

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Project',
        body: BizAsync<Map<String, dynamic>>(
          load: () => InvestmentsApi.project(id),
          builder: (c, p, reload) {
            final docs = ((p['documents'] as List?) ?? const []).whereType<Map>().toList();
            final updates = ((p['updates'] as List?) ?? const []).whereType<Map>().toList();
            Widget section(String t, dynamic v) => (v ?? '').toString().trim().isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                      const SizedBox(height: 6),
                      Text('$v', style: TextStyle(color: fgColor(c), height: 1.4)),
                    ]),
                  );
            return ListView(padding: const EdgeInsets.all(16), children: [
              ProjectCard(p),
              BizCard(
                child: Column(children: [
                  KeyValue('Sector', _label(sectorLabels, p['sector'])),
                  KeyValue('Instrument', _label(instrumentLabels, p['instrument_type'])),
                  KeyValue('Location', [p['location'], p['country']].where((e) => e != null).join(', ')),
                  KeyValue('Duration', p['duration_months'] != null ? '${p['duration_months']} months' : '—'),
                  KeyValue('Minimum', money(p['minimum_investment'])),
                  if (p['maximum_investment'] != null) KeyValue('Maximum per investor', money(p['maximum_investment'])),
                  KeyValue('Backers', '${p['total_backers'] ?? 0}'),
                  if (p['ends_at'] != null) KeyValue('Closes', shortDate(p['ends_at'])),
                ]),
              ),
              section('About', p['description']),
              section('Use of funds', p['use_of_funds']),
              section('Risks', p['risk_factors']),
              section('Team', p['team']),
              MilestoneList(p),
              if (docs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                const SizedBox(height: 8),
                for (final d in docs)
                  BizTile(
                    leading: Icons.description_outlined,
                    title: '${d['title']}',
                    subtitle: _label(documentKindLabels, d['kind']),
                    onTap: () => openDoc(c, '${d['url']}'),
                  ),
              ],
              if (updates.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Updates', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                const SizedBox(height: 8),
                for (final u in updates) BizTile(title: '${u['title']}', subtitle: '${shortDate(u['created_at'])} · ${u['body']}'),
              ],
              const SizedBox(height: 20),
              if (p['investable'] == true)
                ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () async {
                    final ok = await startInvest(c, p);
                    if (ok == true) reload();
                  },
                  child: const Text('Invest'),
                )
              else
                Text('This project is not open for new investment.', textAlign: TextAlign.center,
                    style: TextStyle(color: mutedColor(c))),
              const SizedBox(height: 24),
            ]);
          },
        ),
      );
}

/// Eligibility check -> risk disclosure -> amount -> PIN. Returns true if invested.
Future<bool?> startInvest(BuildContext c, Map<String, dynamic> p) async {
  final el = await runBusy(c, InvestmentsApi.eligibility);
  if (el == null || !c.mounted) return null;
  if (el['eligible'] != true) {
    await confirmAction(c,
        title: 'Not eligible yet',
        message: '${el['reason'] ?? 'Complete identity verification (KYC) to invest.'}',
        confirm: 'OK');
    return null;
  }
  final disc = (p['disclosure'] as Map?) ?? const {};
  final amount = await showModalBottomSheet<double>(
    context: c,
    isScrollControlled: true,
    builder: (_) => _InvestSheet(project: p, points: ((disc['points'] as List?) ?? const []).map((e) => '$e').toList()),
  );
  if (amount == null || !c.mounted) return null;
  final pin = await confirmWithPin(c,
      title: 'Confirm investment',
      message: 'Invest ${money(amount)} in ${p['project_name']}? You could lose this money.');
  if (pin == null || !c.mounted) return null;
  final r = await runBusy(c,
      () => InvestmentsApi.invest('${p['id']}', amount: amount, pin: pin, disclosureVersion: '${disc['version']}'),
      success: 'Investment recorded');
  return r != null;
}

class _InvestSheet extends StatefulWidget {
  const _InvestSheet({required this.project, required this.points});
  final Map<String, dynamic> project;
  final List<String> points;
  @override
  State<_InvestSheet> createState() => _InvestSheetState();
}

class _InvestSheetState extends State<_InvestSheet> {
  final _amount = TextEditingController();
  bool _accepted = false;
  String? _err;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _go() {
    final v = double.tryParse(_amount.text.trim());
    final min = (widget.project['minimum_investment'] as num?)?.toDouble() ?? 0;
    if (v == null || v <= 0) return setState(() => _err = 'Enter an amount');
    if (v < min) return setState(() => _err = 'Minimum is ${money(min)}');
    if (!_accepted) return setState(() => _err = 'Please accept the risk disclosure');
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Risk disclosure', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(context))),
              const SizedBox(height: 10),
              for (final pt in widget.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('•  $pt', style: TextStyle(color: fgColor(context), height: 1.35)),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _accepted,
                activeColor: fgColor(context),
                onChanged: (v) => setState(() => _accepted = v ?? false),
                title: Text('I have read and understand these risks',
                    style: TextStyle(color: fgColor(context))),
              ),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: bizInput(context, 'Amount (FARM)',
                    hint: 'Minimum ${money(widget.project['minimum_investment'])}'),
              ),
              if (_err != null) ...[
                const SizedBox(height: 8),
                Text(_err!, style: TextStyle(color: fgColor(context), fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(style: primaryButtonStyle(context), onPressed: _go, child: const Text('Continue')),
            ]),
          ),
        ),
      );
}

/// Investor portfolio: holdings, history, documents and updates.
class PortfolioPage extends StatelessWidget {
  const PortfolioPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: BizScaffold(
          title: 'My investments',
          body: Column(children: [
            TabBar(
              isScrollable: true,
              labelColor: fgColor(context),
              unselectedLabelColor: mutedColor(context),
              indicatorColor: fgColor(context),
              tabs: const [Tab(text: 'Holdings'), Tab(text: 'History'), Tab(text: 'Documents'), Tab(text: 'Updates')],
            ),
            Expanded(
              child: TabBarView(children: [
                BizAsync<Map<String, dynamic>>(
                  load: InvestmentsApi.portfolio,
                  isEmpty: (d) => ((d['holdings'] as List?) ?? const []).isEmpty && ((d['legacy_records'] as List?) ?? const []).isEmpty,
                  emptyIcon: Icons.pie_chart_outline,
                  emptyTitle: 'No investments yet',
                  emptyMessage: 'Projects you invest in will show here.',
                  builder: (c, d, _) => ListView(padding: const EdgeInsets.all(16), children: [
                    BizCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Total invested', style: TextStyle(color: mutedColor(c))),
                        Text(money(d['total_invested']),
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fgColor(c))),
                        Text('Amount you put in. This is not a valuation or a promised return.',
                            style: TextStyle(fontSize: 12, color: mutedColor(c))),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    for (final h in ((d['holdings'] as List?) ?? const []).whereType<Map>())
                      BizTile(
                        title: '${(h['project'] as Map?)?['project_name'] ?? 'Project'}',
                        subtitle: '${money(h['invested'])} · ${_label(projectStatusLabels, h['status'])}',
                        trailing: StatusChip(_label(projectStatusLabels, (h['project'] as Map?)?['status'])),
                        onTap: () => pushPage(c, ProjectDetailPage(id: '${(h['project'] as Map?)?['id']}')),
                      ),
                    for (final l in ((d['legacy_records'] as List?) ?? const []).whereType<Map>())
                      BizTile(
                        title: '${(l['project'] as Map?)?['title'] ?? 'Earlier project'}',
                        subtitle: '${money(l['amount'])} · recorded in the earlier system',
                      ),
                  ]),
                ),
                BizAsync<List<Map<String, dynamic>>>(
                  load: InvestmentsApi.history,
                  isEmpty: (l) => l.isEmpty,
                  emptyIcon: Icons.history,
                  emptyTitle: 'No history yet',
                  builder: (c, l, _) => ListView(padding: const EdgeInsets.all(16), children: [
                    for (final r in l)
                      BizTile(
                        title: '${(r['investment_projects'] as Map?)?['project_name'] ?? 'Project'}',
                        subtitle: '${shortDate(r['invested_at'])} · ${_label(projectStatusLabels, r['status'])}',
                        trailing: Text(money(r['amount']), style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
                BizAsync<List<Map<String, dynamic>>>(
                  load: InvestmentsApi.documents,
                  isEmpty: (l) => l.isEmpty,
                  emptyIcon: Icons.folder_open,
                  emptyTitle: 'No documents yet',
                  builder: (c, l, _) => ListView(padding: const EdgeInsets.all(16), children: [
                    for (final d in l)
                      BizTile(
                        leading: Icons.description_outlined,
                        title: '${d['title']}',
                        subtitle: '${(d['project'] as Map?)?['project_name'] ?? ''} · ${_label(documentKindLabels, d['kind'])}',
                        onTap: () => openDoc(c, '${d['url']}'),
                      ),
                  ]),
                ),
                BizAsync<List<Map<String, dynamic>>>(
                  load: InvestmentsApi.updates,
                  isEmpty: (l) => l.isEmpty,
                  emptyIcon: Icons.campaign_outlined,
                  emptyTitle: 'No updates yet',
                  builder: (c, l, _) => ListView(padding: const EdgeInsets.all(16), children: [
                    for (final u in l)
                      BizTile(
                        title: '${u['title']}',
                        subtitle: '${(u['project'] as Map?)?['project_name'] ?? ''} · ${shortDate(u['created_at'])}\n${u['body']}',
                      ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}


/// Read-only milestone plan. Funds are released by FARM one milestone at a time.
class MilestoneList extends StatelessWidget {
  const MilestoneList(this.p, {super.key, this.trailing});
  final Map<String, dynamic> p;
  final Widget? Function(Map m)? trailing;
  @override
  Widget build(BuildContext c) {
    final ms = ((p['milestones'] as List?) ?? const []).whereType<Map>().toList();
    if (ms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Milestones', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
        const SizedBox(height: 4),
        Text('Released to the business: ${money(p['released_amount'] ?? 0)}. Funds are released in stages as milestones are approved by FARM.',
            style: TextStyle(fontSize: 12, color: mutedColor(c))),
        const SizedBox(height: 8),
        for (final m in ms)
          BizTile(
            title: '${m['position']}. ${m['title']}',
            subtitle: '${money(m['amount'])}'
                '${m['released_amount'] != null ? ' · released ${money(m['released_amount'])}' : ''}'
                '${(m['release_notes'] ?? '').toString().isNotEmpty ? ' · ${m['release_notes']}' : ''}',
            trailing: trailing?.call(m) ??
                StatusChip(milestoneStatusLabels['${m['status']}'] ?? '${m['status']}', filled: m['status'] == 'released'),
          ),
      ]),
    );
  }
}
