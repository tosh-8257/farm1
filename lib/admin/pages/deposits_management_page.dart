import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';
import '/services/transaction_receipt_service.dart';
import '/widgets/common/transaction_receipt_selection_bar.dart';

class DepositsManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const DepositsManagementPage({super.key, this.onGoBack});

  @override
  State<DepositsManagementPage> createState() => _DepositsManagementPageState();
}

class _DepositsManagementPageState extends State<DepositsManagementPage>
    with AdminPageRefreshMixin<DepositsManagementPage> {
  List<dynamic> _deposits = [];
  bool _loading = true;
  String _statusFilter = 'all';
  int _page = 1;
  String _search = '';
  final _searchController = TextEditingController();
  final Set<int> _selectedTransactions = <int>{};

  List<Map<String, dynamic>> get _visibleDeposits => _deposits
      .whereType<Map>()
      .map((deposit) => Map<String, dynamic>.from(deposit))
      .where((deposit) =>
          _search.isEmpty ||
          deposit.toString().toLowerCase().contains(_search.toLowerCase()))
      .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getDeposits(
          page: _page, status: _statusFilter == 'all' ? null : _statusFilter);
      setState(() {
        _deposits = res['data'] ?? [];
        _selectedTransactions.clear();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  List<Map<String, dynamic>> get _selectedReceipts => _selectedTransactions
      .where((index) => index >= 0 && index < _visibleDeposits.length)
      .map((index) => _visibleDeposits[index])
      .toList();

  Future<void> _shareSelected() async {
    try {
      await TransactionReceiptService.shareReceipts(_selectedReceipts);
      if (mounted) setState(() => _selectedTransactions.clear());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipts: $error')),
      );
    }
  }

  Future<void> _downloadSelected() async {
    try {
      await TransactionReceiptService.downloadReceipts(_selectedReceipts);
      if (!mounted) return;
      setState(() => _selectedTransactions.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected receipts saved to gallery')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save receipts: $error')),
      );
    }
  }

  void _toggleAll() => setState(() {
        if (_selectedTransactions.length == _visibleDeposits.length) {
          _selectedTransactions.clear();
        } else {
          _selectedTransactions
            ..clear()
            ..addAll(List<int>.generate(_visibleDeposits.length, (i) => i));
        }
      });

  Color _sc(String? s) {
    switch (s) {
      case 'completed':
        return context.successColor;
      case 'pending':
        return context.warningColor;
      case 'failed':
        return context.errorColor;
      default:
        return AdminColors.textSecondary;
    }
  }

  String _paymentMethodLabel(Map? meta, Map txn) {
    final raw = meta?['method'] ??
        txn['paymentMethod'] ??
        txn['payment_method'] ??
        meta?['payment_method'] ??
        txn['payment_provider'] ??
        meta?['provider'] ??
        txn['provider'];
    final value = raw?.toString().toLowerCase() ?? '';
    if (value.contains('crypto') || value.contains('ivory')) return 'CRYPTO';
    if (value.contains('mobile')) return 'MOBILE';
    if (value.contains('card')) return 'CARD';
    if (value.contains('paystack')) {
      final explicit = (meta?['method'] ??
              txn['method'] ??
              txn['paymentMethod'] ??
              txn['payment_method'])
          ?.toString()
          .toLowerCase();
      if (explicit?.contains('mobile') == true) return 'MOBILE';
      if (explicit?.contains('card') == true) return 'CARD';
      return 'PAYSTACK';
    }
    return value.isNotEmpty ? value.toUpperCase() : 'Not specified';
  }

  String _userLabel(Map record) {
    final username = (record['username'] ?? '').toString().trim();
    final name = (record['user_name'] ?? '').toString().trim();
    final email = (record['user_email'] ?? '').toString().trim();
    final phone = (record['user_phone'] ?? '').toString().trim();
    final identity = username.isNotEmpty ? '@$username' : '';
    if (identity.isNotEmpty && name.isNotEmpty) return '$identity · $name';
    if (identity.isNotEmpty) return identity;
    if (name.isNotEmpty) return name;
    if (email.isNotEmpty) return email;
    if (phone.isNotEmpty) return phone;
    return 'Not linked';
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white;
    final cardColor = Colors.white;
    final accent = AppTheme.accentOn(bgColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _filterRow(accent),
            if (_selectedTransactions.isNotEmpty)
              TransactionReceiptSelectionBar(
                selectedCount: _selectedTransactions.length,
                totalCount: _visibleDeposits.length,
                onSelectAll: _toggleAll,
                onShare: _shareSelected,
                onDownload: _downloadSelected,
              ),
            if (_loading && _deposits.isEmpty)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF90CAF9))))
            else
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _load,
                      color: accent,
                      child: _deposits.isEmpty
                          ? Center(
                              child: Text('No deposits found',
                                  style: GoogleFonts.plusJakartaSans(
                                      color:
                                          AdminColors.textSecondary)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _visibleDeposits.length,
                              itemBuilder: (_, i) {
                                final d = _visibleDeposits[i];
                                final meta = d['metadata'] as Map? ?? {};
                                final color = _sc(d['status']);
                                final method = _paymentMethodLabel(meta, d);
                                final userLabel = _userLabel(d);
                                final userId = (d['user_id'] ?? '').toString();
                                final senderLabel = (d['sender_name'] ??
                                        d['sender_wallet'] ??
                                        'External payment provider')
                                    .toString();
                                final receiverLabel = (d['receiver_name'] ??
                                        d['receiver_wallet'] ??
                                        userLabel)
                                    .toString();
                                final reference = (d['transaction_reference'] ??
                                        d['id'] ??
                                        '-')
                                    .toString();
                                final amountLabel = d['amount_display']
                                        ?.toString() ??
                                    '${double.tryParse(d['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} FARM';
                                final statusLabel =
                                    (d['status_display'] ?? d['status'] ?? '-')
                                        .toString()
                                        .toUpperCase();
                                final dateLabel = (d['date'] ?? '-').toString();
                                final timeLabel = (d['time'] ?? '-').toString();
                                return GestureDetector(
                                  onLongPress: () => setState(
                                      () => _selectedTransactions.add(i)),
                                  onTap: () {
                                    if (_selectedTransactions.isNotEmpty) {
                                      setState(() {
                                        if (!_selectedTransactions.add(i)) {
                                          _selectedTransactions.remove(i);
                                        }
                                      });
                                      return;
                                    }
                                    TransactionReceiptService.showDetails(
                                      context,
                                      d,
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: context.onSurface
                                              .withOpacity(0.1)),
                                    ),
                                    child: Row(children: [
                                      if (_selectedTransactions.isNotEmpty)
                                        Checkbox(
                                          value:
                                              _selectedTransactions.contains(i),
                                          onChanged: (selected) => setState(() {
                                            if (selected == true) {
                                              _selectedTransactions.add(i);
                                            } else {
                                              _selectedTransactions.remove(i);
                                            }
                                          }),
                                        ),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                            color: context.successColor
                                                .withAlpha(
                                                    (0.14 * 255).round()),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Icon(Icons.south_west_rounded,
                                            color: context.successColor,
                                            size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text('User: $userLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color:
                                                            context.onSurface,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14)),
                                            Text(
                                                'User ID: ${userId.isNotEmpty ? userId : '-'}',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context
                                                            .onSurface
                                                            .withOpacity(0.78),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Sender: $senderLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.78),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Receiver: $receiverLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.78),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('ID: $reference',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.7),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Method: $method',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.54),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Amount: $amountLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.54),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Status: $statusLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.54),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Date: $dateLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.54),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                            Text('Time: $timeLabel',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                        color: context.onSurface
                                                            .withOpacity(0.54),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                          ])),
                                      if (MediaQuery.of(context).size.width >=
                                          480) ...[
                                        const SizedBox(width: 8),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(amountLabel,
                                                  style: GoogleFonts
                                                      .plusJakartaSans(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          color: context
                                                              .successColor)),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                    color: color.withAlpha(
                                                        (0.16 * 255).round()),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6)),
                                                child: Text(statusLabel,
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                            color: color,
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                              ),
                                            ]),
                                      ],
                                    ]),
                                  ),
                                );
                              }))),
          ],
        ),
      ),
    );
  }

  Widget _filterRow(Color accent) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                    hintText: 'Search username, user ID, deposit ID',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder()),
                onChanged: (value) => setState(() {
                      _search = value;
                      _selectedTransactions.clear();
                    }))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            for (final s in ['all', 'completed', 'pending', 'failed'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _statusFilter == s
                              ? AppTheme.onAccent
                              : Colors.black)),
                  selected: _statusFilter == s,
                  selectedColor: AppTheme.accent,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                      color: _statusFilter == s ? AppTheme.accent : Colors.black54,
                      width: 1),
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = s;
                      _page = 1;
                    });
                    _load();
                  },
                ),
              ),
          ]),
        )
      ]);
}
