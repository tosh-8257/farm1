import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/backend/services/api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';
// Removed unused imports

class AllRequestsWidget extends StatefulWidget {
  final List<dynamic> pendingRequests;
  final List<dynamic> myTransferRequests;

  const AllRequestsWidget({
    super.key,
    this.pendingRequests = const [],
    this.myTransferRequests = const [],
  });

  @override
  State<AllRequestsWidget> createState() => _AllRequestsWidgetState();
}

class _AllRequestsWidgetState extends State<AllRequestsWidget> {
  late List<dynamic> pending;
  late List<dynamic> outgoing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    pending = List<dynamic>.from(widget.pendingRequests);
    outgoing = List<dynamic>.from(widget.myTransferRequests);
  }

  Future<void> _cancel(String id) async {
    try {
      setState(() => _loading = true);
      await ApiService.request(method: 'POST', path: '/payment-requests/$id/cancel');
      setState(() {
        outgoing.removeWhere((r) => r['id'] == id);
        pending.removeWhere((r) => r['id'] == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorMessage(e))));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: Text('common.requests'.tr()),
        backgroundColor: theme.primaryBackground,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('common.pending_requests'.tr(), style: theme.titleLarge),
                    const SizedBox(height: 12),
                    ...pending.map((req) => _buildIncoming(req)).toList(),
                  ],
                  if (outgoing.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('common.your_requests'.tr(), style: theme.titleLarge),
                    const SizedBox(height: 12),
                    ...outgoing.map((req) => _buildOutgoing(req)).toList(),
                  ],
                  if (pending.isEmpty && outgoing.isEmpty)
                    Center(child: Text('common.no_requests'.tr(), style: theme.bodyMedium)),
                ],
              ),
            ),
    );
  }

  Widget _buildIncoming(dynamic req) {
    final requester = req['users_requester'];
    final requesterUsername = requester != null ? requester['username'] : 'unknown';
    final amount = (req['amount'] ?? 0).toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.call_received)),
        title: Text('@$requesterUsername requested'),
        subtitle: Text('${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount} FARM'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          OutlinedButton(onPressed: () => _cancel(req['id']), child: const Text('Reject')),
        ]),
      ),
    );
  }

  Widget _buildOutgoing(dynamic req) {
    final recipient = req['users_recipient'];
    final recipientUsername = recipient != null ? recipient['username'] : 'unknown';
    final amount = (req['amount'] ?? 0).toString();
    final status = (req['status'] ?? 'pending').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.call_made)),
        title: Text('You requested'),
        subtitle: Text('@$recipientUsername'),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount} FARM', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(status.toUpperCase(), style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            OutlinedButton(onPressed: () => _cancel(req['id']), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
