import 'package:flutter/material.dart';

import '../services/admin_api_service.dart';
import '/utils/user_error_message.dart';

class FeeManagementPage extends StatefulWidget {
  const FeeManagementPage({required this.onGoBack, super.key});

  final VoidCallback onGoBack;

  @override
  State<FeeManagementPage> createState() => _FeeManagementPageState();
}

class _FeeManagementPageState extends State<FeeManagementPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _fees = [];

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
      final response = await AdminApiService.getFees();
      final rows = response['data'];
      if (rows is! List) {
        throw const FormatException('Fee configuration response was not a list.');
      }
      if (!mounted) return;
      setState(() {
        _fees = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editFee(Map<String, dynamic> fee) async {
    final id = fee['id']?.toString();
    if (id == null || id.isEmpty) return;
    final controller =
        TextEditingController(text: fee['value']?.toString() ?? '0');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Update ${fee['label'] ?? fee['name'] ?? fee['transaction_type'] ?? 'fee'} (%)',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Fee value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (double.tryParse(value.trim()) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid numeric fee value.')),
      );
      return;
    }

    try {
      await AdminApiService.updateFee(id, value.trim());
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update fee: ${userErrorMessage(error)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onGoBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Fees'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh fees',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _fees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _fees.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _fees.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('No fee configurations found.')),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _fees.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final fee = _fees[index];
                            final label = fee['label'] ?? fee['name'] ??
                                fee['transaction_type'] ?? fee['fee_type'] ??
                                fee['transaction_type'] ??
                                'Fee';
                            return Card(
                              child: ListTile(
                                title: Text(label.toString()),
                                subtitle: Text(
                                  '${fee['value'] ?? '0'}'
                                  '${fee['percentage_fee'] != null ? '%' : ''}',
                                ),
                                trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _editFee(fee),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
