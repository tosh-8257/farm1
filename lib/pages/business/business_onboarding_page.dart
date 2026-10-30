import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/services/api_service.dart';
import '/backend/api_requests/business_api_service.dart';
import '/components/step_indicator/step_indicator_widget.dart';
import 'business_ui.dart';
import 'business_status_page.dart';

const _sectors = <String, String>{
  'agriculture': 'Agriculture',
  'energy': 'Energy',
  'real_estate': 'Real Estate',
  'infrastructure': 'Infrastructure',
  'technology': 'Technology',
  'manufacturing': 'Manufacturing',
  'retail': 'Retail',
  'services': 'Services',
  'other': 'Other',
};

const _docTypes = <String, String>{
  'certificate_of_incorporation': 'Certificate of incorporation *',
  'proof_of_address': 'Proof of business address *',
  'business_registration': 'Business registration / permit',
  'tax_certificate': 'Tax registration certificate',
  'memorandum_articles': 'Memorandum & articles',
  'director_id': 'Director ID',
  'beneficial_owner_id': 'Beneficial owner ID',
  'other': 'Other supporting document',
};

/// Multi-step KYB form. Every step saves a server-side draft; nothing is
/// approved on the device. Submitting moves the application to Under Review.
class BusinessOnboardingPage extends StatefulWidget {
  const BusinessOnboardingPage({super.key});

  static String routeName = 'BusinessOnboarding';
  static String routePath = '/business/onboarding';

  @override
  State<BusinessOnboardingPage> createState() => _BusinessOnboardingPageState();
}

class _BusinessOnboardingPageState extends State<BusinessOnboardingPage> {
  static const _titles = [
    'Business information',
    'Contact & address',
    'Directors',
    'Beneficial owners',
    'Documents',
    'Review & submit',
  ];

  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _status;
  String? _reviewNotes;

  final _c = <String, TextEditingController>{
    for (final k in [
      'legal_name',
      'trading_name',
      'registration_number',
      'registration_country',
      'incorporation_date',
      'business_type',
      'tax_id',
      'description',
      'country',
      'city',
      'address',
      'postal_code',
      'business_email',
      'business_phone',
      'website',
    ])
      k: TextEditingController(),
  };
  String? _sector;
  List<Map<String, dynamic>> _persons = [];
  List<Map<String, dynamic>> _documents = [];
  List<String> _missing = [];
  String? _uploadingType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      var data = await BusinessApiService.getMine();
      var b = data['business'];
      if (b is! Map) {
        // Arrived here directly: start the upgrade (creates a Draft).
        b = await BusinessApiService.upgrade();
      }
      _apply(Map<String, dynamic>.from(b));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = friendlyError(e);
          _loading = false;
        });
      }
    }
  }

  void _apply(Map<String, dynamic> b) {
    for (final e in _c.entries) {
      final v = b[e.key];
      var s = v?.toString() ?? '';
      if (e.key == 'incorporation_date' && s.length >= 10)
        s = s.substring(0, 10);
      e.value.text = s;
    }
    _sector = b['sector']?.toString();
    _status = b['status']?.toString();
    _reviewNotes = b['review_notes']?.toString();
    _persons = (b['persons'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    _documents = (b['documents'] as List? ?? [])
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    _missing = (b['missing'] as List? ?? []).map((e) => e.toString()).toList();
  }

  Map<String, dynamic> _payload() {
    final body = <String, dynamic>{};
    _c.forEach((k, c) {
      final v = c.text.trim();
      if (v.isNotEmpty) body[k] = v;
    });
    if (_sector != null) body['sector'] = _sector;
    body['persons'] = _persons
        .map(
          (p) => {
            'role': p['role'],
            'full_name': p['full_name'],
            for (final k in [
              'nationality',
              'id_number',
              'email',
              'phone',
              'ownership_percent',
            ])
              if (p[k] != null && p[k].toString().isNotEmpty) k: p[k],
          },
        )
        .toList();
    body['documents'] = _documents
        .map(
          (d) => {
            'doc_type': d['doc_type'],
            'file_url': d['file_url'],
            if (d['file_name'] != null) 'file_name': d['file_name'],
          },
        )
        .toList();
    return body;
  }

  Future<bool> _save({bool quiet = false}) async {
    setState(() => _saving = true);
    try {
      final b = await BusinessApiService.saveDraft(_payload());
      if (!mounted) return false;
      setState(() => _apply(b));
      if (!quiet) _snack('Draft saved');
      return true;
    } catch (e) {
      _snack(friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Submit for verification?'),
        content: const Text(
          'Our compliance team will review your business. You will not be able to edit it while it is under review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await _save(quiet: true)) return;
    setState(() => _saving = true);
    try {
      await BusinessApiService.submit();
      if (!mounted) return;
      context.pushReplacementNamed(BusinessStatusPage.routeName);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  bool get _editable =>
      _status == null || BusinessStatus.editable.contains(_status);

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: const Text('Business verification'),
        actions: [
          if (!_loading && _loadError == null && _editable)
            TextButton(
              onPressed: _saving ? null : () => _save(),
              child: Text(
                'Save draft',
                style: TextStyle(color: theme.primaryText),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: BizMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Could not open your application',
          message: _loadError!,
          action: _load,
          actionLabel: 'Retry',
        ),
      );
    }
    if (!_editable) {
      return Center(
        child: BizMessage(
          icon: Icons.hourglass_top_rounded,
          title: BusinessStatus.label(_status),
          message: 'This application cannot be edited right now.',
          action: () =>
              context.pushReplacementNamed(BusinessStatusPage.routeName),
          actionLabel: 'View status',
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _titles.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: StepIndicatorWidget(active: i == _step),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Step ${_step + 1} of ${_titles.length}',
                style: TextStyle(color: mutedColor(context), fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _titles[_step],
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: fgColor(context),
                ),
              ),
              if (_reviewNotes != null &&
                  _reviewNotes!.isNotEmpty &&
                  _status != BusinessStatus.draft) ...[
                const SizedBox(height: 12),
                BizCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Reviewer note: $_reviewNotes',
                    style: TextStyle(color: fgColor(context), height: 1.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [_stepBody(context)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    style: secondaryButtonStyle(context),
                    onPressed: _saving
                        ? null
                        : () => setState(() => _step -= 1),
                    child: const Text('Back'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: primaryButtonStyle(context),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_step == _titles.length - 1) {
                            await _submit();
                          } else if (await _save(quiet: true)) {
                            setState(() => _step += 1);
                          }
                        },
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _step == _titles.length - 1
                              ? 'Submit for review'
                              : 'Next',
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepBody(BuildContext context) {
    switch (_step) {
      case 0:
        return Column(
          children: [
            _field('legal_name', 'Registered business name *'),
            _field('trading_name', 'Trading name'),
            _field('registration_number', 'Registration number *'),
            _field('registration_country', 'Country of registration *'),
            _field(
              'incorporation_date',
              'Date of incorporation (YYYY-MM-DD)',
              keyboard: TextInputType.datetime,
            ),
            _field('business_type', 'Legal form (e.g. Limited company)'),
            _sectorField(context),
            _field('tax_id', 'Tax ID / PIN'),
            _field('description', 'What does the business do?', lines: 3),
          ],
        );
      case 1:
        return Column(
          children: [
            _field('country', 'Country of operation *'),
            _field('city', 'City'),
            _field('address', 'Business address *', lines: 2),
            _field('postal_code', 'Postal code'),
            _field(
              'business_email',
              'Business email *',
              keyboard: TextInputType.emailAddress,
            ),
            _field(
              'business_phone',
              'Business phone *',
              keyboard: TextInputType.phone,
            ),
            _field('website', 'Website', keyboard: TextInputType.url),
          ],
        );
      case 2:
        return _personsStep(
          context,
          'director',
          'Add every director of the business. At least one is required.',
        );
      case 3:
        return _personsStep(
          context,
          'beneficial_owner',
          'Add each person who owns or controls 25% or more of the business. At least one is required.',
        );
      case 4:
        return _documentsStep(context);
      default:
        return _reviewStep(context);
    }
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: _c[key],
      maxLines: lines,
      keyboardType: keyboard,
      style: TextStyle(color: fgColor(context)),
      decoration: _decoration(label),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: mutedColor(context)),
    filled: true,
    fillColor: cardColor(context),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor(context)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: borderColor(context)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: fgColor(context)),
    ),
  );

  Widget _sectorField(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      value: _sectors.containsKey(_sector) ? _sector : null,
      decoration: _decoration('Business sector *'),
      dropdownColor: cardColor(context),
      items: _sectors.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, style: TextStyle(color: fgColor(context))),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _sector = v),
    ),
  );

  Widget _personsStep(BuildContext context, String role, String help) {
    final list = _persons.where((p) => p['role'] == role).toList();
    final noun = role == 'director' ? 'director' : 'beneficial owner';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(help, style: TextStyle(color: mutedColor(context), height: 1.5)),
        const SizedBox(height: 16),
        if (list.isEmpty)
          BizCard(
            child: Text(
              'No ${noun}s added yet.',
              style: TextStyle(color: mutedColor(context)),
            ),
          ),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BizCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['full_name']?.toString() ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: fgColor(context),
                          ),
                        ),
                        Text(
                          [
                                p['nationality'],
                                if (p['ownership_percent'] != null)
                                  '${p['ownership_percent']}%',
                              ]
                              .where(
                                (e) => e != null && e.toString().isNotEmpty,
                              )
                              .join(' · '),
                          style: TextStyle(
                            color: mutedColor(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: fgColor(context)),
                    onPressed: () => _editPerson(role, p),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: fgColor(context)),
                    onPressed: () => setState(() => _persons.remove(p)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: secondaryButtonStyle(context),
          onPressed: () => _editPerson(role, null),
          icon: const Icon(Icons.add),
          label: Text('Add $noun'),
        ),
      ],
    );
  }

  Future<void> _editPerson(String role, Map<String, dynamic>? existing) async {
    final fields = {
      'full_name': TextEditingController(text: existing?['full_name'] ?? ''),
      'nationality': TextEditingController(
        text: existing?['nationality'] ?? '',
      ),
      'id_number': TextEditingController(text: existing?['id_number'] ?? ''),
      'email': TextEditingController(text: existing?['email'] ?? ''),
      'phone': TextEditingController(text: existing?['phone'] ?? ''),
      'ownership_percent': TextEditingController(
        text: existing?['ownership_percent']?.toString() ?? '',
      ),
    };
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                role == 'director' ? 'Director' : 'Beneficial owner',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: fgColor(context),
                ),
              ),
              const SizedBox(height: 16),
              for (final e in {
                'full_name': 'Full legal name *',
                'nationality': 'Nationality',
                'id_number': 'ID / passport number',
                'email': 'Email',
                'phone': 'Phone',
                if (role == 'beneficial_owner')
                  'ownership_percent': 'Ownership %',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: fields[e.key],
                    keyboardType: e.key == 'ownership_percent'
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : null,
                    style: TextStyle(color: fgColor(context)),
                    decoration: _decoration(e.value),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: primaryButtonStyle(context),
                onPressed: () {
                  if (fields['full_name']!.text.trim().isEmpty) return;
                  Navigator.pop(c, true);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      final pct = double.tryParse(fields['ownership_percent']!.text.trim());
      final person = <String, dynamic>{
        'role': role,
        'full_name': fields['full_name']!.text.trim(),
        'nationality': fields['nationality']!.text.trim(),
        'id_number': fields['id_number']!.text.trim(),
        'email': fields['email']!.text.trim(),
        'phone': fields['phone']!.text.trim(),
        if (pct != null && pct >= 0 && pct <= 100) 'ownership_percent': pct,
      };
      setState(() {
        if (existing != null) {
          final i = _persons.indexOf(existing);
          if (i >= 0) _persons[i] = person;
        } else {
          _persons.add(person);
        }
      });
    }
    for (final c in fields.values) {
      c.dispose();
    }
  }

  Widget _documentsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upload a PDF, or a clear photo or scan (JPG, PNG or WebP), up to 10 MB, of each document. Items marked * are required.',
          style: TextStyle(color: mutedColor(context), height: 1.5),
        ),
        const SizedBox(height: 16),
        for (final e in _docTypes.entries) _docRow(context, e.key, e.value),
      ],
    );
  }

  Widget _docRow(BuildContext context, String type, String label) {
    final docs = _documents.where((d) => d['doc_type'] == type).toList();
    final uploading = _uploadingType == type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BizCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              docs.isEmpty
                  ? Icons.description_outlined
                  : Icons.check_circle_outline,
              color: fgColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: fgColor(context),
                    ),
                  ),
                  Text(
                    docs.isEmpty
                        ? 'Not uploaded'
                        : '${docs.length} file(s) uploaded',
                    style: TextStyle(color: mutedColor(context), fontSize: 13),
                  ),
                ],
              ),
            ),
            if (docs.isNotEmpty)
              IconButton(
                tooltip: 'Remove',
                icon: Icon(Icons.delete_outline, color: fgColor(context)),
                onPressed: () => setState(
                  () => _documents.removeWhere((d) => d['doc_type'] == type),
                ),
              ),
            uploading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Upload',
                    icon: Icon(Icons.upload_outlined, color: fgColor(context)),
                    onPressed: _uploadingType != null
                        ? null
                        : () => _upload(type),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload(String type) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read that file. Please try another.');
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      _snack('Documents must be no larger than 10 MB.');
      return;
    }
    setState(() => _uploadingType = type);
    try {
      final url = await ApiService.uploadDocument(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      setState(
        () => _documents.add({
          'doc_type': type,
          'file_url': url,
          'file_name': file.name,
        }),
      );
      await _save(quiet: true);
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Widget _reviewStep(BuildContext context) {
    String v(String k) => _c[k]!.text.trim().isEmpty ? '—' : _c[k]!.text.trim();
    final rows = <String, String>{
      'Business name': v('legal_name'),
      'Registration number': v('registration_number'),
      'Country of registration': v('registration_country'),
      'Sector': _sectors[_sector] ?? '—',
      'Address': v('address'),
      'Email': v('business_email'),
      'Phone': v('business_phone'),
      'Website': v('website'),
      'Directors': '${_persons.where((p) => p['role'] == 'director').length}',
      'Beneficial owners':
          '${_persons.where((p) => p['role'] == 'beneficial_owner').length}',
      'Documents': '${_documents.length}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BizCard(
          child: Column(
            children: [
              for (final e in rows.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: TextStyle(color: mutedColor(context)),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: fgColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_missing.isNotEmpty)
          BizCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Still needed before you can submit',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 8),
                for (final m in _missing)
                  Text(
                    '• ${_missingLabel(m)}',
                    style: TextStyle(color: mutedColor(context), height: 1.6),
                  ),
              ],
            ),
          )
        else
          Text(
            'By submitting you confirm the information is accurate. Verification is carried out by FARM\'s compliance team and is not automatic.',
            style: TextStyle(color: mutedColor(context), height: 1.5),
          ),
      ],
    );
  }

  String _missingLabel(String m) {
    if (m.startsWith('document:')) {
      return (_docTypes[m.substring(9)] ?? m).replaceAll(' *', '');
    }
    return const {
          'legal_name': 'Registered business name',
          'registration_number': 'Registration number',
          'registration_country': 'Country of registration',
          'sector': 'Business sector',
          'country': 'Country of operation',
          'address': 'Business address',
          'business_email': 'Business email',
          'business_phone': 'Business phone',
          'directors': 'At least one director',
          'beneficial_owners': 'At least one beneficial owner',
        }[m] ??
        m;
  }
}
