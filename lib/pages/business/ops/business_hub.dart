import '/components/farm_coin_icon.dart';
import 'package:flutter/material.dart';
import '/backend/api_requests/business_ops_api.dart';
import 'ops_ui.dart';
import 'developer_pages.dart';
import 'money_pages.dart';
import 'commerce_pages.dart';
import 'escrow_pages.dart';
import 'team_pages.dart';
import 'project_pages.dart';
import '/pages/agent_payments/agent_payments_pages.dart';
import '/pages/x402/x402_pages.dart';

/// Approved-business home: real summary numbers plus the tools the
/// signed-in user's role is allowed to use.
class BusinessHub extends StatefulWidget {
  const BusinessHub({super.key, required this.context});
  final Map<String, dynamic> context;

  @override
  State<BusinessHub> createState() => _BusinessHubState();
}

class _BusinessHubState extends State<BusinessHub> {
  final _key = GlobalKey<BizAsyncState<Map<String, dynamic>>>();

  Set<String> get _perms =>
      ((widget.context['permissions'] as List?) ?? const []).map((e) => '$e').toSet();

  @override
  Widget build(BuildContext context) {
    final role = '${widget.context['role'] ?? ''}';
    final name = '${widget.context['name'] ?? 'Your business'}';
    final tools = <(String, IconData, String, Widget Function())>[
      ('wallet:read', Icons.account_balance_wallet_outlined, 'Wallet', () => const BusinessWalletPage()),
      ('transactions:read', Icons.swap_vert_rounded, 'Transactions', () => const BusinessTransactionsPage()),
      ('links:read', Icons.link_rounded, 'Payment links', () => const PaymentLinksPage()),
      ('links:read', Icons.request_page_outlined, 'Payment requests', () => const BusinessIntentsPage()),
      ('links:read', Icons.api_outlined, 'Paid APIs (x402)', () => const X402ResourcesPage()),
      ('invoices:read', Icons.receipt_long_outlined, 'Invoices', () => const InvoicesPage()),
      ('customers:read', Icons.people_outline, 'Customers', () => const CustomersPage()),
      ('payouts:read', Icons.north_east_rounded, 'Payouts', () => const PayoutsPage()),
      ('escrow:read', Icons.verified_user_outlined, 'Escrow', () => const BusinessEscrowsPage()),
      ('analytics:read', Icons.insights_outlined, 'Analytics', () => const AnalyticsPage()),
      ('team:read', Icons.groups_outlined, 'Team', () => const TeamPage()),
      ('profile:read', Icons.storefront_outlined, 'Business profile', () => const BusinessProfilePage()),
      ('developers:read', Icons.code_rounded, 'Developer API', () => const DeveloperHomePage()),
      ('projects:read', Icons.account_tree_outlined, 'Projects', () => const BusinessProjectsPage()),
    ].where((t) => _perms.contains(t.$1)).toList();

    return BizAsync<Map<String, dynamic>>(
      key: _key,
      load: BusinessOpsApi.dashboard,
      cacheKey: 'dashboard',
      builder: (ctx, d, reload) {
        final w = d['wallet'] as Map?;
        final m = d['last_30_days'] as Map?;
        final inv = (d['open_invoices'] as Map?) ?? {};
        final recent = (d['recent_payments'] as List?) ?? const [];
        return ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            BizCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(ctx))),
                  ),
                  StatusChip(businessRoleLabels[role] ?? role, filled: true),
                ]),
                if (w != null) ...[
                  const SizedBox(height: 16),
                  Text(w['kind'] == 'business' ? 'Business balance' : 'Available balance', style: TextStyle(color: mutedColor(ctx))),
                  const SizedBox(height: 4),
                  Row(children: [
                    if ('${w['currency'] ?? 'FARM'}' == 'FARM') ...[const FarmCoinIcon(size: 28), const SizedBox(width: 10)],
                    Flexible(child: Text(money(w['available_balance'], '${w['currency'] ?? 'FARM'}'),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: fgColor(ctx)))),
                  ]),
                ],
                if (m != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last 30 days: ${money(m['received'])} received · ${m['payments_count']} payments',
                    style: TextStyle(color: mutedColor(ctx)),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _stat(ctx, 'Open invoices', '${inv['count'] ?? 0}'),
              const SizedBox(width: 10),
              _stat(ctx, 'Active links', '${d['active_payment_links'] ?? 0}'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _stat(ctx, 'Pending payouts', '${d['pending_payouts'] ?? 0}'),
              const SizedBox(width: 10),
              _stat(ctx, 'Open escrows', '${d['open_escrows'] ?? 0}'),
            ]),
            const SizedBox(height: 20),
            Text('Tools', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(ctx))),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                for (final t in tools)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      await pushPage(ctx, t.$4());
                      _key.currentState?.reload();
                    },
                    child: BizCard(
                      padding: const EdgeInsets.all(10),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(t.$2, color: fgColor(ctx)),
                        const SizedBox(height: 8),
                        Text(t.$3,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: fgColor(ctx), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Recent business payments', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(ctx))),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Text('No payments yet. Share a payment link or send an invoice to get paid.',
                  style: TextStyle(color: mutedColor(ctx)))
            else
              for (final p in recent.whereType<Map>())
                BizTile(
                  title: money(p['amount']),
                  subtitle: '${p['source'] == 'invoice' ? 'Invoice' : p['source'] == 'payment_intent' ? 'Payment request' : 'Payment link'} · ${shortDate(p['created_at'])}',
                  trailing: const StatusChip('Successful'),
                ),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext c, String label, String value) => Expanded(
        child: BizCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fgColor(c))),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: mutedColor(c))),
          ]),
        ),
      );
}
