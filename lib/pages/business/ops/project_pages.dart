import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '/backend/api_requests/investments_api.dart';
import '/backend/services/api_service.dart';
import '/pages/investments/investment_pages.dart' show openDoc, MilestoneList;
import 'ops_ui.dart';

String _lbl(Map<String, String> m, dynamic k) => m['$k'] ?? '${k ?? '—'}';

class BusinessProjectsPage extends StatefulWidget {
  const BusinessProjectsPage({super.key});
  @override
  State<BusinessProjectsPage> createState() => _BusinessProjectsPageState();
}

class _BusinessProjectsPageState extends State<BusinessProjectsPage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();
  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Investment projects',
        fab: BizFab(
          label: 'New project',
          onPressed: () async {
            await pushPage(context, const ProjectEditorPage());
            _key.currentState?.reload();
          },
        ),
        body: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: InvestmentsApi.myProjects,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.account_tree_outlined,
          emptyTitle: 'No projects yet',
          emptyMessage: 'Create a project, add documents and submit it for FARM review. Approved projects can be listed for investors.',
          builder: (c, l, reload) => ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
            for (final p in l)
              BizTile(
                title: '${p['project_name']}',
                subtitle: '${_lbl(sectorLabels, p['sector'])} · ${money(p['raised_amount'])} of ${money(p['target_amount'])}',
                trailing: StatusChip(_lbl(projectStatusLabels, p['status']), filled: p['status'] == 'listed'),
                onTap: () async {
                  await pushPage(c, BusinessProjectDetailPage(id: '${p['id']}'));
                  reload();
                },
              ),
          ]),
        ),
      );
}

/// Multi-step create / edit form. Server validates everything again.
class ProjectEditorPage extends StatefulWidget {
  const ProjectEditorPage({super.key, this.existing});
  final Map<String, dynamic>? existing;
  @override
  State<ProjectEditorPage> createState() => _ProjectEditorPageState();
}

class _ProjectEditorPageState extends State<ProjectEditorPage> {
  int _step = 0;
  late final Map<String, TextEditingController> _t;
  String _sector = 'agriculture';
  String _instrument = 'equity';
  static const _fields = [
    'project_name', 'summary', 'location', 'country', 'banner_image', 'description', 'target_amount',
    'minimum_investment', 'maximum_investment', 'duration_months', 'use_of_funds', 'risk_factors', 'team',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const {};
    _t = {for (final f in _fields) f: TextEditingController(text: e[f] == null ? '' : '${e[f]}')};
    _sector = '${e['sector'] ?? 'agriculture'}';
    if (!sectorLabels.containsKey(_sector)) _sector = 'other';
    _instrument = '${e['instrument_type'] ?? 'equity'}';
    if (!instrumentLabels.containsKey(_instrument)) _instrument = 'other';
  }

  @override
  void dispose() {
    for (final c in _t.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _body() {
    String? s(String k) => _t[k]!.text.trim().isEmpty ? null : _t[k]!.text.trim();
    num? n(String k) => num.tryParse(_t[k]!.text.trim());
    return {
      'project_name': s('project_name'),
      'sector': _sector,
      'instrument_type': _instrument,
      if (s('summary') != null) 'summary': s('summary'),
      if (s('location') != null) 'location': s('location'),
      if (s('country') != null) 'country': s('country')!.toUpperCase(),
      if (s('banner_image') != null) 'banner_image': s('banner_image'),
      if (s('description') != null) 'description': s('description'),
      if (n('target_amount') != null) 'target_amount': n('target_amount'),
      if (n('minimum_investment') != null) 'minimum_investment': n('minimum_investment'),
      'maximum_investment': n('maximum_investment'),
      if (n('duration_months') != null) 'duration_months': n('duration_months')!.toInt(),
      if (s('use_of_funds') != null) 'use_of_funds': s('use_of_funds'),
      if (s('risk_factors') != null) 'risk_factors': s('risk_factors'),
      if (s('team') != null) 'team': s('team'),
    };
  }

  Future<void> _save() async {
    final b = _body();
    if (b['project_name'] == null || (b['project_name'] as String).length < 3) {
      setState(() => _step = 0);
      return bizSnack(context, 'Add a project name');
    }
    if (b['target_amount'] == null) {
      setState(() => _step = 1);
      return bizSnack(context, 'Add a funding target');
    }
    final id = widget.existing?['id'];
    final r = await runBusy(
        context, () => id == null ? InvestmentsApi.createProject(b) : InvestmentsApi.updateProject('$id', b),
        success: 'Saved as draft');
    if (r != null && mounted) {
      if (id == null) {
        Navigator.pop(context);
        pushPage(context, BusinessProjectDetailPage(id: '${r['id']}'));
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  Widget _tf(String k, String label, {int lines = 1, bool number = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _t[k],
          minLines: lines,
          maxLines: lines == 1 ? 1 : 12,
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
          decoration: bizInput(context, label, hint: hint),
        ),
      );

  Widget _drop(String label, String value, Map<String, String> items, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: bizInput(context, label),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => on(v!)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final steps = [
      Step(
        title: const Text('Basics'),
        isActive: _step >= 0,
        content: Column(children: [
          _tf('project_name', 'Project name'),
          _drop('Sector', _sector, sectorLabels, (v) => _sector = v),
          _tf('summary', 'One-line summary', lines: 2),
          _tf('location', 'Location', hint: 'Town, county'),
          _tf('country', 'Country code', hint: 'KE'),
          _tf('banner_image', 'Cover image link (https)'),
        ]),
      ),
      Step(
        title: const Text('Funding'),
        isActive: _step >= 1,
        content: Column(children: [
          _drop('Instrument', _instrument, instrumentLabels, (v) => _instrument = v),
          _tf('target_amount', 'Funding target (FARM)', number: true),
          _tf('minimum_investment', 'Minimum per investor (FARM)', number: true),
          _tf('maximum_investment', 'Maximum per investor (optional)', number: true),
          _tf('duration_months', 'Duration (months)', number: true),
          Text('Do not promise returns. FARM does not display or guarantee returns.',
              style: TextStyle(fontSize: 12, color: mutedColor(context))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.token_rounded, size: 16, color: Color(0xFFD4AF37)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Tokenize: after saving, open the project and tap "Tokenize project" before it is listed. '
                  'Supply = funding target; investors get 1 token per FARM as they invest, once FARM approves.',
                  style: TextStyle(fontSize: 12, color: mutedColor(context))),
            ),
          ]),
        ]),
      ),
      Step(
        title: const Text('Details'),
        isActive: _step >= 2,
        content: Column(children: [
          _tf('description', 'Description', lines: 4),
          _tf('use_of_funds', 'Use of funds', lines: 3),
          _tf('risk_factors', 'Key risks', lines: 3),
          _tf('team', 'Team (optional)', lines: 3),
        ]),
      ),
    ];
    return BizScaffold(
      title: widget.existing == null ? 'New project' : 'Edit project',
      body: Stepper(
        currentStep: _step,
        steps: steps,
        onStepTapped: (i) => setState(() => _step = i),
        onStepContinue: () => _step < steps.length - 1 ? setState(() => _step++) : _save(),
        onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
        controlsBuilder: (c, d) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            ElevatedButton(
                style: primaryButtonStyle(c),
                onPressed: d.onStepContinue,
                child: Text(_step == steps.length - 1 ? 'Save draft' : 'Next')),
            const SizedBox(width: 10),
            if (_step > 0) OutlinedButton(style: secondaryButtonStyle(c), onPressed: d.onStepCancel, child: const Text('Back')),
          ]),
        ),
      ),
    );
  }
}

class BusinessProjectDetailPage extends StatefulWidget {
  const BusinessProjectDetailPage({super.key, required this.id});
  final String id;
  @override
  State<BusinessProjectDetailPage> createState() => _BusinessProjectDetailPageState();
}

class _BusinessProjectDetailPageState extends State<BusinessProjectDetailPage> {
  final _key = GlobalKey<BizAsyncState<Map<String, dynamic>>>();
  Future<void> _reload() async => _key.currentState?.reload();

  Future<void> _addDoc(Map<String, dynamic> p) async {
    final kind = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('Document type'), children: [
        for (final e in documentKindLabels.entries)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
      ]),
    );
    if (kind == null || !mounted) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file?.bytes == null || !mounted) return;
    final r = await runBusy(context, () async {
      final url = await ApiService.uploadDocument(bytes: file!.bytes!, filename: file.name);
      return InvestmentsApi.addDocument(widget.id, kind: kind, title: file.name, url: url);
    }, success: 'Document added');
    if (r != null) _reload();
  }

  Future<void> _postUpdate() async {
    final t = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post update to investors'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: bizInput(ctx, 'Title')),
          const SizedBox(height: 10),
          TextField(controller: b, minLines: 3, maxLines: 8, decoration: bizInput(ctx, 'Update')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
        ],
      ),
    );
    final title = t.text.trim(), body = b.text.trim();
    t.dispose();
    b.dispose();
    if (ok != true || title.isEmpty || body.isEmpty || !mounted) return;
    final r = await runBusy(context, () => InvestmentsApi.postUpdate(widget.id, title, body), success: 'Update posted');
    if (r != null) _reload();
  }

  Future<void> _requestRelease(Map m) async {
    final ev = TextEditingController();
    final url = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request release: ${m['title']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ev, minLines: 3, maxLines: 8, decoration: bizInput(ctx, 'What was completed?')),
          const SizedBox(height: 10),
          TextField(controller: url, decoration: bizInput(ctx, 'Evidence link (https, optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
        ],
      ),
    );
    final e = ev.text.trim(), u = url.text.trim();
    ev.dispose();
    url.dispose();
    if (ok != true || e.isEmpty || !mounted) return;
    final r = await runBusy(context,
        () => InvestmentsApi.requestMilestone(widget.id, '${m['id']}', evidence: e, evidenceUrl: u),
        success: 'Release requested. FARM will review it.');
    if (r != null) _reload();
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Project',
        body: BizAsync<Map<String, dynamic>>(
          key: _key,
          load: () => InvestmentsApi.myProject(widget.id),
          builder: (c, p, reload) {
            final status = '${p['status']}';
            final editable = status == 'draft' || status == 'more_info_required';
            final docs = ((p['documents'] as List?) ?? const []).whereType<Map>().toList();
            final have = docs.map((d) => '${d['kind']}').toSet();
            final required = ((p['required_documents'] as List?) ?? const []).map((e) => '$e').toList();
            final reviews = ((p['reviews'] as List?) ?? const []).whereType<Map>().toList();
            final summary = ((p['investment_summary'] as List?) ?? const []).whereType<Map>().toList();
            final canUpdate = ['listed', 'funded', 'closed'].contains(status);
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('${p['project_name']}',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(_lbl(projectStatusLabels, status), filled: true),
                  ]),
                  const SizedBox(height: 10),
                  KeyValue('Sector', _lbl(sectorLabels, p['sector'])),
                  KeyValue('Instrument', _lbl(instrumentLabels, p['instrument_type'])),
                  KeyValue('Target', money(p['target_amount'])),
                  KeyValue('Raised', money(p['raised_amount'])),
                  KeyValue('Minimum', money(p['minimum_investment'])),
                  for (final s in summary)
                    KeyValue(_lbl(projectStatusLabels, s['status']), '${s['count']} · ${money(s['amount'])}'),
                ]),
              ),
              if ((p['review_notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                BizCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notes from FARM review', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                    const SizedBox(height: 6),
                    Text('${p['review_notes']}', style: TextStyle(color: fgColor(c))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                if (!['rejected', 'closed', 'cancelled'].contains(status))
                  TextButton.icon(
                    onPressed: () => _addDoc(p),
                    icon: Icon(Icons.upload_file, color: fgColor(c)),
                    label: Text('Add', style: TextStyle(color: fgColor(c))),
                  ),
              ]),
              for (final k in required.where((k) => !have.contains(k)))
                Text('Required: ${_lbl(documentKindLabels, k)}', style: TextStyle(color: mutedColor(c))),
              for (final d in docs)
                BizTile(
                  leading: Icons.description_outlined,
                  title: '${d['title']}',
                  subtitle: '${_lbl(documentKindLabels, d['kind'])} · visible to ${d['visibility']}',
                  onTap: () => openDoc(c, '${d['url']}'),
                  trailing: editable
                      ? IconButton(
                          icon: Icon(Icons.delete_outline, color: mutedColor(c)),
                          onPressed: () async {
                            final r = await runBusy(c, () async {
                              await InvestmentsApi.removeDocument(widget.id, '${d['id']}');
                              return true;
                            });
                            if (r == true) reload();
                          })
                      : null,
                ),
              MilestoneList(p, trailing: (m) {
                if (!['funded', 'closed'].contains(status)) return null;
                if (!['planned', 'returned'].contains('${m['status']}')) return null;
                return TextButton(
                    onPressed: () => _requestRelease(m),
                    child: Text('Request', style: TextStyle(color: fgColor(c))));
              }),
              if (editable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final r = await pushPage<bool>(c, MilestoneEditorPage(project: p));
                      if (r == true) reload();
                    },
                    icon: Icon(Icons.flag_outlined, color: fgColor(c)),
                    label: Text(((p['milestones'] as List?) ?? const []).isEmpty ? 'Set milestones (required)' : 'Edit milestones',
                        style: TextStyle(color: fgColor(c))),
                  ),
                ),
              const SizedBox(height: 16),
              if (editable) ...[
                OutlinedButton(
                  style: secondaryButtonStyle(c),
                  onPressed: () async {
                    final r = await pushPage<bool>(c, ProjectEditorPage(existing: p));
                    if (r == true) reload();
                  },
                  child: const Text('Edit details'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: primaryButtonStyle(c),
                  onPressed: () async {
                    final ok = await confirmAction(c,
                        title: 'Submit for review?',
                        message: 'FARM will review this project. You cannot edit it while it is under review.',
                        confirm: 'Submit');
                    if (!ok || !c.mounted) return;
                    final r = await runBusy(c, () => InvestmentsApi.submitProject(widget.id), success: 'Submitted for review');
                    if (r != null) reload();
                  },
                  child: const Text('Submit for review'),
                ),
              ],
              if (!['rejected', 'cancelled'].contains(status)) TokenizationCard(projectId: widget.id, projectStatus: status, targetAmount: p['target_amount']),
              if (canUpdate)
                ElevatedButton(style: primaryButtonStyle(c), onPressed: _postUpdate, child: const Text('Post update to investors')),
              if (reviews.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Review history', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                const SizedBox(height: 8),
                for (final r in reviews)
                  BizTile(
                    title: _lbl(projectStatusLabels, r['to_status']),
                    subtitle: '${shortDate(r['created_at'])}${r['notes'] != null ? ' · ${r['notes']}' : ''}',
                  ),
              ],
              const SizedBox(height: 24),
            ]);
          },
        ),
      );
}


/// Define how raised funds are released. Amounts must add up to the target.
class MilestoneEditorPage extends StatefulWidget {
  const MilestoneEditorPage({super.key, required this.project});
  final Map<String, dynamic> project;
  @override
  State<MilestoneEditorPage> createState() => _MilestoneEditorPageState();
}

class _MilestoneEditorPageState extends State<MilestoneEditorPage> {
  final _form = GlobalKey<FormState>();
  final List<(TextEditingController, TextEditingController)> _rows = [];

  @override
  void initState() {
    super.initState();
    final ms = ((widget.project['milestones'] as List?) ?? const []).whereType<Map>();
    for (final m in ms) {
      _rows.add((TextEditingController(text: '${m['title']}'), TextEditingController(text: '${m['amount']}')));
    }
    if (_rows.isEmpty) _add();
  }

  void _add() => setState(() => _rows.add((TextEditingController(), TextEditingController())));

  @override
  void dispose() {
    for (final r in _rows) {
      r.$1.dispose();
      r.$2.dispose();
    }
    super.dispose();
  }

  double get _sum => _rows.fold(0, (t, r) => t + (double.tryParse(r.$2.text) ?? 0));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final r = await runBusy(
        context,
        () => InvestmentsApi.setMilestones('${widget.project['id']}', [
              for (final r in _rows) {'title': r.$1.text.trim(), 'amount': double.parse(r.$2.text)},
            ]),
        success: 'Milestones saved');
    if (r != null && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final target = (widget.project['target_amount'] as num?)?.toDouble() ??
        double.tryParse('${widget.project['target_amount']}') ?? 0;
    return BizScaffold(
      title: 'Milestones',
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Raised funds are released to you in stages. FARM releases each milestone after you request it with evidence.',
              style: TextStyle(color: mutedColor(context))),
          const SizedBox(height: 16),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _rows[i].$1,
                    decoration: bizInput(context, 'Milestone ${i + 1}'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _rows[i].$2,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: bizInput(context, 'Amount'),
                    validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0 ? null : '> 0',
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    icon: Icon(Icons.close, color: mutedColor(context)),
                    onPressed: () => setState(() {
                      final r = _rows.removeAt(i);
                      r.$1.dispose();
                      r.$2.dispose();
                    }),
                  ),
              ]),
            ),
          if (_rows.length < 12)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _add,
                icon: Icon(Icons.add, color: fgColor(context)),
                label: Text('Add milestone', style: TextStyle(color: fgColor(context))),
              ),
            ),
          const SizedBox(height: 8),
          KeyValue('Total', money(_sum)),
          KeyValue('Target', money(target)),
          if ((_sum - target).abs() > 0.005)
            Text('Milestone amounts must add up to the target before you submit.',
                style: TextStyle(fontSize: 12, color: mutedColor(context))),
          const SizedBox(height: 20),
          ElevatedButton(style: primaryButtonStyle(context), onPressed: _save, child: const Text('Save milestones')),
        ]),
      ),
    );
  }
}


/// Request tokenization of a funded project. FARM approves and creates the ASA.
class TokenizationCard extends StatefulWidget {
  const TokenizationCard({super.key, required this.projectId, this.projectStatus = 'funded', this.targetAmount});
  final String projectId;
  final String projectStatus;
  final dynamic targetAmount;
  @override
  State<TokenizationCard> createState() => _TokenizationCardState();
}

const _preListing = ['draft', 'more_info_required', 'submitted', 'approved'];

class _TokenizationCardState extends State<TokenizationCard> {
  final _key = GlobalKey<BizAsyncState<Map<String, dynamic>>>();

  bool get funded => ['funded', 'closed'].contains(widget.projectStatus);
  bool get preListing => _preListing.contains(widget.projectStatus);

  Future<void> _request({required bool onInvest}) async {
    final n = TextEditingController();
    final u = TextEditingController();
    var agreed = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Tokenize project'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: n, maxLength: 32, decoration: bizInput(ctx, 'Token name (e.g. Solar Farm Shares)')),
            TextField(
                controller: u,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                decoration: bizInput(ctx, 'Symbol, 1-8 letters/digits (e.g. SOLAR)')),
            KeyValue('Price per token', '1 FARM'),
            KeyValue('Total supply',
                onInvest ? '${widget.targetAmount ?? 'Funding target'} (= funding target)' : '1 token per FARM invested'),
            const SizedBox(height: 6),
            Text(
                onInvest
                    ? 'FARM creates the token when it approves and lists the project. Each investor then gets 1 token per FARM as they invest.'
                    : 'Supply is counted from investments when FARM approves. Nothing is minted until approved.',
                style: TextStyle(fontSize: 12, color: mutedColor(ctx))),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: agreed,
              onChanged: (v) => setD(() => agreed = v == true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I agree to the 15% buyback commitment', style: TextStyle(fontSize: 13)),
              subtitle: Text(
                  'FARM holds back 15% of what this project raises as a buyback fund. Each investor can sell back up to 15% of their own investment at 1 FARM per token. Investors only pay the 3% investment fee.',
                  style: TextStyle(fontSize: 11, color: mutedColor(ctx))),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: agreed ? () => Navigator.pop(ctx, true) : null, child: const Text('Request')),
        ],
      )),
    );
    final name = n.text.trim(), unit = u.text.trim();
    n.dispose();
    u.dispose();
    if (ok != true || name.isEmpty || unit.isEmpty || !mounted) return;
    final r = await runBusy(
        context, () => InvestmentsApi.requestToken(widget.projectId, name, unit, mode: onInvest ? 'on_invest' : null),
        success: 'Requested. FARM will review it.');
    if (r != null) _key.currentState?.reload();
  }

  Widget _progress(BuildContext c, Map<String, dynamic> t, Map p) {
    int n(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;
    final total = n(p['total_units']);
    final alloc = n(p['allocated_units']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total > 0 ? (alloc / total).clamp(0, 1).toDouble() : 0,
          minHeight: 6,
          color: const Color(0xFFD4AF37),
          backgroundColor: mutedColor(c).withValues(alpha: 0.2),
        ),
      ),
      const SizedBox(height: 6),
      KeyValue('Sold', '$alloc of $total ${t['unit_name']}'),
      KeyValue('Delivered · Owed', '${p['delivered_units']} · ${p['owed_units']}'),
      if (t['unsold_units'] != null) KeyValue('Unsold (kept by issuer)', '${t['unsold_units']}'),
    ]);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BizCard(
          child: SizedBox(
            height: preListing ? 170 : 300,
            child: BizAsync<Map<String, dynamic>>(
              key: _key,
              load: () => InvestmentsApi.projectToken(widget.projectId),
              builder: (c, r, _) {
                final t = r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : null;
                final onInvestOn = r['on_invest_enabled'] == true;
                final canOnInvest = preListing && onInvestOn;
                final canPost = funded && r['enabled'] == true;
                final none = t == null || t['status'] == 'rejected';
                final p = r['progress'] is Map ? r['progress'] as Map : null;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tokenization (Algorand TestNet)', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
                  const SizedBox(height: 6),
                  if (none) ...[
                    Text(
                        t?['notes'] != null && (canOnInvest || canPost)
                            ? 'Previous request rejected: ${t!['notes']}'
                            : canOnInvest
                                ? 'Tokenize now: investors get 1 token per FARM as they invest.'
                                : canPost
                                    ? 'Turn investor holdings into an Algorand token.'
                                    : preListing || funded
                                        ? 'Tokenization is not switched on yet.'
                                        : 'Tokenization must be requested before listing (or after funding).',
                        style: TextStyle(color: mutedColor(c))),
                    const Spacer(),
                    OutlinedButton.icon(
                        style: secondaryButtonStyle(c),
                        onPressed: canOnInvest
                            ? () => _request(onInvest: true)
                            : canPost
                                ? () => _request(onInvest: false)
                                : null,
                        icon: const Icon(Icons.token_rounded, size: 18),
                        label: const Text('Tokenize project')),
                  ] else ...[
                    KeyValue('Status', tokenStatusLabels['${t['status']}'] ?? '${t['status']}'),
                    KeyValue('Token', '${t['asset_name']} (${t['unit_name']})'),
                    if (t['mode'] == 'on_invest' && t['status'] != 'created')
                      Text('Created when FARM lists the project.', style: TextStyle(fontSize: 12, color: mutedColor(c))),
                    if (t['asset_id'] != null) KeyValue('Asset ID', '${t['asset_id']}'),
                    if (t['mode'] == 'on_invest' && t['status'] == 'created' && p != null) _progress(c, t, p),
                    Wrap(spacing: 4, children: [
                      if (t['explorer_url'] != null)
                        TextButton(
                            onPressed: () => openDoc(c, '${t['explorer_url']}'),
                            child: Text('View on explorer', style: TextStyle(color: fgColor(c)))),
                      if (t['status'] == 'created')
                        TextButton.icon(
                            onPressed: () => pushPage(c, HolderIncomePage(projectId: widget.projectId)),
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Pay token holders')),
                    ]),
                  ],
                ]);
              },
            ),
          ),
        ),
      );
}


/// Business: pay profit / rental income to the project's current token holders.
class HolderIncomePage extends StatefulWidget {
  const HolderIncomePage({super.key, required this.projectId});
  final String projectId;
  @override
  State<HolderIncomePage> createState() => _HolderIncomePageState();
}

class _HolderIncomePageState extends State<HolderIncomePage> {
  final _key = GlobalKey<BizAsyncState<List<Map<String, dynamic>>>>();

  Future<void> _new() async {
    final amt = TextEditingController();
    final desc = TextEditingController();
    var kind = 'profit';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Pay token holders'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'profit', label: Text('Profit')),
                  ButtonSegment(value: 'rental', label: Text('Rental')),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setD(() => kind = v.first),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: amt,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: bizInput(ctx, 'Amount in FARM')),
              TextField(controller: desc, maxLength: 500, decoration: bizInput(ctx, 'Note for holders (optional)')),
              Text(
                  'Paid from your FARM wallet after FARM approves. Split by how many tokens each holder has at payout time. No fee.',
                  style: TextStyle(fontSize: 12, color: mutedColor(ctx))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
          ],
        ),
      ),
    );
    final amount = num.tryParse(amt.text.trim());
    final note = desc.text.trim();
    amt.dispose();
    desc.dispose();
    if (ok != true || !mounted) return;
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least 1 FARM')));
      return;
    }
    final r = await runBusy(context, () => InvestmentsApi.requestDistribution(widget.projectId, amount, kind, note),
        success: 'Sent to FARM for approval.');
    if (r != null) _key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Token holder income',
        fab: BizFab(label: 'Pay holders', onPressed: _new),
        body: BizAsync<List<Map<String, dynamic>>>(
          key: _key,
          load: () => InvestmentsApi.projectDistributions(widget.projectId),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.payments_outlined,
          emptyTitle: 'No payouts yet',
          emptyMessage: 'Share profit or rental income with everyone who holds this project\'s tokens.',
          builder: (c, l, _) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final d in l)
              BizTile(
                leading: Icons.payments_outlined,
                title: '${d['amount']} FARM · ${d['kind'] == 'rental' ? 'Rental' : 'Profit'}',
                subtitle: [
                  if (d['holders'] != null) '${d['holders']} holders · paid ${d['paid_amount']} FARM',
                  if (d['notes'] != null) '${d['notes']}',
                  if (d['error'] != null && d['status'] == 'failed') '${d['error']}',
                ].join('\n'),
                trailing: StatusChip('${d['status']}', filled: d['status'] == 'paid'),
              ),
          ]),
        ),
      );
}
