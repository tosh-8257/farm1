import 'package:flutter/material.dart';
import '/backend/api_requests/nfc_pay_api.dart';
import '/pages/tap_pay/tap_pay_pages.dart';

/// "Pay by tap / Receive by tap" buttons. Hidden unless the backend flag is on.
class TapPayEntry extends StatefulWidget {
  const TapPayEntry({super.key});
  @override
  State<TapPayEntry> createState() => _TapPayEntryState();
}

class _TapPayEntryState extends State<TapPayEntry> {
  late final Future<bool> _on = NfcPayApi.enabled().catchError((_) => false);
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _on,
        builder: (c, s) => s.data != true
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('tap-pay-entry'),
                      icon: const Icon(Icons.contactless_outlined),
                      label: const Text('Pay by tap'),
                      onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const TapPayPage())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('tap-receive-entry'),
                      icon: const Icon(Icons.contactless_outlined),
                      label: const Text('Receive by tap'),
                      onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const TapReceivePage())),
                    ),
                  ),
                ]),
              ),
      );
}
