import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api_service.dart';
import '../services/admin_page_refresh_coordinator.dart';
import '/utils/user_error_message.dart';

class PayoutsPage extends StatefulWidget {
  final VoidCallback? onGoBack;
  const PayoutsPage({super.key, this.onGoBack});
  @override
  State<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends State<PayoutsPage>
    with AdminPageRefreshMixin<PayoutsPage> {
  List<dynamic> _payouts = [];
  bool _loading = true;
  String _status = 'pending';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await AdminApiService.getPayouts(status: _status == 'all' ? null : _status);
      if (mounted) setState(() => _payouts = response['data'] ?? []);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Future<void> refreshAdminPage() => _load();

  Future<void> _process(String id, String status) async {
    try {
      await AdminApiService.processPayout(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'completed' ? 'Payout approved' : 'Payout rejected')));
      _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        for (final value in ['pending', 'completed', 'failed', 'all'])
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(value.toUpperCase()), selected: _status == value, onSelected: (_) { setState(() => _status = value); _load(); }),
          ),
      ]),
    ),
    if (_loading && _payouts.isEmpty)
      const Expanded(child: Center(child: CircularProgressIndicator()))
    else if (_payouts.isEmpty)
      const Expanded(child: Center(child: Text('No payouts found')))
    else
      Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _payouts.length,
        itemBuilder: (_, index) {
          final payout = Map<String, dynamic>.from(_payouts[index] as Map);
          final status = payout['status']?.toString() ?? 'pending';
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Payout ${payout['id'] ?? '-'}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            Text('Merchant: ${payout['merchant_id'] ?? '-'}'),
            Text('Amount: ${payout['amount'] ?? 0} FARM'),
            Text('Method: ${payout['payout_method'] ?? '-'}'),
            Text('Status: ${status.toUpperCase()}'),
            if (status == 'pending') Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _process(payout['id'].toString(), 'failed'), child: const Text('Reject'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(onPressed: () => _process(payout['id'].toString(), 'completed'), child: const Text('Approve'))),
            ]),
          ])));
        },
      ))),
  ]);
}
