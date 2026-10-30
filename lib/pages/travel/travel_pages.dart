import 'dart:math';
import 'package:flutter/material.dart';
import '/backend/api_requests/travel_api.dart';
import '/pages/business/ops/ops_ui.dart';
import 'hotel_pages.dart';

const _bookingLabels = {
  'payment_held': 'Processing',
  'confirmed': 'Confirmed',
  'needs_review': 'Under review',
  'refunding': 'Refunding',
  'failed_refunded': 'Refunded',
  'cancelling': 'Cancelling',
  'cancelled': 'Cancelled',
};

String _time(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  if (d == null) return '-';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${shortDate(iso)} ${two(d.hour)}:${two(d.minute)}';
}

String _route(Map<String, dynamic> o) {
  final s = (o['slices'] as List? ?? []).cast<Map>();
  if (s.isEmpty) return 'Flight';
  return s.map((x) => '${x['origin']} → ${x['destination']}').join('  ·  ');
}

String _newKey() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Entry: search form, gated on server status.
class TravelHomePage extends StatelessWidget {
  const TravelHomePage({super.key});
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Travel',
        actions: [
          IconButton(
              tooltip: 'My bookings',
              icon: const Icon(Icons.confirmation_number_outlined),
              onPressed: () => pushPage(c, const TravelBookingsPage())),
        ],
        body: BizAsync<Map<String, dynamic>>(
          load: TravelApi.status,
          builder: (c, s, reload) {
            final flightsOn = s['enabled'] == true;
            final hotelsOn = (s['hotels'] as Map?)?['enabled'] == true;
            if (!flightsOn && !hotelsOn) {
              return BizMessage(
                  icon: Icons.flight_outlined,
                  title: 'Travel is not available yet',
                  message: 'Flight booking will appear here once it is switched on.',
                  action: reload,
                  actionLabel: 'Check again');
            }
            final sandbox = (s['flights'] as Map?)?['sandbox'] == true;
            final hotelSandbox = (s['hotels'] as Map?)?['sandbox'] == true;
            return _Categories(sandbox: sandbox, flightsOn: flightsOn, hotelsOn: hotelsOn, hotelSandbox: hotelSandbox);
          },
        ),
      );
}

/// Master prompt travel categories. Only flights have a connected provider; the rest are provider-ready.
const _categories = <(String, IconData)>[
  ('Flights', Icons.flight_outlined),
  ('Hotels', Icons.hotel_outlined),
  ('Transport', Icons.directions_bus_outlined),
  ('Car rental', Icons.directions_car_outlined),
  ('Airport transfers', Icons.local_taxi_outlined),
  ('Activities', Icons.local_activity_outlined),
  ('Other', Icons.more_horiz),
];

class _Categories extends StatefulWidget {
  const _Categories({required this.sandbox, required this.flightsOn, required this.hotelsOn, required this.hotelSandbox});
  final bool sandbox, flightsOn, hotelsOn, hotelSandbox;
  @override
  State<_Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<_Categories> {
  late String _sel = widget.flightsOn ? 'Flights' : 'Hotels';
  @override
  Widget build(BuildContext c) => Column(children: [
        SizedBox(
          height: 56,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 10, 16, 6), children: [
            for (final (name, icon) in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(icon, size: 16, color: _sel == name ? Theme.of(c).scaffoldBackgroundColor : fgColor(c)),
                  label: Text(name),
                  selected: _sel == name,
                  selectedColor: fgColor(c),
                  labelStyle: TextStyle(color: _sel == name ? Theme.of(c).scaffoldBackgroundColor : fgColor(c)),
                  onSelected: (_) => setState(() => _sel = name),
                ),
              ),
          ]),
        ),
        Expanded(
          child: _sel == 'Flights' && widget.flightsOn
              ? _SearchForm(sandbox: widget.sandbox)
              : _sel == 'Hotels' && widget.hotelsOn
                  ? HotelSearchForm(sandbox: widget.hotelSandbox)
                  : BizMessage(
                  icon: _categories.firstWhere((e) => e.$1 == _sel).$2,
                  title: '$_sel not available yet',
                  message: 'We will show $_sel here once a provider is connected. Nothing is listed until it can really be booked.',
                ),
        ),
      ]);
}

class _SearchForm extends StatefulWidget {
  const _SearchForm({required this.sandbox});
  final bool sandbox;
  @override
  State<_SearchForm> createState() => _SearchFormState();
}

class _SearchFormState extends State<_SearchForm> {
  final _from = TextEditingController(text: 'NBO');
  final _to = TextEditingController();
  DateTime? _depart;
  DateTime? _return;
  int _adults = 1;
  String _cabin = 'economy';

  Future<DateTime?> _pick(DateTime? init) => showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 330)),
      initialDate: init ?? DateTime.now().add(const Duration(days: 7)));

  String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

  void _search() {
    final from = _from.text.trim().toUpperCase(), to = _to.text.trim().toUpperCase();
    final iata = RegExp(r'^[A-Z]{3}$');
    if (!iata.hasMatch(from) || !iata.hasMatch(to)) return bizSnack(context, 'Use 3-letter airport codes, e.g. NBO, MBA');
    if (_depart == null) return bizSnack(context, 'Pick a departure date');
    pushPage(
        context,
        TravelResultsPage(query: {
          'origin': from,
          'destination': to,
          'departure_date': _fmt(_depart!),
          if (_return != null) 'return_date': _fmt(_return!),
          'adults': _adults,
          'cabin_class': _cabin,
        }));
  }

  @override
  Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.sandbox)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Test mode: results come from the provider sandbox. No real tickets are issued.',
                style: TextStyle(color: mutedColor(c), fontSize: 12)),
          ),
        BizCard(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            TextField(controller: _from, textCapitalization: TextCapitalization.characters, decoration: bizInput(c, 'From', hint: 'NBO')),
            const SizedBox(height: 10),
            TextField(controller: _to, textCapitalization: TextCapitalization.characters, decoration: bizInput(c, 'To', hint: 'MBA')),
            const SizedBox(height: 10),
            BizTile(
              leading: Icons.event_outlined,
              title: _depart == null ? 'Departure date' : 'Depart ${_fmt(_depart!)}',
              onTap: () async {
                final d = await _pick(_depart);
                if (d != null) setState(() => _depart = d);
              },
            ),
            BizTile(
              leading: Icons.event_repeat_outlined,
              title: _return == null ? 'Return date (optional)' : 'Return ${_fmt(_return!)}',
              trailing: _return == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _return = null)),
              onTap: () async {
                final d = await _pick(_return ?? _depart);
                if (d != null) setState(() => _return = d);
              },
            ),
            Row(children: [
              Expanded(child: Text('Adults', style: TextStyle(color: fgColor(c)))),
              IconButton(icon: const Icon(Icons.remove), onPressed: _adults > 1 ? () => setState(() => _adults--) : null),
              Text('$_adults', style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w700)),
              IconButton(icon: const Icon(Icons.add), onPressed: _adults < 9 ? () => setState(() => _adults++) : null),
            ]),
            DropdownButtonFormField<String>(
              initialValue: _cabin,
              decoration: bizInput(c, 'Cabin'),
              items: const [
                DropdownMenuItem(value: 'economy', child: Text('Economy')),
                DropdownMenuItem(value: 'premium_economy', child: Text('Premium economy')),
                DropdownMenuItem(value: 'business', child: Text('Business')),
                DropdownMenuItem(value: 'first', child: Text('First')),
              ],
              onChanged: (v) => setState(() => _cabin = v ?? 'economy'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        ElevatedButton(style: primaryButtonStyle(c), onPressed: _search, child: const Text('Search flights')),
      ]);
}

class TravelResultsPage extends StatelessWidget {
  const TravelResultsPage({super.key, required this.query});
  final Map<String, dynamic> query;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: '${query['origin']} → ${query['destination']}',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: () => TravelApi.search(query),
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.flight_outlined,
          emptyTitle: 'No flights found',
          emptyMessage: 'Try another date or route.',
          builder: (c, list, reload) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => _OfferCard(list[i], onTap: () => pushPage(c, TravelOfferPage(offerId: '${list[i]['id']}', adults: query['adults'] as int? ?? 1))),
          ),
        ),
      );
}

class _OfferCard extends StatelessWidget {
  const _OfferCard(this.o, {this.onTap});
  final Map<String, dynamic> o;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) {
    final slices = (o['slices'] as List? ?? []).cast<Map>();
    return InkWell(
      onTap: onTap,
      child: BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${o['owner']}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
            Text(o['bookable'] == true ? '${money(o['price_farm'])} FARM' : 'Not bookable',
                style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
          ]),
          const SizedBox(height: 6),
          for (final s in slices)
            Text(
                '${s['origin']} → ${s['destination']}  ·  ${_time((s['segments'] as List?)?.first['departing_at'])}'
                '  ·  ${((s['segments'] as List?)?.length ?? 1) - 1 == 0 ? 'Direct' : '${(s['segments'] as List).length - 1} stop(s)'}',
                style: TextStyle(color: mutedColor(c), fontSize: 13)),
          Text('${o['total_currency']} ${o['total_amount']}', style: TextStyle(color: mutedColor(c), fontSize: 12)),
        ]),
      ),
    );
  }
}

/// Offer details, passengers and PIN booking. [aiActionId] links a Mkulima proposal.
class TravelOfferPage extends StatelessWidget {
  const TravelOfferPage({super.key, required this.offerId, this.adults = 1, this.aiActionId});
  final String offerId;
  final int adults;
  final String? aiActionId;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Flight details',
        body: BizAsync<Map<String, dynamic>>(
          load: () => TravelApi.offer(offerId),
          builder: (c, o, reload) => _OfferDetails(o: o, aiActionId: aiActionId),
        ),
      );
}

class _OfferDetails extends StatefulWidget {
  const _OfferDetails({required this.o, this.aiActionId});
  final Map<String, dynamic> o;
  final String? aiActionId;
  @override
  State<_OfferDetails> createState() => _OfferDetailsState();
}

class _Pax {
  final title = ValueNotifier<String>('mr');
  final gender = ValueNotifier<String>('m');
  final given = TextEditingController();
  final family = TextEditingController();
  final born = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
}

class _OfferDetailsState extends State<_OfferDetails> {
  late final List<_Pax> _pax = List.generate((widget.o['passengers'] as List? ?? [1]).length, (_) => _Pax());
  final String _key = _newKey(); // one key per screen: retries never double-charge

  Future<void> _book() async {
    final o = widget.o;
    final ids = (o['passengers'] as List? ?? []).cast<Map>().map((p) => '${p['id']}').toList();
    final passengers = <Map<String, dynamic>>[];
    for (var i = 0; i < _pax.length; i++) {
      final p = _pax[i];
      if (p.given.text.trim().isEmpty || p.family.text.trim().isEmpty) return bizSnack(context, 'Enter names as on the passport/ID');
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(p.born.text.trim())) return bizSnack(context, 'Date of birth must be YYYY-MM-DD');
      if (!p.email.text.contains('@')) return bizSnack(context, 'Enter a valid email');
      if (!RegExp(r'^\+\d{8,15}$').hasMatch(p.phone.text.trim())) return bizSnack(context, 'Phone must be in +254… format');
      passengers.add({
        'id': ids.length > i ? ids[i] : '',
        'title': p.title.value,
        'gender': p.gender.value,
        'given_name': p.given.text.trim(),
        'family_name': p.family.text.trim(),
        'born_on': p.born.text.trim(),
        'email': p.email.text.trim(),
        'phone_number': p.phone.text.trim(),
      });
    }
    final pin = await confirmWithPin(context,
        title: 'Pay ${money(o['price_farm'])} FARM',
        message: 'Book ${_route(o)} with ${o['owner']}?\n\nThe amount is held from your FARM wallet and refunded in full if the airline does not confirm.');
    if (pin == null || !mounted) return;
    final r = await runBusy(
        context,
        () => TravelApi.book({
              'offer_id': o['id'],
              'passengers': passengers,
              'expected_total_farm': o['price_farm'],
              'pin': pin,
              'idempotency_key': _key,
              if (widget.aiActionId != null) 'ai_action_id': widget.aiActionId,
            }));
    if (r != null && mounted) {
      Navigator.of(context).pop();
      pushPage(context, TravelBookingPage(id: '${r['id']}'));
    }
  }

  @override
  Widget build(BuildContext c) {
    final o = widget.o;
    final slices = (o['slices'] as List? ?? []).cast<Map>();
    return ListView(padding: const EdgeInsets.all(16), children: [
      BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o['owner']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: fgColor(c))),
          const SizedBox(height: 8),
          for (final s in slices)
            for (final g in (s['segments'] as List? ?? []).cast<Map>())
              KeyValue('${g['flight_number']}  ${g['origin']} → ${g['destination']}', '${_time(g['departing_at'])} – ${_time(g['arriving_at'])}'),
          const Divider(),
          KeyValue('Airline price', '${o['total_currency']} ${o['total_amount']}'),
          if (o['service_fee_farm'] != null && (o['service_fee_farm'] as num) > 0) KeyValue('Service fee', '${money(o['service_fee_farm'])} FARM'),
          KeyValue('You pay', o['bookable'] == true ? '${money(o['price_farm'])} FARM' : 'Not bookable in FARM'),
          if (o['refundable'] != null) KeyValue('Refundable', o['refundable'] == true ? 'Yes' : 'No'),
          if (o['expires_at'] != null) KeyValue('Price held until', _time(o['expires_at'])),
        ]),
      ),
      if (o['bookable'] == true) ...[
        const SizedBox(height: 16),
        for (var i = 0; i < _pax.length; i++) _paxForm(c, i),
        const SizedBox(height: 8),
        ElevatedButton(style: primaryButtonStyle(c), onPressed: _book, child: const Text('Book with PIN')),
      ],
    ]);
  }

  Widget _paxForm(BuildContext c, int i) {
    final p = _pax[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Passenger ${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: p.title,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  decoration: bizInput(c, 'Title'),
                  items: const ['mr', 'ms', 'mrs', 'miss', 'dr'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                  onChanged: (x) => p.title.value = x ?? 'mr',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: p.gender,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  decoration: bizInput(c, 'Gender'),
                  items: const [DropdownMenuItem(value: 'm', child: Text('Male')), DropdownMenuItem(value: 'f', child: Text('Female'))],
                  onChanged: (x) => p.gender.value = x ?? 'm',
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextField(controller: p.given, decoration: bizInput(c, 'Given names')),
          const SizedBox(height: 8),
          TextField(controller: p.family, decoration: bizInput(c, 'Surname')),
          const SizedBox(height: 8),
          TextField(controller: p.born, keyboardType: TextInputType.datetime, decoration: bizInput(c, 'Date of birth', hint: 'YYYY-MM-DD')),
          const SizedBox(height: 8),
          TextField(controller: p.email, keyboardType: TextInputType.emailAddress, decoration: bizInput(c, 'Email')),
          const SizedBox(height: 8),
          TextField(controller: p.phone, keyboardType: TextInputType.phone, decoration: bizInput(c, 'Phone', hint: '+2547…')),
        ]),
      ),
    );
  }
}

class TravelBookingsPage extends StatelessWidget {
  const TravelBookingsPage({super.key});
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'My trips',
        body: BizAsync<List<Map<String, dynamic>>>(
          load: TravelApi.bookings,
          isEmpty: (l) => l.isEmpty,
          emptyIcon: Icons.luggage_outlined,
          emptyTitle: 'No bookings yet',
          emptyMessage: 'Flights and hotels you book appear here.',
          builder: (c, list, reload) => RefreshIndicator(
            onRefresh: reload,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final b in list)
                BizTile(
                  leading: b['kind'] == 'hotel' ? Icons.hotel_outlined : Icons.flight_takeoff,
                  title: b['kind'] == 'hotel'
                      ? hotelTitle(Map<String, dynamic>.from(b['summary'] as Map? ?? {}))
                      : _route(Map<String, dynamic>.from(b['summary'] as Map? ?? {})),
                  subtitle: '${money(b['total_farm'])} FARM · ${shortDate(b['created_at'])}',
                  trailing: StatusChip(_bookingLabels['${b['status']}'] ?? '${b['status']}', filled: b['status'] == 'confirmed'),
                  onTap: () => pushPage(c, TravelBookingPage(id: '${b['id']}')),
                ),
            ]),
          ),
        ),
      );
}

class TravelBookingPage extends StatelessWidget {
  const TravelBookingPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c) => BizScaffold(
        title: 'Booking',
        body: BizAsync<Map<String, dynamic>>(
          load: () => TravelApi.booking(id),
          builder: (c, b, reload) {
            if (b['kind'] == 'hotel') return HotelBookingView(b: b, reload: reload, labels: _bookingLabels);
            final s = Map<String, dynamic>.from(b['summary'] as Map? ?? {});
            final status = '${b['status']}';
            final note = {
              'confirmed': 'Your flight is booked. Use the booking reference with the airline.',
              'needs_review': 'We could not confirm the result with the airline. Your FARM is held safely while we check, and it will be ticketed or refunded.',
              'failed_refunded': 'The airline did not confirm this booking. Your FARM was refunded in full.',
              'payment_held': 'We are confirming with the airline.',
              'refunding': 'Your refund is being processed.',
            }[status];
            return ListView(padding: const EdgeInsets.all(16), children: [
              BizCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_route(s), style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(c)))),
                    StatusChip(_bookingLabels[status] ?? status, filled: status == 'confirmed'),
                  ]),
                  if (note != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note, style: TextStyle(color: mutedColor(c)))),
                  const Divider(),
                  if (b['booking_reference'] != null) KeyValue('Booking reference', '${b['booking_reference']}'),
                  KeyValue('Airline', '${s['owner'] ?? '-'}'),
                  for (final sl in (s['slices'] as List? ?? []).cast<Map>())
                    for (final g in (sl['segments'] as List? ?? []).cast<Map>())
                      KeyValue('${g['flight_number']}  ${g['origin']} → ${g['destination']}', _time(g['departing_at'])),
                  for (final p in (b['passengers'] as List? ?? []).cast<Map>()) KeyValue('Passenger', '${p['given_name']} ${p['family_name']}'),
                  KeyValue('Paid', '${money(b['total_farm'])} FARM'),
                  KeyValue('Airline price', '${b['offer_currency']} ${b['offer_amount']}'),
                  if (b['live_mode'] == false) KeyValue('Mode', 'Test (no real ticket)'),
                  KeyValue('Booked', _time(b['created_at'])),
                ]),
              ),
            ]);
          },
        ),
      );
}
