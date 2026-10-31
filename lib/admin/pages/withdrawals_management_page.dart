import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';
import '/services/transaction_receipt_service.dart';
import '/widgets/common/transaction_receipt_selection_bar.dart';

class WithdrawalsManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const WithdrawalsManagementPage({super.key, this.onGoBack});

  @override
  State<WithdrawalsManagementPage> createState() =>
      _WithdrawalsManagementPageState();
}

class _WithdrawalsManagementPageState extends State<WithdrawalsManagementPage>
    with AdminPageRefreshMixin<WithdrawalsManagementPage> {
  List<dynamic> _withdrawals = [];
  bool _loading = true;
  String _statusFilter = 'all';
  int _page = 1;
  String _search = '';
  final _searchController = TextEditingController();
  final Set<int> _selectedTransactions = <int>{};

  List<Map<String, dynamic>> get _visibleWithdrawals => _withdrawals
      .whereType<Map>()
      .map((withdrawal) => Map<String, dynamic>.from(withdrawal))
      .where((withdrawal) =>
          _search.isEmpty ||
          withdrawal.toString().toLowerCase().contains(_search.toLowerCase()))
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
      final results = await Future.wait([
        AdminApiService.getWithdrawals(
          page: _page,
          status: _statusFilter == 'all' ? null : _statusFilter,
        ),
        AdminApiService.getNowpaymentsCryptoWithdrawals(),
      ]);
      final res = results[0];
      final cryptoTransactions = results[1]['data'];
      final cryptoMetadataByReference = <String, Map<String, dynamic>>{};
      if (cryptoTransactions is List) {
        for (final item in cryptoTransactions.whereType<Map>()) {
          final reference = item['transaction_reference']?.toString();
          final metadata = item['metadata'];
          if (reference != null && metadata is Map) {
            cryptoMetadataByReference[reference] =
                Map<String, dynamic>.from(metadata);
          }
        }
      }
      final rawWithdrawals = res['data'];
      final withdrawals = rawWithdrawals is List
          ? rawWithdrawals.whereType<Map>().map((item) {
              final withdrawal = Map<String, dynamic>.from(item);
              final reference = withdrawal['reference']?.toString();
              final metadata = reference == null
                  ? null
                  : cryptoMetadataByReference[reference];
              if (metadata != null) withdrawal['metadata'] = metadata;
              return withdrawal;
            }).toList()
          : <Map<String, dynamic>>[];
      if (cryptoTransactions is List) {
        for (final item in cryptoTransactions.whereType<Map>()) {
          final cryptoWithdrawal = item['withdrawal'];
          if (cryptoWithdrawal is! Map) continue;
          final withdrawal = Map<String, dynamic>.from(cryptoWithdrawal);
          final reference = withdrawal['reference']?.toString();
          if (reference == null ||
              withdrawals.any((item) => item['reference'] == reference)) {
            continue;
          }
          final metadata = item['metadata'];
          if (metadata is Map) {
            withdrawal['metadata'] = Map<String, dynamic>.from(metadata);
          }
          withdrawals.add(withdrawal);
        }
      }
      setState(() {
        _withdrawals = withdrawals;
        _selectedTransactions.clear();
      });
    } catch (error) {
      _snack('Could not load withdrawals: $error', context.errorColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  List<Map<String, dynamic>> get _selectedReceipts => _selectedTransactions
      .where((index) => index >= 0 && index < _visibleWithdrawals.length)
      .map((index) => _visibleWithdrawals[index])
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
        if (_selectedTransactions.length == _visibleWithdrawals.length) {
          _selectedTransactions.clear();
        } else {
          _selectedTransactions
            ..clear()
            ..addAll(List<int>.generate(_visibleWithdrawals.length, (i) => i));
        }
      });

  Future<void> _process(String txId, String action) async {
    try {
      debugPrint('Processing withdrawal: txId=$txId, action=$action');
      final response = await AdminApiService.processWithdrawal(txId, action);
      debugPrint('Withdrawal processed successfully');
      _snack(
          response['message']?.toString() ??
              (action == 'failed'
                  ? 'Withdrawal rejected; reserved funds are available to the user again.'
                  : 'Withdrawal sent to the payout provider. The wallet is deducted after provider confirmation.'),
          action == 'failed' ? context.errorColor : context.successColor);
      await _load();
    } catch (e) {
      debugPrint('Error processing withdrawal: ${e.toString()}');
      _snack(e.toString(), context.errorColor);
    }
  }

  Future<String?> _requestNowpaymentsVerificationCode() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verify NOWPayments payout'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final code = controller.text.trim();
                if (code.isNotEmpty) Navigator.pop(dialogContext, code);
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _approveNowpaymentsWithdrawal(String reference) async {
    try {
      final result =
          await AdminApiService.approveNowpaymentsCryptoWithdrawal(reference);
      if (result['requires_provider_verification'] == true) {
        final code = await _requestNowpaymentsVerificationCode();
        if (code == null || code.isEmpty) return;
        await AdminApiService.verifyNowpaymentsCryptoWithdrawal(
          reference,
          code,
        );
        _snack(
          'NOWPayments payout verification submitted. Waiting for provider confirmation.',
          context.successColor,
        );
      } else {
        _snack(
          'NOWPayments payout approved. Waiting for provider confirmation.',
          context.successColor,
        );
      }
      await _load();
    } catch (error) {
      _snack(
          'Could not approve NOWPayments payout: $error', context.errorColor);
    }
  }

  Future<void> _rejectWithdrawal(String withdrawalId) async {
    final controller = TextEditingController();
    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reject withdrawal'),
          content: TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Reject and release funds'),
            ),
          ],
        ),
      );
      if (!mounted || reason == null) return;
      try {
        await AdminApiService.processWithdrawal(
          withdrawalId,
          'failed',
          reason: reason,
        );
        _snack(
          'Withdrawal rejected; reserved funds are available to the user again.',
          context.successColor,
        );
        await _load();
      } catch (error) {
        _snack(error.toString(), context.errorColor);
      }
    } finally {
      controller.dispose();
    }
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating));

  Color _sc(String? s) {
    switch (s) {
      case 'completed':
        return context.successColor;
      case 'pending':
      case 'processing':
        return context.warningColor;
      case 'failed':
        return context.errorColor;
      default:
        return AdminColors.textSecondary;
    }
  }

  String _paymentMethodLabel(
    Map? meta,
    Map txn, {
    String fallback = 'Not specified',
  }) {
    final raw = meta?['method'] ??
        txn['method'] ??
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
    return value.isNotEmpty ? value.toUpperCase() : fallback;
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

  String _destinationLabel(Map record) {
    final method = (record['method'] ?? '').toString().toUpperCase();
    if (method == 'MOBILE_MONEY') {
      return (record['phoneNumber'] ?? 'Phone number unavailable').toString();
    }
    if (method == 'BANK_TRANSFER') {
      final bank = (record['bankName'] ?? '').toString();
      final account = (record['accountNumber'] ?? '').toString();
      final name = (record['accountName'] ?? '').toString();
      final destination = [
        if (name.isNotEmpty) name,
        if (bank.isNotEmpty) bank,
        if (account.isNotEmpty) 'Account $account',
      ].join(' · ');
      return destination.isEmpty ? 'Bank account unavailable' : destination;
    }
    if (method == 'CRYPTO') {
      final address = (record['cryptoAddress'] ?? '').toString();
      final asset = (record['cryptoAsset'] ?? '').toString();
      final network = (record['network'] ?? '').toString();
      final destination = [
        if (asset.isNotEmpty) asset,
        if (network.isNotEmpty) network,
        if (address.isNotEmpty) address,
      ].join(' · ');
      return destination.isEmpty
          ? 'Crypto destination unavailable'
          : destination;
    }
    return (record['destination'] ?? 'Destination unavailable').toString();
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
                totalCount: _visibleWithdrawals.length,
                onSelectAll: _toggleAll,
                onShare: _shareSelected,
                onDownload: _downloadSelected,
              ),
            if (_loading && _withdrawals.isEmpty)
              const Expanded(
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF90CAF9))))
            else
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: _load,
                      color: accent,
                      child: _withdrawals.isEmpty
                          ? Center(
                              child: Text('No withdrawal requests',
                                  style: GoogleFonts.plusJakartaSans(
                                      color:
                                          AdminColors.textSecondary)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _visibleWithdrawals.length,
                              itemBuilder: (_, i) {
                                final w = _visibleWithdrawals[i];
                                final meta = w['metadata'] as Map? ?? {};
                                final method = _paymentMethodLabel(meta, w);
                                final status = (w['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final isPending = status == 'pending';
                                final canRetry = status == 'failed';
                                final metadataProvider =
                                    (meta['provider'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final isNowpaymentsCrypto =
                                    method == 'CRYPTO' &&
                                        metadataProvider == 'nowpayments';
                                final approvalStatus =
                                    (meta['payout_approval_status'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final providerPayoutStatus =
                                    (meta['nowpayments_payout_status'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                final payoutId =
                                    meta['nowpayments_payout_id']?.toString();
                                final reference = (w['reference'] ??
                                        w['transaction_reference'] ??
                                        w['id'] ??
                                        '-')
                                    .toString();
                                final nowpaymentsNeedsApproval =
                                    isNowpaymentsCrypto &&
                                        approvalStatus == 'pending';
                                final nowpaymentsNeedsRetry =
                                    isNowpaymentsCrypto &&
                                        approvalStatus == 'approved' &&
                                        (payoutId == null ||
                                            payoutId.isEmpty) &&
                                        ['creating', 'unknown']
                                            .contains(providerPayoutStatus);
                                final nowpaymentsNeedsVerification =
                                    isNowpaymentsCrypto &&
                                        approvalStatus == 'approved' &&
                                        payoutId != null &&
                                        payoutId.isNotEmpty &&
                                        providerPayoutStatus == 'creating' &&
                                        meta['nowpayments_payout_verified_at'] ==
                                            null;
                                final canManageNowpayments =
                                    nowpaymentsNeedsApproval ||
                                        nowpaymentsNeedsRetry ||
                                        nowpaymentsNeedsVerification;
                                final color = _sc(status);
                                final userLabel = _userLabel(w);
                                final userId = (w['user_id'] ?? '').toString();
                                final senderLabel =
                                    (w['sender_name'] ?? userLabel).toString();
                                final receiverLabel =
                                    (w['receiver_name'] ?? _destinationLabel(w))
                                        .toString();
                                final amountLabel = w['amount_display']
                                        ?.toString() ??
                                    '${double.tryParse(w['amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'} FARM';
                                final statusLabel =
                                    (w['status_display'] ?? w['status'] ?? '-')
                                        .toString()
                                        .toUpperCase();
                                final dateLabel = (w['date'] ?? '-').toString();
                                final timeLabel = (w['time'] ?? '-').toString();
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
                                      w,
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 14),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                          color: context.onSurface
                                              .withOpacity(0.1)),
                                    ),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                if (_selectedTransactions
                                                    .isNotEmpty)
                                                  Checkbox(
                                                    value: _selectedTransactions
                                                        .contains(i),
                                                    onChanged: (selected) =>
                                                        setState(() {
                                                      if (selected == true) {
                                                        _selectedTransactions
                                                            .add(i);
                                                      } else {
                                                        _selectedTransactions
                                                            .remove(i);
                                                      }
                                                    }),
                                                  ),
                                                Expanded(
                                                  child: Row(children: [
                                                    Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                          color: context
                                                              .errorColor
                                                              .withAlpha(
                                                                  (0.14 * 255)
                                                                      .round()),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10)),
                                                      child: Icon(
                                                          Icons
                                                              .north_east_rounded,
                                                          color: context
                                                              .errorColor,
                                                          size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                'User: $userLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .red)),
                                                            Text(
                                                                'User ID: ${userId.isNotEmpty ? userId : '-'}',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            Text(
                                                                'Sender: $senderLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            Text(
                                                                'Receiver: $receiverLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            Text(
                                                                'ID: $reference',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500)),
                                                            Text(
                                                                'Method: $method',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500)),
                                                            Text(
                                                                'Amount: $amountLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500)),
                                                            Text(
                                                                'Status: $statusLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        11)),
                                                            Text(
                                                                'Date: $dateLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        11)),
                                                            Text(
                                                                'Time: $timeLabel',
                                                                style: GoogleFonts.plusJakartaSans(
                                                                    color: context
                                                                        .onSurface
                                                                        .withOpacity(
                                                                            0.54),
                                                                    fontSize:
                                                                        11)),
                                                          ]),
                                                    ),
                                                  ]),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                      color: color.withAlpha(
                                                          (0.16 * 255).round()),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8)),
                                                  child: Text(statusLabel,
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                              color: color,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                ),
                                              ]),
                                          const SizedBox(height: 10),
                                          Text(
                                              'Destination: ${_destinationLabel(w)}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                      color: context.onSurface
                                                          .withOpacity(0.7),
                                                      fontSize: 12)),
                                          if ((w['rejectionReason'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              'Last failure: ${w['rejectionReason']}',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                color: context.errorColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          if (isPending ||
                                              canRetry ||
                                              canManageNowpayments) ...[
                                            const SizedBox(height: 12),
                                            Row(children: [
                                              if (isPending)
                                                Expanded(
                                                  child: OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                        side: BorderSide(
                                                            color: context
                                                                .errorColor),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10))),
                                                    onPressed: () =>
                                                        _rejectWithdrawal(
                                                            w['id'].toString()),
                                                    child: Text('Reject',
                                                        style: GoogleFonts
                                                            .plusJakartaSans(
                                                                color: context
                                                                    .errorColor)),
                                                  ),
                                                ),
                                              if (isPending)
                                                const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          context.successColor,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10))),
                                                  onPressed: () {
                                                    if (isNowpaymentsCrypto) {
                                                      _approveNowpaymentsWithdrawal(
                                                          reference);
                                                    } else {
                                                      _process(
                                                        w['id'].toString(),
                                                        'approve',
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                      nowpaymentsNeedsVerification
                                                          ? 'Verify payout'
                                                          : nowpaymentsNeedsRetry
                                                              ? 'Retry provider payout'
                                                              : canRetry
                                                                  ? 'Retry withdrawal'
                                                                  : 'Approve',
                                                      style: GoogleFonts
                                                          .plusJakartaSans(
                                                              color: Colors
                                                                  .black87)),
                                                ),
                                              ),
                                            ]),
                                          ],
                                          if (status == 'processing')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 12),
                                              child: Text(
                                                isNowpaymentsCrypto
                                                    ? 'NOWPayments crypto payout is awaiting provider confirmation.'
                                                    : 'Payout submitted; waiting for provider confirmation. It cannot be resubmitted while processing.',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  color: context.warningColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
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
                    hintText: 'Search username, user ID, withdrawal ID',
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
            for (final s in [
              'all',
              'pending',
              'processing',
              'completed',
              'failed'
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
