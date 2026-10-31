import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/chain_wallet_api.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/investments/investment_pages.dart' show openDoc;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '/core/app_theme.dart';

const _depositLabels = {
  'detected': 'Confirming',
  'pending_rate': 'Waiting for rate',
  'credited': 'Credited',
  'failed': 'Failed',
};

/// Receive on Algorand: the user's on-chain receiving address (ALGO, USDC, FARM).
/// Not a deposit method — it is reachable from the Receive panel and Profile.
class WalletAddressPage extends StatelessWidget {
  const WalletAddressPage({super.key});

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Receive on Algorand',
        body: BizAsync<Map<String, dynamic>>(
          load: ChainWalletApi.mine,
          isEmpty: (r) => r['data'] is! Map,
          emptyIcon: Icons.account_balance_wallet_outlined,
          emptyTitle: 'Not available yet',
          emptyMessage: 'Your FARM Algorand address will appear here once this feature is switched on.',
          builder: (c, r, reload) {
            final w = Map<String, dynamic>.from(r['data'] as Map);
            final ready = w['ready'] == true;
            final net = '${w['network']}';
            final address = '${w['address']}';
            Future<void> copy() async {
              await Clipboard.setData(ClipboardData(text: address));
              if (c.mounted) bizSnack(c, 'Address copied');
            }

            return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                        child: Text('Algorand address',
                            style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(net == 'testnet' ? 'TestNet' : net, filled: net != 'testnet'),
                  ]),
                  const SizedBox(height: 12),
                  if (ready) ...[
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(12),
                        child: QrImageView(
                          data: address,
                          size: 200,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                          semanticsLabel: 'QR code of your Algorand address',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      address,
                      key: const ValueKey('wallet-address-text'),
                      textAlign: TextAlign.center,
                      onTap: copy,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: fgColor(c)),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const ValueKey('copy-address-button'),
                      style: AppTheme.primaryButtonStyle().merge(primaryButtonStyle(c)).copyWith(
                            backgroundColor: const WidgetStatePropertyAll(AppTheme.accent),
                            foregroundColor: const WidgetStatePropertyAll(AppTheme.onAccent),
                          ),
                      onPressed: copy,
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy address'),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: secondaryButtonStyle(c),
                          onPressed: () => SharePlus.instance.share(
                              ShareParams(text: 'My FARM Algorand address: $address')),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: secondaryButtonStyle(c),
                          onPressed: () => openDoc(c, '${w['explorer_url']}'),
                          child: const Text('Explorer'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    ready
                        ? 'Receive ALGO, USDC and FARM to this address on the Algorand network only. Tokens sent from other networks, or tokens other than ALGO, USDC (asset ${w['usdc_asa_id']}) and FARM (asset ${w['farm_asa_id']}), may be lost.\n• ALGO and USDC are converted to FARM automatically at the live KSh rate.\n• FARM is credited 1:1 (1 FARM = 1 KSh).'
                        : 'Setting up your address. Do not send funds until this finishes.',
                    style: TextStyle(fontSize: 12, color: mutedColor(c)),
                  ),
                  if (!ready)
                    TextButton(onPressed: reload, child: Text('Refresh', style: TextStyle(color: fgColor(c)))),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Received', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
              const SizedBox(height: 8),
              const _ReceivedList(),
            ]);
          },
        ),
      );
}

/// Compact, non-scrolling list of on-chain deposits (sits inside the page's
/// ListView, so no fixed-height box or nested scroll view).
class _ReceivedList extends StatefulWidget {
  const _ReceivedList();
  @override
  State<_ReceivedList> createState() => _ReceivedListState();
}

class _ReceivedListState extends State<_ReceivedList> {
  late final Future<List<Map<String, dynamic>>> _future = ChainWalletApi.deposits();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
                padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final l = snap.data ?? const [];
          if (snap.hasError || l.isEmpty) {
            return Text(
                snap.hasError
                    ? "Couldn't load received transfers."
                    : 'Nothing received yet. ALGO, USDC or FARM sent to this address shows here.',
                style: TextStyle(fontSize: 13, color: mutedColor(c)));
          }
          return Column(children: [
            for (final d in l)
              BizTile(
                title: '${d['amount']} ${d['asset']}',
                subtitle: [
                  shortDate(d['created_at']),
                  if (d['farm_amount'] != null)
                    d['asset'] == 'FARM'
                        ? '= ${money(d['farm_amount'])} (1:1)'
                        : '= ${money(d['farm_amount'])} @ ${d['rate_kes']} KSh',
                ].join(' · '),
                trailing: StatusChip(_depositLabels['${d['status']}'] ?? '${d['status']}',
                    filled: d['status'] == 'credited'),
                onTap: () => openDoc(c, '${d['tx_url']}'),
              ),
          ]);
        },
      );
}
