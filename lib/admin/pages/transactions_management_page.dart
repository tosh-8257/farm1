import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';
import '/services/transaction_receipt_service.dart';
import '/widgets/common/transaction_receipt_selection_bar.dart';

class TransactionsManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const TransactionsManagementPage({super.key, this.onGoBack});

  @override
  State<TransactionsManagementPage> createState() =>
      _TransactionsManagementPageState();
}

class _TransactionsManagementPageState extends State<TransactionsManagementPage>
    with AdminPageRefreshMixin<TransactionsManagementPage> {
  List<dynamic> _txns = [];
  bool _loading = true;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  int _page = 1;
  int _total = 0;
  String _search = '';
  final _searchController = TextEditingController();
  final Set<int> _selectedTransactions = <int>{};

  List<Map<String, dynamic>> get _visibleTransactions => _txns
      .whereType<Map>()
      .map((transaction) => Map<String, dynamic>.from(transaction))
      .where((transaction) =>
          _search.trim().isEmpty ||
          transaction.toString().toLowerCase().contains(_search.toLowerCase()))
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
      final res = await AdminApiService.getTransactions(
        page: _page,
        type: _typeFilter == 'all' ? null : _typeFilter,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() {
        _txns = res['data'] ?? [];
        _total = res['meta']?['total'] ?? 0;
        _selectedTransactions.clear();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  Future<void> _shareSelected() async {
    try {
      await TransactionReceiptService.shareReceipts(
        _selectedTransactions
            .where((index) => index >= 0 && index < _visibleTransactions.length)
            .map((index) => _visibleTransactions[index])
            .toList(),
      );
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
      await TransactionReceiptService.downloadReceipts(
        _selectedTransactions
            .where((index) => index >= 0 && index < _visibleTransactions.length)
            .map((index) => _visibleTransactions[index])
            .toList(),
      );
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

  Color _statusColor(String? s) {
    switch (s) {
      case 'completed':
        return context.successColor;
      case 'pending':
        return context.warningColor;
      case 'failed':
        return context.errorColor;
      case 'processing':
        return Colors.blue;
      default:
        return AdminColors.textSecondary;
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(children: [
                IconButton(
                  tooltip: 'Go back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed:
                      widget.onGoBack ?? () => Navigator.of(context).maybePop(),
                ),
                Text('Transactions',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
            _filters(accent),
            if (_selectedTransactions.isNotEmpty)
              TransactionReceiptSelectionBar(
                selectedCount: _selectedTransactions.length,
                totalCount: _visibleTransactions.length,
                onSelectAll: () => setState(() {
                  if (_selectedTransactions.length ==
                      _visibleTransactions.length) {
                    _selectedTransactions.clear();
                  } else {
                    _selectedTransactions
                      ..clear()
                      ..addAll(
                        List<int>.generate(
                            _visibleTransactions.length, (index) => index),
                      );
                  }
                }),
                onShare: _shareSelected,
                onDownload: _downloadSelected,
              ),
            if (_loading && _txns.isEmpty)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF90CAF9))))
            else
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _load,
                      color: accent,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _txns.length + 1,
                        itemBuilder: (_, i) {
                          if (i == _txns.length) {
                            final last = (_total / 20).ceil();
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                        onPressed: _page > 1
                                            ? () {
                                                setState(() {
                                                  _page--;
                                                  _selectedTransactions.clear();
                                                });
                                                _load();
                                              }
                                            : null,
                                        child: Text('← Prev',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: Colors.grey.shade600))),
                                    Text('$_page / $last',
                                        style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            color: context.onSurface)),
                                    TextButton(
                                        onPressed: _page < last
                                            ? () {
                                                setState(() {
                                                  _page++;
                                                  _selectedTransactions.clear();
                                                });
                                                _load();
                                              }
                                            : null,
                                        child: Text('Next →',
                                            style: GoogleFonts.plusJakartaSans(
                                                color: Colors.grey.shade600))),
                                  ]),
                            );
                          }
                          final visible = _visibleTransactions;
                          if (i >= visible.length)
                            return const SizedBox.shrink();
                          final t = visible[i];
                          final color = _statusColor(t['status']);
                          final meta = t['metadata'] as Map? ?? {};
                          final methodValue = (t['method'] ??
                                  meta['payment_method'] ??
                                  meta['method'] ??
                                  '')
                              .toString()
                              .toUpperCase();
                          final method =
                              methodValue == 'UNKNOWN' || methodValue.isEmpty
                                  ? 'Not specified'
                                  : methodValue;
                          final userLabel = _userLabel(t);
                          final userId = (t['user_id'] ?? '').toString();
                          final senderLabel = (t['sender_name'] ??
                                  t['sender_wallet'] ??
                                  'External sender')
                              .toString();
                          final receiverLabel = (t['receiver_name'] ??
                                  t['receiver_wallet'] ??
                                  'External recipient')
                              .toString();
                          final reference =
                              (t['transaction_reference'] ?? t['id'] ?? '-')
                                  .toString();
                          final amountLabel = t['amount_display']?.toString() ??
                              '${double.tryParse(t['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} FARM';
                          final statusLabel =
                              (t['status_display'] ?? t['status'] ?? '-')
                                  .toString()
                                  .toUpperCase();
                          final dateLabel = (t['date'] ?? '-').toString();
                          final timeLabel = (t['time'] ?? '-').toString();
                          return InkWell(
                            onLongPress: () => setState(() {
                              _selectedTransactions.add(i);
                            }),
                            onTap: () {
                              if (_selectedTransactions.isNotEmpty) {
                                setState(() {
                                  if (!_selectedTransactions.add(i)) {
                                    _selectedTransactions.remove(i);
                                  }
                                });
                                return;
                              }
                              _showTransactionDetails(t);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AdminColors.border),
                              ),
                              child: Row(children: [
                                if (_selectedTransactions.isNotEmpty)
                                  Checkbox(
                                    value: _selectedTransactions.contains(i),
                                    onChanged: (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedTransactions.add(i);
                                      } else {
                                        _selectedTransactions.remove(i);
                                      }
                                    }),
                                  ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color:
                                          color.withAlpha((0.14 * 255).round()),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.swap_horiz_rounded,
                                      color: color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('User: $userLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: context.onSurface)),
                                      Text(
                                          'User ID: ${userId.isNotEmpty ? userId : '-'}',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Sender: $senderLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Receiver: $receiverLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('ID: $reference',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Method: $method',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Amount: $amountLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Status: $statusLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Date: $dateLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      Text('Time: $timeLabel',
                                          style: GoogleFonts.plusJakartaSans(
                                              color: context.onSurface
                                                  .withOpacity(0.72),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ])),
                                if (MediaQuery.of(context).size.width >=
                                    480) ...[
                                  const SizedBox(width: 8),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(amountLabel,
                                            style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: context.onSurface)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: color.withAlpha(
                                                  (0.16 * 255).round()),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(statusLabel,
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                      color: color,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                        ),
                                      ]),
                                ],
                              ]),
                            ),
                          );
                        },
                      ))),
          ],
        ),
      ),
    );
  }

  Widget _filters(Color accent) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search username, user ID, transaction ID',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _search = value;
                _selectedTransactions.clear();
              }),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(children: [
              for (final f in [
                'all',
                'transfer',
                'deposit',
                'withdrawal',
                'escrow_lock',
                'escrow_release',
                'investment'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _typeFilter == f
                                ? AppTheme.onAccent
                                : Colors.black)),
                    selected: _typeFilter == f,
                    selectedColor: AppTheme.accent,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: _typeFilter == f ? AppTheme.accent : Colors.black54,
                        width: 1),
                    onSelected: (_) {
                      setState(() {
                        _typeFilter = f;
                        _page = 1;
                        _selectedTransactions.clear();
                      });
                      _load();
                    },
                  ),
                ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              for (final s in [
                'all',
                'completed',
                'pending',
                'failed',
                'processing'
              ])
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
                        color:
                            _statusFilter == s ? AppTheme.accent : Colors.black54,
                        width: 1),
                    onSelected: (_) {
                      setState(() {
                        _statusFilter = s;
                        _page = 1;
                        _selectedTransactions.clear();
                      });
                      _load();
                    },
                  ),
                ),
            ]),
          ),
        ],
      );

  void _showTransactionDetails(Map<String, dynamic> transaction) {
    TransactionReceiptService.showDetails(
      context,
      transaction,
    );
  }
}
