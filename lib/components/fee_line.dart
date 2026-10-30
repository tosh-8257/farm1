import 'package:flutter/material.dart';
import '/backend/api_requests/fees_api.dart';

/// Live "Fee / Total" line for a fee key, computed from the backend fee schedule.
/// Shows loading and error states; never guesses a rate.
class FeeLine extends StatefulWidget {
  const FeeLine({super.key, required this.feeKey, required this.amount, this.payerPays = true, this.label});
  final String feeKey;
  final double amount;
  /// true: fee added to what the user pays; false: fee deducted from what the receiver gets.
  final bool payerPays;
  final String? label;
  @override
  State<FeeLine> createState() => _FeeLineState();
}

class _FeeLineState extends State<FeeLine> {
  late Future<FeeRule> _f = FeesApi.rule(widget.feeKey);
  @override
  Widget build(BuildContext c) {
    final muted = Theme.of(c).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey;
    final style = TextStyle(fontSize: 13, color: muted);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: FutureBuilder<FeeRule>(
        future: _f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) {
            return Text('Loading fee…', key: const Key('fee-line-loading'), style: style);
          }
          if (s.hasError || s.data == null) {
            return InkWell(
              key: const Key('fee-line-error'),
              onTap: () => setState(() => _f = FeesApi.rule(widget.feeKey)),
              child: Text('Fee unavailable. Tap to retry.', style: style),
            );
          }
          final r = s.data!;
          final amt = widget.amount > 0 ? widget.amount : 0.0;
          final fee = r.feeFor(amt);
          final total = widget.payerPays ? amt + fee : amt - fee;
          return Text(
            '${widget.label ?? 'Fee'} (${r.percentLabel}): ${fee.toStringAsFixed(2)} FARM · '
            '${widget.payerPays ? 'Total' : 'Receiver gets'}: ${total.toStringAsFixed(2)} FARM',
            key: const Key('fee-line'),
            style: style,
          );
        },
      ),
    );
  }
}
