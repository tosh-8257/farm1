import 'package:flutter/material.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/transaction_receipt_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class MerchantSalesWidget extends StatefulWidget {
  const MerchantSalesWidget({super.key});

  static String routeName = 'MerchantSales';
  static String routePath = '/merchantSales';

  @override
  State<MerchantSalesWidget> createState() => _MerchantSalesWidgetState();
}

class _MerchantSalesWidgetState extends State<MerchantSalesWidget> {
  bool loading = true;
  String error = '';
  List<Map<String, dynamic>> sales = [];
  final Set<int> _selectedSales = <int>{};
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  List<Map<String, dynamic>> get _visibleSales {
    final needle = _search.trim().toLowerCase();
    if (needle.isEmpty) return sales;
    return sales.where((tx) {
      final haystack = [
        tx['id'],
        tx['transaction_id'],
        tx['transactionId'],
        tx['transaction_reference'],
        tx['reference'],
        tx['description'],
        tx['transaction_type'],
        tx['type'],
        tx['sender_username'],
        tx['customer_name'],
        tx['customer_email'],
        tx['guest_email'],
        if (tx['metadata'] is Map) ...[
          (tx['metadata'] as Map)['guest_email'],
          (tx['metadata'] as Map)['customer_email'],
          (tx['metadata'] as Map)['payer_email'],
        ],
        tx['merchant_business_name'],
        tx['status'],
        tx['amount'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(needle);
    }).toList();
  }

  Future<void> _downloadSelected() async {
    final selected = _selectedSales
        .where((index) => index >= 0 && index < _visibleSales.length)
        .map((index) => _visibleSales[index])
        .toList();
    try {
      await TransactionReceiptService.downloadReceipts(selected);
      if (mounted) {
        setState(() => _selectedSales.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected receipts saved to gallery')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save receipts: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final response = await ApiService.getTransactions(
          type: 'merchant_payment', page: 1, limit: 100);
      final raw = response['data'];
      final items = raw is List
          ? raw.map<Map<String, dynamic>>((item) {
              if (item is Map) return Map<String, dynamic>.from(item);
              return <String, dynamic>{};
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        sales = items;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = userErrorMessage(e);
        loading = false;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return dateTimeFormatEastAfricanTime('MMM d, yyyy • h:mm a', parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Sales History'),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryText),
      ),
      backgroundColor: theme.primaryBackground,
      body: RefreshIndicator(
        onRefresh: _loadSales,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Merchant sales recorded by customer',
                          style: theme.titleMedium
                              .copyWith(fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: () => context.pushNamed('ReceiptHistory'),
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Receipts'),
                    ),
                  ],
                ),
                if (_selectedSales.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label:
                          Text('Download selected (${_selectedSales.length})'),
                      onPressed: _downloadSelected,
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search sales by ID, customer, amount, or status',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _selectedSales.clear();
                              });
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() {
                    _search = value;
                    _selectedSales.clear();
                  }),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.redAccent))
                else if (_visibleSales.isEmpty)
                  Text('No sales records available.', style: theme.bodyMedium)
                else
                  Column(
                    children: _visibleSales.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tx = entry.value;
                      final amount = tx['amount']?.toString() ?? '0';
                      final metadata = tx['metadata'] is Map
                          ? Map<String, dynamic>.from(tx['metadata'] as Map)
                          : const <String, dynamic>{};
                      final payerEmail = [
                        tx['customer_email'],
                        tx['guest_email'],
                        tx['payer_email'],
                        metadata['guest_email'],
                        metadata['customer_email'],
                        metadata['payer_email'],
                      ]
                          .map((value) => value?.toString().trim() ?? '')
                          .firstWhere((value) => value.isNotEmpty,
                              orElse: () => '');
                      final payerUsername = tx['sender_username']
                                  ?.toString()
                                  .trim()
                                  .isNotEmpty ==
                              true
                          ? '@${tx['sender_username']}'
                          : tx['customer_name']?.toString().trim().isNotEmpty ==
                                  true
                              ? tx['customer_name']
                              : tx['username']?.toString().trim().isNotEmpty ==
                                      true
                                  ? '@${tx['username']}'
                                  : payerEmail.isNotEmpty
                                      ? payerEmail
                                      : 'Unknown';
                      final merchantName =
                          tx['merchant_business_name']?.toString().trim();
                      final title =
                          merchantName != null && merchantName.isNotEmpty
                              ? '$payerUsername • $merchantName'
                              : payerUsername;
                      final status = tx['status']?.toString() ?? 'Unknown';
                      final date = _formatDate(tx['created_at'] ??
                          tx['createdAt'] ??
                          tx['timestamp']);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onLongPress: () => setState(() {
                          _selectedSales.add(index);
                        }),
                        onTap: () {
                          if (_selectedSales.isNotEmpty) {
                            setState(() {
                              if (!_selectedSales.add(index)) {
                                _selectedSales.remove(index);
                              }
                            });
                            return;
                          }
                          TransactionReceiptService.showDetails(context, tx);
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedSales.isNotEmpty)
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    value: _selectedSales.contains(index),
                                    title: const Text('Select receipt'),
                                    onChanged: (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedSales.add(index);
                                      } else {
                                        _selectedSales.remove(index);
                                      }
                                    }),
                                  ),
                                Text(title,
                                    style: theme.titleSmall
                                        .copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Amount: $amount FARM',
                                    style: theme.bodyMedium),
                                const SizedBox(height: 4),
                                Text('Status: $status',
                                    style: theme.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(date,
                                    style: theme.bodySmall
                                        .copyWith(color: theme.secondaryText)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
