import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '/admin/services/admin_api_service.dart';
import '/admin/services/admin_page_refresh_coordinator.dart';

class FeeManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const FeeManagementPage({super.key, this.onGoBack});

  @override
  State<FeeManagementPage> createState() => _FeeManagementPageState();
}

class _FeeManagementPageState extends State<FeeManagementPage>
    with AdminPageRefreshMixin<FeeManagementPage> {
  final _bgColor = Colors.white;
  final _cardColor = Colors.white;
  final _accent = AppTheme.accentOn(Colors.white);

  List<dynamic> _fees = [];
  bool _loading = true;
  String? _error;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _saving = {};

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
      final res = await AdminApiService.getFees();
      final list = _normalizeFees(res['data']);
      for (final c in _controllers.values) {
        c.dispose();
      }

      _controllers.clear();
      setState(() {
        _fees = list;
        for (final fee in list) {
          final id = _feeId(fee);
          _controllers[id] = TextEditingController(text: _feeValue(fee));
        }
      });
    } catch (e) {
      if (mounted && _fees.isEmpty) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  List<dynamic> _normalizeFees(dynamic payload) {
    if (payload is List) {
      return payload;
    }

    if (payload is Map) {
      final data = payload['data'];
      if (data is List) return data;
      if (payload['items'] is List) return payload['items'] as List<dynamic>;
      if (data is Map && data['items'] is List) {
        return data['items'] as List<dynamic>;
      }
    }

    return [];
  }

  String _feeId(dynamic fee) {
    return fee['id']?.toString() ??
        fee['fee_code']?.toString() ??
        fee['name']?.toString() ??
        '';
  }

  String _feeLabel(dynamic fee) {
    return fee['label']?.toString() ??
        fee['name']?.toString() ??
        fee['transaction_type']?.toString() ??
        'Fee setting';
  }

  String _feeDescription(dynamic fee) {
    final key = fee['transaction_type']?.toString();
    final payer = fee['payer']?.toString();
    final desc = fee['description']?.toString() ??
        'Update the fee percent for this configuration.';
    return [
      desc,
      if (key != null) 'Key: $key',
      if (payer != null) 'Paid by: $payer',
    ].join(' · ');
  }

  String _feeValue(dynamic fee) {
    if (fee is! Map) return '';
    return fee['value']?.toString() ??
        fee['percentage_fee']?.toString() ??
        fee['flat_fee']?.toString() ??
        '';
  }

  Future<void> _saveFee(String feeId) async {
    final controller = _controllers[feeId];
    if (controller == null) return;
    final value = controller.text.trim();
    if (value.isEmpty) {
      _snack('Enter a value before saving', context.warningColor);
      return;
    }

    setState(() => _saving[feeId] = true);
    try {
      await AdminApiService.updateFee(feeId, value);
      final index = _fees.indexWhere((fee) => _feeId(fee) == feeId);
      if (index != -1) {
        setState(() => _fees[index]['value'] = value);
      }
      _snack('Fee updated ✓', context.successColor);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), context.errorColor);
    } finally {
      if (mounted) setState(() => _saving[feeId] = false);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating),
      );

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _accent,
          backgroundColor: _bgColor,
          child: _loading && _fees.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator())
                ])
              : ListView(padding: const EdgeInsets.all(20), children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Go back',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: widget.onGoBack ??
                          () => Navigator.of(context).maybePop(),
                    ),
                    Text('Fee Management',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: context.onSurface)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Review and update platform fee configurations.',
                      style: GoogleFonts.plusJakartaSans(
                          color: AdminColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color:
                            context.errorColor.withAlpha((0.14 * 255).round()),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: context.errorColor
                                .withAlpha((0.2 * 255).round())),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline,
                            color: context.errorColorAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.plusJakartaSans(
                                  color: AdminColors.textSecondary)),
                        ),
                        TextButton(
                            onPressed: _load,
                            child: Text('Retry',
                                style: TextStyle(color: _accent))),
                      ]),
                    ),
                  if (_fees.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AdminColors.border),
                      ),
                      child: Column(children: [
                        Icon(Icons.percent_rounded,
                            size: 32,
                            color: AdminColors.border),
                        const SizedBox(height: 14),
                        Text('No fee configurations available',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: AdminColors.textSecondary,
                                fontSize: 14)),
                      ]),
                    )
                  else
                    ..._fees.map((fee) {
                      final id = _feeId(fee);
                      final controller = _controllers[id]!;
                      final saving = _saving[id] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AdminColors.border),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_feeLabel(fee),
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: context.onSurface)),
                              const SizedBox(height: 8),
                              Text(_feeDescription(fee),
                                  style: GoogleFonts.plusJakartaSans(
                                      color: AdminColors.textSecondary,
                                      fontSize: 12)),
                              const SizedBox(height: 16),
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: GoogleFonts.plusJakartaSans(
                                        color: context.onSurface),
                                    decoration: InputDecoration(
                                      hintText: 'Percent (0–100)',
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                          color: context.onSurface
                                              .withOpacity(0.38)),
                                      filled: true,
                                      fillColor: const Color(0xFF0F1724),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: context.onSurface
                                                .withOpacity(0.1)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                            color: context.onSurface
                                                .withOpacity(0.1)),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                                      backgroundColor: AppTheme.accent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    onPressed:
                                        saving ? null : () => _saveFee(id),
                                    child: saving
                                        ? SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                color: AppTheme.onAccent,
                                                strokeWidth: 2),
                                          )
                                        : Text('Save',
                                            style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.onAccent)),
                                  ),
                                ),
                              ]),
                            ]),
                      );
                    }),
                ]),
        ),
      ),
    );
  }
}
