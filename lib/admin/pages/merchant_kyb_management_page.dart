import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '/utils/user_error_message.dart';

class MerchantKybManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const MerchantKybManagementPage({super.key, this.onGoBack});

  @override
  State<MerchantKybManagementPage> createState() =>
      _MerchantKybManagementPageState();
}

class _MerchantKybManagementPageState extends State<MerchantKybManagementPage> {
  final _bgColor = Colors.white;
  final _cardColor = Colors.white;
  final _accent = AppTheme.accentOn(Colors.white);

  List<dynamic> _merchants = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'pending';
  final Map<String, bool> _processing = {};

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
      final res = await AdminApiService.getMerchants(
        page: 1,
        status: _statusFilter != 'all' ? _statusFilter : null,
      );
      setState(() => _merchants = res['data'] as List? ?? []);
    } catch (e) {
      setState(() => _error = userErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewMerchant(String merchantId, String status,
      {String? rejectionReason}) async {
    setState(() => _processing[merchantId] = true);
    try {
      await AdminApiService.decideMerchant(merchantId, status,
          rejectionReason: rejectionReason);
      _snack(
          status == 'approved'
              ? 'Merchant KYB approved ✓'
              : 'Merchant KYB rejected',
          status == 'approved' ? context.successColor : context.errorColor);
      _load();
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), context.errorColor);
    } finally {
      if (mounted) setState(() => _processing[merchantId] = false);
    }
  }

  Future<void> _showMerchantDetails(String merchantId) async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getMerchant(merchantId);
      final m = res['data'] as Map<String, dynamic>? ?? {};
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(m['business_name'] ?? m['name'] ?? 'Merchant'),
          content: SingleChildScrollView(
            child: _detailsColumn(m),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close')),
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRejectDialog(merchantId);
                },
                child: Text('Reject',
                    style: TextStyle(color: context.errorColor))),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _reviewMerchant(merchantId, 'approved');
                },
                child: const Text('Approve')),
          ],
        ),
      );
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), context.errorColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRejectDialog(String merchantId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Reject Merchant KYB',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold, color: context.onSurface)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: context.onSurface),
          decoration: InputDecoration(
            hintText: 'Reason for rejection',
            hintStyle: TextStyle(color: context.onSurface.withOpacity(0.38)),
            filled: true,
            fillColor: const Color(0xFF0F1724),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _accent)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: context.errorColor),
            onPressed: () {
              Navigator.pop(context);
              _reviewMerchant(merchantId, 'rejected',
                  rejectionReason: controller.text);
            },
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating),
      );

  String _merchantId(dynamic merchant) {
    return merchant['id']?.toString() ??
        merchant['merchant_id']?.toString() ??
        '';
  }

  String _merchantStatus(dynamic merchant) {
    return merchant['kyb_status']?.toString().toLowerCase() ??
        merchant['status']?.toString().toLowerCase() ??
        'pending';
  }

  String _detailLabel(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _detailValue(dynamic value) {
    if (value is Map || value is List) return value.toString();
    return value?.toString() ?? '-';
  }

  List<MapEntry<String, dynamic>> _merchantDetailEntries(
      Map<String, dynamic> merchant) {
    const hidden = {
      'id',
      'user_id',
      'approved_by',
      'qr_secret',
      'users_merchants_user_idTousers',
      'merchant_payouts',
    };
    return merchant.entries
        .where((entry) => !hidden.contains(entry.key))
        .where(
            (entry) => entry.value != null && entry.value.toString().isNotEmpty)
        .toList();
  }

  Widget _detailsColumn(Map<String, dynamic> merchant) {
    final applicant = merchant['users_merchants_user_idTousers'];
    final entries = _merchantDetailEntries(merchant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (applicant is Map) ...[
          Text('Applicant account',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...applicant.entries.map((entry) =>
              _detailRow(_detailLabel(entry.key), _detailValue(entry.value))),
          const Divider(height: 22),
        ],
        ...entries.map((entry) =>
            _detailRow(_detailLabel(entry.key), _detailValue(entry.value))),
        if (merchant['merchant_payouts'] is List &&
            (merchant['merchant_payouts'] as List).isNotEmpty) ...[
          const Divider(height: 22),
          Text('Recent payouts',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...((merchant['merchant_payouts'] as List)
              .map((payout) => _detailRow('Payout', _detailValue(payout)))),
        ],
        if (merchant['decision_history'] is List &&
            (merchant['decision_history'] as List).isNotEmpty) ...[
          const Divider(height: 22),
          Text('Decision history',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...((merchant['decision_history'] as List).map(
              (decision) => _detailRow('Decision', _detailValue(decision)))),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: context.onSurface.withOpacity(0.54))),
          const SizedBox(height: 2),
          SelectableText(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, color: context.onSurface)),
        ],
      ),
    );
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
          child: _loading && _merchants.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator())
                ])
              : ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Merchant KYB',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.onSurface)),
                  const SizedBox(height: 6),
                  Text(
                      'Review merchant KYB applications and decide onboarding status.',
                      style: GoogleFonts.plusJakartaSans(
                          color: context.onSurface.withOpacity(0.7),
                          fontSize: 13)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final status in [
                        'all',
                        'pending',
                        'approved',
                        'rejected',
                        'active'
                      ])
                        ChoiceChip(
                          label: Text(status.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                  color: _statusFilter == status
                                      ? context.background
                                      : context.onSurface.withOpacity(0.7),
                                  fontSize: 12)),
                          selected: _statusFilter == status,
                          selectedColor: AppTheme.accent,
                          backgroundColor: _cardColor,
                          side: BorderSide(
                              color: _statusFilter == status
                                  ? AppTheme.accent
                                  : context.onSurface.withOpacity(0.1)),
                          onSelected: (_) {
                            setState(() => _statusFilter = status);
                            _load();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
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
                                  color: context.onSurface.withOpacity(0.7))),
                        ),
                        TextButton(
                            onPressed: _load,
                            child: Text('Retry',
                                style: TextStyle(color: _accent))),
                      ]),
                    ),
                  if (_merchants.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: context.onSurface.withOpacity(0.1)),
                      ),
                      child: Column(children: [
                        Icon(Icons.badge_rounded,
                            size: 32,
                            color: context.onSurface.withOpacity(0.24)),
                        const SizedBox(height: 14),
                        Text('No merchant KYB records found',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                color: context.onSurface.withOpacity(0.54),
                                fontSize: 14)),
                      ]),
                    )
                  else
                    ..._merchants.map((merchant) {
                      final id = _merchantId(merchant);
                      final status = _merchantStatus(merchant);
                      final processing = _processing[id] == true;
                      final business = merchant['business_name'] ??
                          merchant['name'] ??
                          'Merchant';
                      final email =
                          merchant['email'] ?? merchant['contact_email'] ?? '-';
                      final phone =
                          merchant['phone'] ?? merchant['contact_phone'] ?? '-';
                      final created =
                          merchant['created_at'] ?? merchant['createdAt'] ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: context.onSurface.withOpacity(0.1)),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(business,
                                      style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: context.onSurface)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: status == 'approved'
                                        ? context.successColor
                                            .withAlpha((0.15 * 255).round())
                                        : status == 'rejected'
                                            ? context.errorColor
                                                .withAlpha((0.15 * 255).round())
                                            : context.warningColor.withAlpha(
                                                (0.14 * 255).round()),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(status.toUpperCase(),
                                      style: GoogleFonts.plusJakartaSans(
                                          color: status == 'approved'
                                              ? context.successColorAccent
                                              : status == 'rejected'
                                                  ? context.errorColorAccent
                                                  : context.warningColorAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                )
                              ]),
                              const SizedBox(height: 10),
                              Text(email,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: context.onSurface.withOpacity(0.6),
                                      fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(phone,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: context.onSurface.withOpacity(0.6),
                                      fontSize: 12)),
                              if (created.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Applied: $created',
                                    style: GoogleFonts.plusJakartaSans(
                                        color:
                                            context.onSurface.withOpacity(0.38),
                                        fontSize: 11)),
                              ],
                              const SizedBox(height: 12),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                title: Text('Submitted business details',
                                    style: GoogleFonts.plusJakartaSans(
                                        color: context.onSurface,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                children: [
                                  ..._merchantDetailEntries(
                                          Map<String, dynamic>.from(merchant))
                                      .map((entry) => _detailRow(
                                          _detailLabel(entry.key),
                                          _detailValue(entry.value))),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showMerchantDetails(id),
                                  icon:
                                      const Icon(Icons.info_outline, size: 16),
                                  label: const Text('View details'),
                                ),
                              ),
                              if (status == 'pending')
                                Row(children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: context.errorColor),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        foregroundColor: context.errorColor,
                                      ),
                                      onPressed: processing
                                          ? null
                                          : () => _showRejectDialog(id),
                                      child: Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                                        backgroundColor: AppTheme.accent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: processing
                                          ? null
                                          : () =>
                                              _reviewMerchant(id, 'approved'),
                                      child: processing
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  color: AppTheme.onAccent,
                                                  strokeWidth: 2),
                                            )
                                          : Text('Approve',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppTheme.onAccent)),
                                    ),
                                  ),
                                ])
                              else
                                Row(children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: status == 'approved'
                                            ? context.successColor
                                            : context.errorColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      onPressed: processing
                                          ? null
                                          : () => _reviewMerchant(
                                              id,
                                              status == 'approved'
                                                  ? 'rejected'
                                                  : 'approved'),
                                      child: Text(
                                        status == 'approved'
                                            ? 'Mark Rejected'
                                            : 'Mark Approved',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: context.onBackground
                                                .withOpacity(0.87)),
                                      ),
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
