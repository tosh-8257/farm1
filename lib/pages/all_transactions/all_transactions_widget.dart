import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:flutter/services.dart';

import '/backend/services/api_service.dart';
import '/core/responsive.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/transaction_receipt_service.dart';
import '/utils/transaction_peer_resolver.dart';
import '/utils/transaction_history_utils.dart';
import '/widgets/common/back_chevron.dart';
import 'all_transactions_model.dart';
import '/utils/user_error_message.dart';

export 'all_transactions_model.dart';

class AllTransactionsWidget extends StatefulWidget {
  const AllTransactionsWidget({super.key});

  static String routeName = 'AllTransactions';
  static String routePath = '/allTransactions';

  @override
  State<AllTransactionsWidget> createState() => _AllTransactionsWidgetState();
}

class _AllTransactionsWidgetState extends State<AllTransactionsWidget> {
  late AllTransactionsModel _model;

  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _transactions = [];
  String _selectedType = 'all';
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedTransactions = <int>{};
  String _search = '';

  List<Map<String, dynamic>> get _visibleTransactions {
    final needle = _search.trim().toLowerCase();
    if (needle.isEmpty) return _transactions;
    return _transactions.where((tx) {
      final values = [
        tx['transaction_id'],
        tx['transactionId'],
        tx['transaction_reference'],
        tx['reference'],
        tx['id'],
        tx['description'],
        tx['transaction_type'],
        tx['type'],
        tx['sender_username'],
        tx['recipient_username'],
        tx['merchant_business_name'],
        tx['status'],
        tx['amount'],
      ];
      return values.any(
          (value) => value?.toString().toLowerCase().contains(needle) == true);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AllTransactionsModel());
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _selectedReceipts => _selectedTransactions
      .where((index) => index >= 0 && index < _visibleTransactions.length)
      .map((index) => _visibleTransactions[index])
      .toList();

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
        SnackBar(content: Text('Could not save receipts: ${userErrorMessage(error)}')),
      );
    }
  }

  Future<void> _shareSelected() async {
    try {
      await TransactionReceiptService.shareReceipts(_selectedReceipts);
      if (!mounted) return;
      setState(() => _selectedTransactions.clear());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipts: ${userErrorMessage(error)}')),
      );
    }
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final response = await ApiService.getTransactions(
        page: 1,
        limit: 50,
        type: _selectedType == 'all' ? null : _selectedType,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );

      final raw = response['data'];
      final items = raw is List
          ? raw.map<Map<String, dynamic>>((item) {
              if (item is Map) {
                return Map<String, dynamic>.from(item);
              }
              return <String, dynamic>{};
            }).toList()
          : <Map<String, dynamic>>[];

      final filtered = items
          .where(isVisibleTransactionHistoryItem)
          .where(_matchesFilters)
          .toList();
      if (!mounted) return;
      setState(() {
        _transactions = filtered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(e);
        _loading = false;
      });
    }
  }

  bool _matchesFilters(Map<String, dynamic> tx) {
    if (_selectedType != 'all') {
      final type =
          (tx['transaction_type'] ?? tx['type'] ?? '').toString().toLowerCase();
      final isOutgoing = (tx['is_outgoing'] == true) ||
          type.contains('send') ||
          type.contains('sent') ||
          type.contains('outgoing');
      final isIncoming = !isOutgoing ||
          type.contains('receive') ||
          type.contains('received') ||
          type.contains('incoming');

      switch (_selectedType) {
        case 'send':
          if (!isOutgoing) return false;
          break;
        case 'receive':
          if (!isIncoming) return false;
          break;
        case 'deposit':
          if (!(type.contains('deposit') || type.contains('topup')))
            return false;
          break;
        case 'withdraw':
          if (!(type.contains('withdraw') || type.contains('withdrawal')))
            return false;
          break;
        default:
          break;
      }
    }

    if (_selectedStatus != 'all') {
      final status =
          (tx['status'] ?? tx['state'] ?? '').toString().toLowerCase();
      switch (_selectedStatus) {
        case 'completed':
          if (!(status.contains('complete') ||
              status.contains('success') ||
              status.contains('approved'))) return false;
          break;
        case 'pending':
          if (!(status.contains('pending') || status.contains('processing')))
            return false;
          break;
        case 'failed':
          if (!(status.contains('fail') ||
              status.contains('rejected') ||
              status.contains('error'))) return false;
          break;
        default:
          break;
      }
    }

    return true;
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return dateTimeFormatEastAfricanTime('MMM d, yyyy • h:mm a', parsed);
  }

  String _resolveTransactionPeer(Map<String, dynamic> tx,
      {required bool isOutgoing}) {
    return resolveTransactionPeer(tx, outgoing: isOutgoing);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
      case 'approved':
        return Colors.green;
      case 'pending':
      case 'processing':
        return Colors.orange;
      case 'failed':
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Transactions'),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: context.responsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your transaction history',
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ID, type, person, amount, or status',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _selectedTransactions.clear();
                              });
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {
                    _search = value;
                    _selectedTransactions.clear();
                  }),
                ),
                if (_selectedTransactions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${_selectedTransactions.length} selected'),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Share selected receipts',
                        icon: const Icon(Icons.share_rounded),
                        onPressed: _shareSelected,
                      ),
                      IconButton(
                        tooltip: 'Download selected receipts',
                        icon: const Icon(Icons.download_rounded),
                        onPressed: _downloadSelected,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip('All', 'all'),
                    _filterChip('Sent', 'send'),
                    _filterChip('Received', 'receive'),
                    _filterChip('Deposit', 'deposit'),
                    _filterChip('Withdraw', 'withdraw'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip('All', 'all'),
                    _statusChip('Completed', 'completed'),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading && _transactions.isEmpty)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator()))
                else if (_error.isNotEmpty && _transactions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  )
                else if (_visibleTransactions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No transactions match your filters yet.',
                          style: theme.bodyMedium),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _visibleTransactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tx = _visibleTransactions[index];
                      final type = (tx['transaction_type'] ??
                              tx['type'] ??
                              'Transaction')
                          .toString();
                      final amount = tx['amount'] ?? tx['value'] ?? 0;
                      final isOutgoing = tx['is_outgoing'] == true ||
                          type.toLowerCase().contains('send');
                      final status = (tx['status'] ?? 'Completed').toString();
                      final merchantName =
                          tx['merchant_business_name']?.toString().trim() ?? '';
                      final peer =
                          _resolveTransactionPeer(tx, isOutgoing: isOutgoing);
                      final payerUsername = !isOutgoing
                          ? (tx['sender_username']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? '@${tx['sender_username']}'
                              : peer)
                          : (tx['recipient_username']
                                      ?.toString()
                                      .trim()
                                      .isNotEmpty ==
                                  true
                              ? '@${tx['recipient_username']}'
                              : peer);
                      final peerWithMerchant = merchantName.isNotEmpty
                          ? '$payerUsername ($merchantName)'
                          : payerUsername;
                      final isMerchantPayment =
                          type.toLowerCase() == 'merchant_payment';
                      final amountText =
                          '${isOutgoing ? '-' : '+'}${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount} FARM';
                      final dateText = _formatDate(tx['created_at'] ??
                          tx['createdAt'] ??
                          tx['timestamp']);
                      final peerLabel = isMerchantPayment
                          ? '${isOutgoing ? 'To' : 'From'} $peerWithMerchant'
                          : '${isOutgoing ? 'To' : 'From'} $peer';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onLongPress: () => setState(() {
                          _selectedTransactions.add(index);
                        }),
                        onTap: () {
                          if (_selectedTransactions.isNotEmpty) {
                            setState(() {
                              if (!_selectedTransactions.add(index)) {
                                _selectedTransactions.remove(index);
                              }
                            });
                            return;
                          }
                          TransactionReceiptService.showDetails(
                            context,
                            tx,
                            fetchLatest: true,
                          );
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                if (_selectedTransactions.isNotEmpty)
                                  Checkbox(
                                    value:
                                        _selectedTransactions.contains(index),
                                    onChanged: (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedTransactions.add(index);
                                      } else {
                                        _selectedTransactions.remove(index);
                                      }
                                    }),
                                  ),
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: theme.secondaryBackground,
                                  child: Icon(
                                    isOutgoing
                                        ? Icons.north_east_rounded
                                        : Icons.south_west_rounded,
                                    color: theme.primaryText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              type,
                                              style: theme.titleSmall.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status)
                                                  .withAlpha(
                                                      (0.12 * 255).round()),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (TransactionReceiptService
                                              .transactionId(tx)
                                          .isNotEmpty)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'ID: ${TransactionReceiptService.transactionId(tx)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.bodySmall,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Copy transaction ID',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 18),
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(
                                                    text:
                                                        TransactionReceiptService
                                                            .transactionId(tx),
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'Transaction ID copied'),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tx['description']?.toString() ??
                                            tx['reference']?.toString() ??
                                            'Transaction updated',
                                        style: theme.bodyMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$peerLabel • $dateText',
                                        style: theme.bodySmall.copyWith(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatDate(tx['created_at'] ??
                                                  tx['createdAt'] ??
                                                  tx['timestamp']),
                                              style: theme.bodySmall,
                                            ),
                                          ),
                                          Text(
                                            amountText,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: isOutgoing
                                                  ? Colors.redAccent
                                                  : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _selectedType == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.accent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: selected
            ? AppTheme.onAccent
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      shape: const StadiumBorder(),
      onSelected: (_) {
        setState(() => _selectedType = value);
        _loadTransactions();
      },
    );
  }

  Widget _statusChip(String label, String value) {
    final selected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppTheme.accent,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: selected
            ? AppTheme.onAccent
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      shape: const StadiumBorder(),
      onSelected: (_) {
        setState(() => _selectedStatus = value);
        _loadTransactions();
      },
    );
  }
}
