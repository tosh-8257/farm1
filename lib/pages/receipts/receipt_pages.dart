import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/services/api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class ReceiptHistoryPage extends StatefulWidget {
  const ReceiptHistoryPage({super.key});

  @override
  State<ReceiptHistoryPage> createState() => _ReceiptHistoryPageState();
}

class _ReceiptHistoryPageState extends State<ReceiptHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _receipts = [];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getReceipts();
      final data = response['data'];
      if (data is! List) {
        throw const FormatException('Receipt list was not returned.');
      }
      if (!mounted) return;
      setState(() {
        _receipts = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Receipt History'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReceipts,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 100),
                      Center(child: Text(_error!)),
                    ],
                  )
                : _receipts.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No payment receipts yet.')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _receipts.length,
                        itemBuilder: (context, index) {
                          final receipt = _receipts[index];
                          final receiptId = receipt['id']?.toString() ?? '';
                          return Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF167346),
                              ),
                              title: Text(
                                receipt['receipt_number']?.toString() ??
                                    'FARM receipt',
                              ),
                              subtitle: Text(
                                '${receipt['merchant_name'] ?? 'Merchant'} • '
                                '${receipt['amount'] ?? 0} '
                                '${receipt['currency'] ?? 'FARM'}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: receiptId.isEmpty
                                  ? null
                                  : () => context.pushNamed(
                                        'ReceiptDetails',
                                        queryParameters: {
                                          'receiptId': receiptId,
                                        },
                                      ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class ReceiptDetailsPage extends StatefulWidget {
  const ReceiptDetailsPage({super.key, required this.receiptId});

  final String receiptId;

  @override
  State<ReceiptDetailsPage> createState() => _ReceiptDetailsPageState();
}

class _ReceiptDetailsPageState extends State<ReceiptDetailsPage> {
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    try {
      final response = await ApiService.getReceipt(widget.receiptId);
      final data = response['data'];
      if (data is! Map) {
        throw const FormatException('Receipt details were not returned.');
      }
      if (!mounted) return;
      setState(() {
        _receipt = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final response = await ApiService.getReceiptDownloadUrl(widget.receiptId);
      final data = response['data'];
      final url = data is Map ? data['url']?.toString() : null;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the private receipt download link.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download receipt: ${userErrorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Receipt Details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ))
              : receipt == null
                  ? const Center(child: Text('Receipt not found.'))
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Color(0xFF167346),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          receipt['receipt_number']?.toString() ??
                              'FARM receipt',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        _ReceiptValue(
                          label: 'Merchant',
                          value: receipt['merchant_name']?.toString() ??
                              'Merchant',
                        ),
                        _ReceiptValue(
                          label: 'Amount',
                          value:
                              '${receipt['amount'] ?? 0} ${receipt['currency'] ?? 'FARM'}',
                        ),
                        _ReceiptValue(
                          label: 'Fee',
                          value:
                              '${receipt['fee'] ?? 0} ${receipt['currency'] ?? 'FARM'}',
                        ),
                        _ReceiptValue(
                          label: 'Payer email',
                          value: receipt['payer_email']?.toString() ??
                              'Not provided',
                        ),
                        _ReceiptValue(
                          label: 'Transaction reference',
                          value: receipt['transaction_reference']?.toString() ??
                              '',
                        ),
                        _ReceiptValue(
                          label: 'Status',
                          value: receipt['status']?.toString() ?? 'completed',
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _downloading ? null : _downloadPdf,
                          icon: _downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _downloading ? 'Preparing PDF...' : 'Download PDF',
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ReceiptValue extends StatelessWidget {
  const _ReceiptValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Theme.of(context).textTheme.labelLarge),
      subtitle: SelectableText(value),
    );
  }
}
