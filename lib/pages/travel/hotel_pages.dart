import 'dart:math';
import 'package:flutter/material.dart';
import '/backend/api_requests/travel_api.dart';
import '/pages/business/ops/ops_ui.dart';

/// Hotels (LiteAPI): search -> prebook (price check) -> PIN book -> my trips / cancel.
/// Shown only when the server reports hotels.enabled; prices and holds are computed server-side.

String hotelTitle(Map<String, dynamic> s) {
  final name = '${s['hotel_name'] ?? ''}'.trim();
  final dates = '${s['checkin'] ?? '-'} → ${s['checkout'] ?? '-'}';
  return name.isEmpty ? 'Hotel · $dates' : '$name · $dates';
}

String _key() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Only confirmed, refundable bookings offer a cancel button.
bool canCancelHotel(Map<String, dynamic> b) {
  final s = b['summary'] is Map ? b['summary'] as Map : const {};
  return '${b['status']}' == 'confirmed' && s['refundable'] != false;
}

String cancellationText(dynamic list, [dynamic refundable]) {
  final l = (list as List? ?? []).cast<Map>().where((p) => (p['amount'] as num? ?? 0) > 0).toList();
  if (l.isEmpty) return refundable == false ? 'Non-refundable' : 'Free cancellation';
  return l.map((p) => 'From ${p['cancel_time']}: ${p['currency']} ${p['amount']}').join('\n');
}

class HotelSearchForm extends StatefulWidget {
  const HotelSearchForm({super.key, required this.sandbox});
  final bool sandbox;
  @override
  State<HotelSearchForm> createState() => _HotelSearchFormState();
}

class _HotelSearchFormState extends State<HotelSearchForm> {
  final _city = TextEditingController(text: 'Nairobi');
  final _country = TextEditingController(text: 'KE');
  DateTime? _in;
  DateTime? _out;
  int _adults = 2;

  String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);
  Future<DateTime?> _pick(DateTime? init) => showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: init ?? DateTime.now().add(const Duration(days: 7)));

  void _search() {
    final city = _city.text.trim(), cc = _country.text.trim().toUpperCase();
    if (city.isEmpty || !RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return bizSnack(context, 'Enter a city and 2-letter country code, e.g. KE');
    if (_in == null || _out == null || !_out!.isAfter(_in!)) return bizSnack(context, 'Pick check-in and a later check-out');
    pushPage(context, HotelResultsPage(query: {'city_name': city, 'country_code': cc, 'checkin': _fmt(_in!), 'checkout': _fmt(_out!), 'adults': _adults}));
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.sandbox)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Test mode: results come from the provider sandbox. No real rooms are booked.', style: TextStyle(color: mutedColor(c), fontSize: 12)),
          ),
        BizCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(controller: _city, decoration: bizInput(c, 'City', hint: 'Nairobi')),
            const SizedBox(height: 10),
            TextField(controller: _country, textCapitalization: TextCapitalization.characters, decoration: bizInput(c, 'Country code', hint: 'KE')),
            const SizedBox(height: 10),
            BizTile(
              leading: Icons.login,
              title: _in == null ? 'Check-in' : 'Check-in ${_fmt(_in!)}',
              onTap: () async {
                final d = await _pick(_in);
                if (d != null) setState(() => _in = d);
              },
            ),
            BizTile(
              leading: Icons.logout,
              title: _out == null ? 'Check-out' : 'Check-out ${_fmt(_out!)}',
              onTap: () async {
                final d = await _pick(_out ?? _in?.add(const Duration(days: 1)));
                if (d != null) setState(() => _out = d);
              },
            ),
            Row(children: [
              Expanded(child: Text('Adults', style: TextStyle(color: fgColor(c)))),
              IconButton(icon: const Icon(Icons.remove), onPressed: _adults > 1 ? () => setState(() => _adults--) : null),
              Text('$_adults', style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700)),
              IconButton(icon: const Icon(Icons.add), onPressed: _adults < 6 ? () => setState(() => _adults++) : null),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        ElevatedButton(style: primaryButtonStyle(c), onPressed: _search, child: const Text('Search hotels')),
      ]);
}

class HotelResultsPage extends StatelessWidget {
  const HotelResultsPage({super.key, required this.query});
  final Map<String, dynamic> query;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: '${query['city_name']} hotels',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: () => TravelApi.hotelSearch(query),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.hotel_outlined,
          emptyTitle: 'No rooms found',
          emptyMessage: 'Try other dates or another city.',
          builder: (c, list, reload) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) {
              final h = list[i];
              return BizTile(
                leading: Icons.hotel_outlined,
                title: '${h['hotel_name']}${h['stars'] != null ? '  ${h['stars']}★' : ''}',
                subtitle: '${h['room_name']}${h['board'] != null ? ' · ${h['board']}' : ''}\n'
                    '${h['bookable'] == true ? '${money(h['price_farm'])}' : '${h['total_currency']} ${h['total_amount']} (not bookable in FARM)'}'
                    '${h['refundable'] == true ? ' · Refundable' : h['refundable'] == false ? ' · Non-refundable' : ''}',
                onTap: h['bookable'] == true ? () => pushPage(c, HotelCheckoutPage(offer: h)) : null,
              );
            },
          ),
        ),
      );
}

class HotelCheckoutPage extends StatelessWidget {
  const HotelCheckoutPage({super.key, required this.offer});
  final Map<String, dynamic> offer;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: '${offer['hotel_name']}',
        body: BizAsync<Map<String, dynamic>>(
          load: () => TravelApi.hotelPrebook('${offer['id']}'),
          builder: (c, pb, reload) => _Checkout(offer: offer, pb: pb),
        ),
      );
}

class _Checkout extends StatefulWidget {
  const _Checkout({required this.offer, required this.pb});
  final Map<String, dynamic> offer, pb;
  @override
  State<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<_Checkout> {
  final _first = TextEditingController(), _last = TextEditingController(), _email = TextEditingController(), _phone = TextEditingController();
  final String _idem = _key(); // one key per screen: retries never double-charge

  Future<void> _book() async {
    final pb = widget.pb;
    if (_first.text.trim().isEmpty || _last.text.trim().isEmpty) return bizSnack(context, 'Enter the guest name');
    if (!_email.text.contains('@')) return bizSnack(context, 'Enter a valid email');
    if (!RegExp(r'^\+\d{8,15}$').hasMatch(_phone.text.trim())) return bizSnack(context, 'Phone must be in +254… format');
    final pin = await confirmWithPin(context,
        title: 'Pay ${money(pb['price_farm'])}',
        message: 'Book ${widget.offer['hotel_name']} (${pb['checkin']} → ${pb['checkout']})?\n\n'
            'The amount is held from your FARM wallet and refunded in full if the hotel does not confirm.');
    if (pin == null || !mounted) return;
    final r = await runBusy(
        context,
        () => TravelApi.hotelBook({
              'prebook_id': pb['prebook_id'],
              'expected_total_farm': pb['price_farm'],
              'idempotency_key': _idem,
              'pin': pin,
              'guest': {'first_name': _first.text.trim(), 'last_name': _last.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim()},
            }));
    if (r != null && mounted) {
      Navigator.of(context).pop();
      pushPage(context, HotelBookingPage(id: '${r['id']}'));
    }
  }

  @override
  Widget build(BuildContext c) {
    final o = widget.offer, pb = widget.pb;
    return ListView(padding: const EdgeInsets.all(16), children: [
      BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o['hotel_name']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fgColor(c))),
          if (o['address'] != null) Text('${o['address']}', style: TextStyle(color: mutedColor(c))),
          const Divider(),
          KeyValue('Room', '${o['room_name']}'),
          if (o['board'] != null) KeyValue('Board', '${o['board']}'),
          KeyValue('Dates', '${pb['checkin']} → ${pb['checkout']}'),
          KeyValue('Hotel price', '${pb['total_currency']} ${pb['total_amount']}'),
          KeyValue('You pay', pb['bookable'] == true ? '${money(pb['price_farm'])}' : 'Not bookable in FARM'),
          KeyValue('Refundable', pb['refundable'] == true ? 'Yes' : pb['refundable'] == false ? 'No' : '-'),
          KeyValue('Cancellation', cancellationText(pb['cancel_policies'], pb['refundable'])),
        ]),
      ),
      if (pb['bookable'] == true) ...[
        const SizedBox(height: 16),
        BizCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lead guest', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
            const SizedBox(height: 8),
            TextField(controller: _first, decoration: bizInput(c, 'First name')),
            const SizedBox(height: 8),
            TextField(controller: _last, decoration: bizInput(c, 'Last name')),
            const SizedBox(height: 8),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: bizInput(c, 'Email')),
            const SizedBox(height: 8),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: bizInput(c, 'Phone', hint: '+2547…')),
          ]),
        ),
        const SizedBox(height: 12),
        ElevatedButton(style: primaryButtonStyle(c), onPressed: _book, child: const Text('Book with PIN')),
      ],
    ]);
  }
}

class HotelBookingPage extends StatelessWidget {
  const HotelBookingPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Hotel booking',
        body: BizAsync<Map<String, dynamic>>(
          load: () => TravelApi.booking(id),
          builder: (c, b, reload) => HotelBookingView(b: b, reload: reload, labels: const {}),
        ),
      );
}

class HotelBookingView extends StatelessWidget {
  const HotelBookingView({super.key, required this.b, required this.reload, required this.labels});
  final Map<String, dynamic> b;
  final Future<void> Function() reload;
  final Map<String, String> labels;

  Future<void> _cancel(BuildContext c) async {
    final s = Map<String, dynamic>.from(b['summary'] as Map? ?? {});
    final ok = await confirmAction(c,
        title: 'Cancel this booking?',
        message: 'Cancellation terms:\n${cancellationText(s['cancel_policies'], s['refundable'])}\n\nYou get back FARM for whatever the hotel refunds.',
        confirm: 'Cancel booking');
    if (!ok || !c.mounted) return;
    final r = await runBusy(c, () => TravelApi.hotelCancel('${b['id']}'));
    if (r != null) await reload();
  }

  @override
  Widget build(BuildContext c) {
    final s = Map<String, dynamic>.from(b['summary'] as Map? ?? {});
    final status = '${b['status']}';
    final note = {
      'confirmed': 'Your room is booked. Show the confirmation code at check-in.',
      'needs_review': 'We could not confirm the result with the hotel. Your FARM is held safely while we check.',
      'failed_refunded': 'The hotel did not confirm this booking. Your FARM was refunded in full.',
      'payment_held': 'We are confirming with the hotel.',
      'cancelled': 'This booking was cancelled. Any refund from the hotel was returned to your FARM wallet.',
      'cancelling': 'Cancelling with the hotel.',
    }[status];
    return ListView(padding: const EdgeInsets.all(16), children: [
      BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(hotelTitle(s), style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
            StatusChip(labels[status] ?? status, filled: status == 'confirmed'),
          ]),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note, style: TextStyle(color: mutedColor(c)))),
          const Divider(),
          if (b['booking_reference'] != null) KeyValue('Confirmation', '${b['booking_reference']}'),
          for (final p in (b['passengers'] as List? ?? []).cast<Map>()) KeyValue('Guest', '${p['given_name']} ${p['family_name']}'),
          KeyValue('Paid', '${money(b['total_farm'])}'),
          KeyValue('Hotel price', '${b['offer_currency']} ${b['offer_amount']}'),
          KeyValue('Cancellation', cancellationText(s['cancel_policies'], s['refundable'])),
          if (b['live_mode'] == false) KeyValue('Mode', 'Test (no real room)'),
        ]),
      ),
      if (canCancelHotel(b)) ...[
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => _cancel(c), child: const Text('Cancel booking')),
      ],
    ]);
  }
}
