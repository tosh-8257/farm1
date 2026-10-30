import 'package:flutter/material.dart';
import '/backend/api_requests/travel_api.dart';
import '/pages/business/ops/ops_ui.dart';

/// Admin: resolve travel bookings stuck in review. Check the Duffel dashboard first; every decision is audited.
class TravelReviewPage extends StatefulWidget {
  const TravelReviewPage({super.key, this.onGoBack});
  final VoidCallback? onGoBack;
  @override
  State<TravelReviewPage> createState() => _TravelReviewPageState();
}

const _filters = {'open': 'Open', 'needs_review': 'Needs review', 'confirmed': 'Confirmed', 'failed_refunded': 'Refunded'};

class _TravelReviewPageState extends State<TravelReviewPage> {
  String _filter = 'open';
  int _gen = 0;

  String _route(Map b) {
    final s = ((b['summary'] as Map?)?['slices'] as List? ?? []).cast<Map>();
    return s.isEmpty ? 'Flight' : s.map((x) => '${x['origin']} → ${x['destination']}').join(' · ');
  }

  Future<void> _resolve(BuildContext c, Map<String, dynamic> b, String action) async {
    final ref = TextEditingController(), order = TextEditingController(), note = TextEditingController();
    final ok = await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(action == 'confirm' ? 'Confirm booking' : 'Refund in full'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              action == 'confirm'
                  ? 'Only confirm if the order exists in the Duffel dashboard.'
                  : 'Refund ${money(b['total_farm'])} FARM to the user. Only do this if no order exists in Duffel.',
              style: TextStyle(color: mutedColor(d))),
          const SizedBox(height: 10),
          if (action == 'confirm') ...[
            TextField(controller: ref, textCapitalization: TextCapitalization.characters, decoration: bizInput(d, 'Booking reference (PNR)')),
            const SizedBox(height: 8),
            TextField(controller: order, decoration: bizInput(d, 'Duffel order id (optional)', hint: 'ord_…')),
            const SizedBox(height: 8),
          ],
          TextField(controller: note, maxLines: 2, decoration: bizInput(d, 'Note (required, audited)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(style: primaryButtonStyle(d), onPressed: () => Navigator.pop(d, true), child: Text(action == 'confirm' ? 'Confirm' : 'Refund')),
        ],
      ),
    );
    if (ok != true || !c.mounted) return;
    final r = await runBusy(
        c,
        () => AdminTravelApi.resolve('${b['id']}', {
              'action': action,
              'note': note.text.trim(),
              if (action == 'confirm') 'booking_reference': ref.text.trim(),
              if (action == 'confirm' && order.text.trim().isNotEmpty) 'provider_order_id': order.text.trim(),
            }),
        success: action == 'confirm' ? 'Booking confirmed' : 'Refunded');
    if (r != null) setState(() => _gen++);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: Theme.of(c).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Theme.of(c).scaffoldBackgroundColor,
          foregroundColor: fgColor(c),
          leading: widget.onGoBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onGoBack),
          title: Text('Travel review', style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700)),
        ),
        body: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              for (final e in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) => setState(() => _filter = e.key)),
                ),
            ]),
          ),
          Expanded(
            child: BizAsync<List<Map<String, dynamic>>>(
              key: ValueKey('$_filter$_gen'),
              load: () => AdminTravelApi.bookings(status: _filter == 'open' ? null : _filter),
              isEmpty: (l) => l.isEmpty,
              emptyIcon: Icons.flight_outlined,
              emptyTitle: 'Nothing to review',
              emptyMessage: 'Bookings with an unknown airline result appear here.',
              builder: (c, list, reload) => ListView(padding: const EdgeInsets.all(16), children: [
                for (final b in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BizCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_route(b), style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                          StatusChip('${b['status']}', filled: b['status'] == 'confirmed'),
                        ]),
                        const SizedBox(height: 6),
                        KeyValue('Held', '${money(b['total_farm'])} FARM'),
                        KeyValue('Airline price', '${b['offer_currency']} ${b['offer_amount']}'),
                        KeyValue('Offer', '${b['provider_offer_id'] ?? '-'}'),
                        if (b['provider_order_id'] != null) KeyValue('Order', '${b['provider_order_id']}'),
                        if (b['booking_reference'] != null) KeyValue('PNR', '${b['booking_reference']}'),
                        KeyValue('Booking id', '${b['id']}'),
                        KeyValue('User', '${b['user_id']}'),
                        KeyValue('Created', shortDate(b['created_at'])),
                        if (b['failure_reason'] != null) KeyValue('Reason', '${b['failure_reason']}'),
                        if (b['live_mode'] == false) KeyValue('Mode', 'Sandbox'),
                        if (b['status'] == 'needs_review' || b['status'] == 'payment_held') ...[
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: OutlinedButton(style: secondaryButtonStyle(c), onPressed: () => _resolve(c, b, 'refund'), child: const Text('Refund'))),
                            const SizedBox(width: 8),
                            Expanded(child: ElevatedButton(style: primaryButtonStyle(c), onPressed: () => _resolve(c, b, 'confirm'), child: const Text('Confirm'))),
                          ]),
                        ],
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      );
}
