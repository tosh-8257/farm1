import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/backend/api_requests/chain_wallet_api.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/investments/investment_pages.dart' show openDoc;
import 'package:qr_flutter/qr_flutter.dart';

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
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text('Algorand address',
                            style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(net == 'testnet' ? 'TestNet' : net, filled: net != 'testnet'),
                  ]),
                  const SizedBox(height: 6),
                  Text('Receive ALGO, USDC and FARM to this address on the Algorand network.',
                      style: TextStyle(fontSize: 13, color: fgColor(c))),
                  const SizedBox(height: 12),
                  if (ready)
                    Center(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(10),
                        child: QrImageView(
                          data: '${w['address']}',
                          size: 200,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                          dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                          semanticsLabel: 'QR code of your Algorand address',
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SelectableText('${w['address']}',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: fgColor(c))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: primaryButtonStyle(c),
                        onPressed: ready
                            ? () async {
                                await Clipboard.setData(ClipboardData(text: '${w['address']}'));
                                if (c.mounted) bizSnack(c, 'Address copied');
                              }
                            : null,
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy address'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: secondaryButtonStyle(c),
                      onPressed: () => openDoc(c, '${w['explorer_url']}'),
                      child: const Text('Explorer'),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    ready
                        ? 'Only send on the Algorand network. Tokens sent from other networks, or tokens other than ALGO, USDC (asset ${w['usdc_asa_id']}) and FARM (asset ${w['farm_asa_id']}), may be lost.\n• ALGO and USDC are converted to FARM automatically at the live KSh rate.\n• FARM is credited 1:1 (1 FARM = 1 KSh).'
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
              SizedBox(
                height: 320,
                child: BizAsync<List<Map<String, dynamic>>>(
                  load: ChainWalletApi.deposits,
                  isEmpty: (l) => l.isEmpty,
                  emptyIcon: Icons.south_west,
                  emptyTitle: 'Nothing received yet',
                  emptyMessage: 'ALGO, USDC or FARM sent to this address shows here.',
                  builder: (c2, l, _) => ListView(children: [
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
                        onTap: () => openDoc(c2, '${d['tx_url']}'),
                      ),
                  ]),
                ),
              ),
            ]);
          },
        ),
      );
}
