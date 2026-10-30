import 'package:flutter/material.dart';
import '/backend/api_requests/ai_api.dart';
import '/pages/agent_payments/agent_payments_pages.dart';
import '/pages/assistant/assistant_pages.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/travel/travel_pages.dart';

/// Mkulima section: AI Agent, Travel, Services, Payments, Activity.
class MkulimaHubPage extends StatelessWidget {
  const MkulimaHubPage({super.key});
  @override
  Widget build(BuildContext c) {
    final items = <(IconData, String, String, Widget Function())>[
      (Icons.smart_toy_outlined, 'AI Agent', 'Chat with Mkulima', () => const AssistantChatPage()),
      (Icons.flight_outlined, 'Travel', 'Flights, hotels and more', () => const TravelHomePage()),
      (Icons.miscellaneous_services_outlined, 'Services', 'Bookable services', () => const MkulimaServicesPage()),
      (Icons.account_balance_wallet_outlined, 'Payments', 'Limits, categories and approvals', () => const AssistantSettingsPage()),
      (Icons.history_rounded, 'Activity', 'Everything Mkulima did', () => const MkulimaActivityPage()),
    ];
    return BizScaffold(
      title: 'Mkulima',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final (icon, title, sub, page) in items)
          BizTile(leading: icon, title: title, subtitle: sub, onTap: () => pushPage(c, page())),
        BizTile(
          leading: Icons.verified_user_outlined,
          title: 'Agent payments',
          subtitle: 'Business agents you have authorized',
          onTap: () => pushPage(c, const AgentPaymentsHomePage()),
        ),
      ]),
    );
  }
}

/// No service providers are connected yet; nothing is shown that cannot be booked.
class MkulimaServicesPage extends StatelessWidget {
  const MkulimaServicesPage({super.key});
  @override
  Widget build(BuildContext c) => const BizScaffold(
        title: 'Services',
        body: BizMessage(
          icon: Icons.miscellaneous_services_outlined,
          title: 'Services are not available yet',
          message: 'Bookable services will appear here once a provider is connected. Mkulima can already pay business payment requests you approve.',
        ),
      );
}

const _statusFilled = {'Completed'};

class MkulimaActivityPage extends StatelessWidget {
  const MkulimaActivityPage({super.key});

  void _open(BuildContext c, Map<String, dynamic> a) => showModalBottomSheet(
        context: c,
        builder: (ctx) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Expanded(child: Text('${a['agent_action']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fgColor(ctx)))),
              StatusChip('${a['status']}', filled: _statusFilled.contains(a['status'])),
            ]),
            const Divider(),
            if (a['request'] != null) KeyValue('Request', '${a['request']}'),
            KeyValue('Agent action', '${a['agent_action']}'),
            if (a['category'] != null) KeyValue('Category', '${a['category']}'),
            KeyValue('Provider', '${a['provider'] ?? '-'}'),
            KeyValue('Amount', '${money(a['amount'])}'),
            KeyValue('Payment method', '${a['payment_method']}'),
            KeyValue('Status', '${a['status']}'),
            KeyValue('Time', shortDate(a['timestamp'])),
            KeyValue('Booking ref', '${a['booking_ref'] ?? '-'}'),
            KeyValue('Confirmation', '${a['confirmation'] ?? '-'}'),
            KeyValue('Refund status', '${a['refund_status'] ?? '-'}'),
            if (a['failure_reason'] != null) KeyValue('Note', '${a['failure_reason']}'),
          ]),
        ),
      );

  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Activity',
        actions: [
          IconButton(tooltip: 'Audit log', icon: const Icon(Icons.receipt_long_outlined), onPressed: () => pushPage(c, const AssistantAuditPage())),
        ],
        body: BizAsync<List<Map<String, dynamic>>>(
          load: AiApi.activity,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.history_rounded,
          emptyTitle: 'No activity yet',
          emptyMessage: 'Payments and bookings Mkulima prepares for you appear here.',
          builder: (c, l, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final a in l)
                BizTile(
                  leading: Icons.bolt_outlined,
                  title: '${a['agent_action']} · ${money(a['amount'])}',
                  subtitle: '${a['provider'] ?? ''} · ${shortDate(a['timestamp'])}${a['booking_ref'] != null ? ' · ${a['booking_ref']}' : ''}',
                  trailing: StatusChip('${a['status']}', filled: _statusFilled.contains(a['status'])),
                  onTap: () => _open(c, a),
                ),
            ]),
          ),
        ),
      );
}
