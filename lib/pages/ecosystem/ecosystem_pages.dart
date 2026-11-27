import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/pages/business/ops/ops_ui.dart';
import 'ecosystem_api.dart';
import 'ecosystem_flows.dart';
import 'ecosystem_logic.dart';

String _key() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Entry points that stay hidden until the matching backend phase answers.
class EcosystemTools extends StatefulWidget {
  const EcosystemTools({super.key, this.preview});
  final EcosystemFlags? preview;

  @override
  State<EcosystemTools> createState() => _EcosystemToolsState();
}

class _EcosystemToolsState extends State<EcosystemTools> {
  EcosystemFlags? _flags;

  @override
  void initState() {
    super.initState();
    if (widget.preview != null) {
      _flags = widget.preview;
      return;
    }
    EcosystemApi.flags().then((flags) {
      if (mounted) setState(() => _flags = flags);
    }).catchError((_) {
      if (mounted) setState(() => _flags = EcosystemFlags.hidden);
    });
  }

  @override
  Widget build(BuildContext context) {
    final flags = _flags;
    if (flags == null || !flags.any) return const SizedBox.shrink();
    final tiles = <(String, IconData, Widget)>[
      if (flags.dropship || flags.catalogue || flags.orders)
        (
          'Dropshipping',
          Icons.storefront_outlined,
          DropshipPage(catalogue: flags.catalogue, orders: flags.orders),
        ),
      if (flags.orders || flags.dropship) ('Dropshipping sales', Icons.insights_outlined, const DropshipSalesPage()),
      if (flags.dropship) ('Supplier', Icons.inventory_2_outlined, const SupplierPage()),
      if (flags.stores) ('Store connections', Icons.shopping_bag_outlined, StoreConnectionsPage(flags: flags)),
      if (flags.cargo || flags.cargoList)
        ('FARM Cargo', Icons.local_shipping_outlined, CargoPage(history: flags.cargoList, addresses: flags.cargoList)),
      if (flags.partnerPortal || flags.partnerApply)
        ('Partner portal', Icons.badge_outlined, PartnerPortalPage()),
      if (flags.dispatch || flags.partnerApply) ('Delivery partner', Icons.badge_outlined, PartnerPage(apply: flags.partnerApply)),
      if (flags.cargoAdmin) ('Cargo rates', Icons.tune, const CargoAdminPage()),
      if (flags.settlement) ('Settlements', Icons.account_balance_outlined, const SettlementPage()),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('New tools', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 8),
        for (final tile in tiles)
          BizTile(
            leading: tile.$2,
            title: tile.$1,
            subtitle: 'Available on this server',
            onTap: () => pushPage(context, tile.$3),
          ),
      ]),
    );
  }
}

class _RecordTiles extends StatelessWidget {
  const _RecordTiles(this.rows, {required this.onTap});
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic> row) onTap;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return Text('None yet.', style: TextStyle(color: mutedColor(context)));
    return Column(children: [
      for (final row in rows)
        BizTile(
          title: '${row['name'] ?? row['trading_name'] ?? row['id'] ?? 'Record'}',
          subtitle: [
            row['status'],
            row['sku'],
            row['from_zone'],
            row['to_zone'],
            row['wholesale_price'] ?? row['price_farm'],
          ].where((part) => part != null && '$part'.isNotEmpty).join(' · '),
          onTap: () => onTap(row),
        ),
    ]);
  }
}

class _Result extends StatelessWidget {
  const _Result(this.value);
  final Map<String, dynamic>? value;
  @override
  Widget build(BuildContext context) {
    final map = value;
    if (map == null) return const SizedBox.shrink();
    final data = map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : map;
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final entry in data.entries)
          if (entry.value is! Map && entry.value is! List)
            KeyValue('${entry.key}'.replaceAll('_', ' '), '${entry.value}'),
      ]),
    );
  }
}

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});
  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  final _name = TextEditingController();
  final _region = TextEditingController();
  final _fulfilment = TextEditingController();
  String _kind = 'individual';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    _fulfilment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Supplier',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Apply with your existing account. This does not create a new account type.'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _kind,
          decoration: bizInput(context, 'Kind'),
          items: const [
            DropdownMenuItem(value: 'individual', child: Text('Individual')),
            DropdownMenuItem(value: 'business', child: Text('Business')),
          ],
          onChanged: (value) => setState(() => _kind = value ?? 'individual'),
        ),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: bizInput(context, 'Legal name')),
        const SizedBox(height: 8),
        TextField(controller: _region, decoration: bizInput(context, 'Region (optional)')),
        const SizedBox(height: 12),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_name.text.trim().length < 2) {
              bizSnack(context, 'Enter the legal name');
              return;
            }
            final result = await runBusy(
              context,
              () => EcosystemApi.applySupplier(kind: _kind, legalName: _name.text.trim(), region: _region.text.trim()),
              success: 'Application sent',
            );
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Submit application'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            final result = await runBusy(context, EcosystemApi.mySupplier);
            if (mounted) setState(() => _result = result);
          },
          child: const Text('View my supplier profile'),
        ),
        const SizedBox(height: 16),
        TextField(controller: _fulfilment, decoration: bizInput(context, 'Fulfilment ID')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () => _decide('rejected'),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: primaryButtonStyle(context),
              onPressed: () => _decide('accepted'),
              child: const Text('Accept'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _Result(_result),
      ]),
    );
  }

  Future<void> _decide(String decision) async {
    final id = _fulfilment.text.trim();
    if (id.isEmpty) {
      bizSnack(context, 'Enter the fulfilment ID');
      return;
    }
    final result = await runBusy(context, () => EcosystemApi.supplierDecision(id, decision));
    if (mounted) setState(() => _result = result);
  }
}

class DropshipPage extends StatefulWidget {
  const DropshipPage({super.key, this.catalogue = false, this.orders = false});
  final bool catalogue;
  final bool orders;
  @override
  State<DropshipPage> createState() => _DropshipPageState();
}

class _DropshipPageState extends State<DropshipPage> {
  final _variant = TextEditingController();
  final _retail = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _order = TextEditingController();
  final _reason = TextEditingController();
  final _search = TextEditingController();
  String? _orderKey;
  String? _payKey;
  String? _caseKey;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _catalogue = const [];
  List<Map<String, dynamic>> _orders = const [];

  @override
  void dispose() {
    _variant.dispose();
    _retail.dispose();
    _qty.dispose();
    _order.dispose();
    _reason.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Dropshipping',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          widget.catalogue
              ? 'The catalogue lists active products from approved suppliers. Commission is shown only when the server has a rate. Nothing is added that the server did not return.'
              : 'Import an approved supplier variant by ID. This server has no catalogue list. Commission is shown only when the server has a rate.',
        ),
        const SizedBox(height: 12),
        if (widget.catalogue) ...[
          TextField(controller: _search, decoration: bizInput(context, 'Search catalogue')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              final result = await runBusy(
                context,
                () => EcosystemApi.catalogue(query: _search.text.trim()),
              );
              if (mounted) setState(() => _catalogue = recordList(result));
            },
            child: const Text('Load catalogue'),
          ),
          const SizedBox(height: 8),
          _RecordTiles(_catalogue, onTap: (row) {
            final variants = row['variants'];
            final first = variants is List && variants.isNotEmpty && variants.first is Map ? variants.first as Map : row;
            _variant.text = '${first['id'] ?? row['variant_id'] ?? ''}';
            setState(() {});
          }),
          const SizedBox(height: 12),
        ],
        TextField(controller: _variant, decoration: bizInput(context, 'Variant ID')),
        const SizedBox(height: 8),
        TextField(
          controller: _retail,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: bizInput(context, 'Retail price (FARM)'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _qty,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: bizInput(context, 'Quantity'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            final price = num.tryParse(_retail.text);
            if (_variant.text.trim().isEmpty || price == null || price <= 0) {
              bizSnack(context, 'Enter a variant and a retail price');
              return;
            }
            final result = await runBusy(
              context,
              () => EcosystemApi.importListing(variantId: _variant.text.trim(), retailPrice: price),
              success: 'Listing imported',
            );
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Import listing'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            final price = num.tryParse(_retail.text);
            final qty = int.tryParse(_qty.text);
            if (_variant.text.trim().isEmpty || price == null || qty == null || qty < 1) {
              bizSnack(context, 'Enter a variant, quantity, and retail price');
              return;
            }
            _orderKey ??= _key();
            final result = await runBusy(
              context,
              () => EcosystemApi.placeOrder(
                idempotencyKey: _orderKey!,
                variantId: _variant.text.trim(),
                qty: qty,
                retail: price,
              ),
              success: 'Order placed. It is unpaid until a completed payment is linked.',
            );
            if (result != null && mounted) {
              final data = result['data'] is Map ? result['data'] as Map : result;
              _order.text = '${data['id'] ?? _order.text}';
              setState(() => _result = result);
            }
          },
          child: const Text('Place order'),
        ),
        const SizedBox(height: 16),
        TextField(controller: _order, decoration: bizInput(context, 'Order ID')),
        const SizedBox(height: 8),
        if (_result != null) FeeBreakdown(orderFeeLines(_result!['data'] is Map ? _result!['data'] as Map : _result!)),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_order.text.trim().isEmpty) {
              bizSnack(context, 'Choose an order from the list');
              return;
            }
            final lines = orderFeeLines(_result ?? const {});
            final auth = await confirmWithPin(
              context,
              title: 'Pay for this order',
              message: '${lines.isEmpty ? 'The server charges the order total into escrow.' : feeSummary(lines)}\n\nConfirm with your PIN or biometrics.',
            );
            if (auth == null || !mounted) return;
            _payKey ??= _key();
            final result = await runBusy(
              context,
              () => EcosystemApi.payOrder(orderId: _order.text.trim(), idempotencyKey: _payKey!, auth: auth.authFields()),
              success: 'Payment sent to escrow',
            );
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Pay for this order'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            if (_order.text.trim().isEmpty) return;
            final result = await runBusy(context, () => EcosystemApi.forwardOrder(_order.text.trim()), success: 'Forwarded to the supplier');
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Forward to supplier'),
        ),
        if (widget.orders) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              final result = await runBusy(context, EcosystemApi.orders);
              if (mounted) setState(() => _orders = recordList(result));
            },
            child: const Text('Load orders'),
          ),
          const SizedBox(height: 8),
          _RecordTiles(_orders, onTap: (row) {
            _order.text = '${row['id'] ?? ''}';
            pushPage(context, OrderStatusPage(order: row));
          }),
          const SizedBox(height: 8),
          TextField(controller: _reason, decoration: bizInput(context, 'Reason')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('cancel'), child: const Text('Cancel')),
            OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('return'), child: const Text('Return')),
            OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('dispute'), child: const Text('Dispute')),
          ]),
        ],
        const SizedBox(height: 12),
        _Result(_result),
      ]),
    );
  }

  Future<void> _case(String kind) async {
    if (_order.text.trim().isEmpty || _reason.text.trim().length < 3) {
      bizSnack(context, 'Enter the order and a reason');
      return;
    }
    final auth = await confirmWithPin(
      context,
      title: kind == 'cancel' ? 'Cancel this order' : kind == 'return' ? 'Open a return' : 'Open a dispute',
      message: 'This does not move a wallet. A dispute freezes a scheduled payout. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    _caseKey ??= _key();
    final id = _order.text.trim();
    final reason = _reason.text.trim();
    final result = await runBusy(context, () {
      if (kind == 'cancel') {
        return EcosystemApi.cancelOrder(orderId: id, idempotencyKey: _caseKey!, reason: reason);
      }
      if (kind == 'return') {
        return EcosystemApi.openReturn(orderId: id, idempotencyKey: _caseKey!, reason: reason);
      }
      return EcosystemApi.openDispute(orderId: id, idempotencyKey: _caseKey!, reason: reason);
    });
    if (mounted) setState(() => _result = result);
  }
}

class StoreConnectionsPage extends StatefulWidget {
  const StoreConnectionsPage({super.key, required this.flags});
  final EcosystemFlags flags;
  @override
  State<StoreConnectionsPage> createState() => _StoreConnectionsPageState();
}

class _StoreConnectionsPageState extends State<StoreConnectionsPage> {
  final _domain = TextEditingController();
  final _storeId = TextEditingController();
  String _platform = 'shopify';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _domain.dispose();
    _storeId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _platform == 'shopify' ? widget.flags.shopifyEnabled : widget.flags.wooEnabled;
    return BizScaffold(
      title: 'Store connections',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(storeSyncMessage(verified: false)),
        const SizedBox(height: 8),
        Text(
          enabled
              ? '$_platform is flagged on. That does not verify the shop.'
              : '$_platform is flagged off. You can still save a domain. It stays unverified.',
          style: TextStyle(color: mutedColor(context)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _platform,
          decoration: bizInput(context, 'Platform'),
          items: const [
            DropdownMenuItem(value: 'shopify', child: Text('Shopify')),
            DropdownMenuItem(value: 'woocommerce', child: Text('WooCommerce')),
          ],
          onChanged: (value) => setState(() => _platform = value ?? 'shopify'),
        ),
        const SizedBox(height: 8),
        TextField(controller: _domain, decoration: bizInput(context, 'Shop domain')),
        const SizedBox(height: 12),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_domain.text.trim().length < 3) {
              bizSnack(context, 'Enter the shop domain');
              return;
            }
            final result = await runBusy(
              context,
              () => EcosystemApi.connectStore(platform: _platform, shopDomain: _domain.text.trim()),
              success: 'Saved as unverified',
            );
            if (result != null && mounted) {
              final data = result['data'] is Map ? result['data'] as Map : result;
              _storeId.text = '${data['id'] ?? _storeId.text}';
              setState(() => _result = result);
            }
          },
          child: const Text('Save connection'),
        ),
        const SizedBox(height: 8),
        TextField(controller: _storeId, decoration: bizInput(context, 'Connection ID')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            if (_storeId.text.trim().isEmpty) return;
            final result = await runBusy(context, () => EcosystemApi.syncStore(_storeId.text.trim()));
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Sync'),
        ),
        const SizedBox(height: 12),
        _Result(_result),
      ]),
    );
  }
}

class CargoPage extends StatefulWidget {
  const CargoPage({super.key, this.history = false, this.addresses = false});
  final bool history;
  final bool addresses;
  @override
  State<CargoPage> createState() => _CargoPageState();
}

class _CargoPageState extends State<CargoPage> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _weight = TextEditingController();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _shipmentId = TextEditingController();
  final _dispute = TextEditingController();
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _booked;
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _shipments = const [];
  String? _keyUsed;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _weight.dispose();
    _pickup.dispose();
    _dropoff.dispose();
    _shipmentId.dispose();
    _dispute.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'FARM Cargo',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.history
            ? 'Quotes use configured zone rates. History and the event timeline come from this server. There is no live map and no arrival time unless the server sends one.'
            : 'Quotes use configured zone rates only. There is no live map and no courier tracking.'),
        const SizedBox(height: 12),
        TextField(controller: _from, decoration: bizInput(context, 'From zone')),
        const SizedBox(height: 8),
        TextField(controller: _to, decoration: bizInput(context, 'To zone')),
        const SizedBox(height: 8),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: bizInput(context, 'Weight (kg)'),
        ),
        if (widget.addresses) ...[
          const SizedBox(height: 8),
          TextField(controller: _pickup, decoration: bizInput(context, 'Pickup address (optional)')),
          const SizedBox(height: 8),
          TextField(controller: _dropoff, decoration: bizInput(context, 'Delivery address (optional)')),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            final weight = num.tryParse(_weight.text);
            if (_from.text.trim().isEmpty || _to.text.trim().isEmpty || weight == null || weight <= 0) {
              bizSnack(context, 'Enter both zones and a weight');
              return;
            }
            final result = await runBusy(
              context,
              () => EcosystemApi.cargoQuote(fromZone: _from.text.trim(), toZone: _to.text.trim(), weightKg: weight),
            );
            if (mounted) setState(() => _quote = result);
          },
          child: const Text('Get quote'),
        ),
        if (_quote != null) ...[
          const SizedBox(height: 12),
          Text(cargoQuoteSummary(_quote!), style: TextStyle(color: fgColor(context))),
          const SizedBox(height: 8),
          FeeBreakdown(cargoFeeLines(_quote!)),
          const SizedBox(height: 8),
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () async {
              final weight = num.tryParse(_weight.text);
              if (weight == null) return;
              final auth = await confirmWithPin(
                context,
                title: 'Pay for this shipment',
                message: '${feeSummary(cargoFeeLines(_quote!))}\n\nThe server charges your wallet into escrow. Confirm with your PIN or biometrics.',
              );
              if (auth == null || !mounted) return;
              _keyUsed ??= _key();
              final result = await runBusy(
                context,
                () => EcosystemApi.cargoBook(
                  fromZone: _from.text.trim(),
                  toZone: _to.text.trim(),
                  weightKg: weight,
                  idempotencyKey: _keyUsed!,
                  auth: auth.authFields(),
                  pickupAddress: widget.addresses ? _pickup.text.trim() : null,
                  deliveryAddress: widget.addresses ? _dropoff.text.trim() : null,
                ),
                success: 'Booked',
              );
              if (mounted) setState(() => _booked = result);
            },
            child: const Text('Pay and book'),
          ),
        ],
        if (_booked != null) ...[
          const SizedBox(height: 12),
          Text(widget.history
              ? 'The booked shipment is below. Open history for later events stored on the server.'
              : 'Tracking shows the booked step only. Later steps are not available until a partner can update them.'),
          const SizedBox(height: 8),
          _Result(_booked),
        ],
        if (widget.history) ...[
          const SizedBox(height: 16),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              final result = await runBusy(context, EcosystemApi.shipments);
              if (mounted) setState(() => _shipments = recordList(result));
            },
            child: const Text('Load my shipments'),
          ),
          const SizedBox(height: 8),
          _RecordTiles(_shipments, onTap: (row) {
            _shipmentId.text = '${row['id'] ?? ''}';
            pushPage(context, ShipmentStatusPage(shipment: row));
          }),
          const SizedBox(height: 8),
          TextField(controller: _shipmentId, decoration: bizInput(context, 'Shipment ID')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () async {
                if (_shipmentId.text.trim().isEmpty) return;
                final result = await runBusy(context, () => EcosystemApi.shipment(_shipmentId.text.trim()));
                if (mounted) setState(() => _detail = result);
              },
              child: const Text('Timeline'),
            ),
            OutlinedButton(
              style: secondaryButtonStyle(context),
              onPressed: () async {
                if (_shipmentId.text.trim().isEmpty) return;
                final result = await runBusy(context, () => EcosystemApi.shipmentReceipt(_shipmentId.text.trim()));
                if (mounted) setState(() => _detail = result);
              },
              child: const Text('Receipt'),
            ),
          ]),
          if (_detail != null) ...[
            const SizedBox(height: 8),
            _Result(_detail),
            for (final event in shipmentTimeline(_detail))
              KeyValue('${event['status'] ?? event['type'] ?? 'Event'}', '${event['created_at'] ?? event['at'] ?? ''}'),
          ],
          const SizedBox(height: 8),
          TextField(controller: _dispute, decoration: bizInput(context, 'Dispute reason')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              if (_shipmentId.text.trim().isEmpty || _dispute.text.trim().length < 3) {
                bizSnack(context, 'Enter the shipment and a reason');
                return;
              }
              final auth = await confirmWithPin(
                context,
                title: 'Dispute this shipment',
                message: 'This freezes a scheduled cargo payout. It does not send a new payment. Confirm with your PIN or biometrics.',
              );
              if (auth == null || !mounted) return;
              final result = await runBusy(
                context,
                () => EcosystemApi.shipmentDispute(id: _shipmentId.text.trim(), reason: _dispute.text.trim()),
              );
              if (mounted) setState(() => _detail = result);
            },
            child: const Text('Open dispute'),
          ),
        ],
      ]),
    );
  }
}

class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key, this.apply = false});
  final bool apply;
  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _shipment = TextEditingController();
  final _job = TextEditingController();
  final _partner = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _registration = TextEditingController();
  final _vehicleCategory = TextEditingController();
  final _vehicleModel = TextEditingController();
  final _vehiclePlate = TextEditingController();
  final _capacity = TextEditingController();
  final _driver = TextEditingController();
  final _licence = TextEditingController();
  final _proofRef = TextEditingController();
  final _otp = TextEditingController();
  String _kind = 'individual_rider';
  String _proof = 'otp';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _shipment.dispose();
    _job.dispose();
    _partner.dispose();
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _registration.dispose();
    _vehicleCategory.dispose();
    _vehicleModel.dispose();
    _vehiclePlate.dispose();
    _capacity.dispose();
    _driver.dispose();
    _licence.dispose();
    _proofRef.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Delivery partner',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(partnerRegistrationNote),
        if (widget.apply) ...[
          const SizedBox(height: 16),
          Text('Application', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: bizInput(context, 'Kind'),
            items: const [
              DropdownMenuItem(value: 'individual_rider', child: Text('Rider')),
              DropdownMenuItem(value: 'individual_vehicle', child: Text('Vehicle owner')),
              DropdownMenuItem(value: 'logistics_company', child: Text('Logistics company')),
            ],
            onChanged: (value) => setState(() => _kind = value ?? 'individual_rider'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: bizInput(context, 'Legal name')),
          const SizedBox(height: 8),
          TextField(controller: _phone, decoration: bizInput(context, 'Phone (optional)')),
          const SizedBox(height: 8),
          TextField(controller: _area, decoration: bizInput(context, 'Service area (optional)')),
          if (_kind == 'logistics_company') ...[
            const SizedBox(height: 8),
            TextField(controller: _registration, decoration: bizInput(context, 'Company registration')),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () async {
              if (_name.text.trim().length < 2) {
                bizSnack(context, 'Enter the legal name');
                return;
              }
              if (_kind == 'logistics_company' && _registration.text.trim().isEmpty) {
                bizSnack(context, 'A company needs its registration');
                return;
              }
              final result = await runBusy(
                context,
                () => EcosystemApi.applyPartner(
                  kind: _kind,
                  legalName: _name.text.trim(),
                  phone: _phone.text.trim(),
                  serviceArea: _area.text.trim(),
                  companyRegistration: _registration.text.trim(),
                ),
                success: 'Application sent',
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Submit application'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              final result = await runBusy(context, EcosystemApi.myPartner);
              if (mounted) setState(() => _result = result);
            },
            child: const Text('View my partner profile'),
          ),
          const SizedBox(height: 16),
          Text('Fleet', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
          const SizedBox(height: 8),
          TextField(controller: _vehicleCategory, decoration: bizInput(context, 'Vehicle category')),
          const SizedBox(height: 8),
          TextField(controller: _vehicleModel, decoration: bizInput(context, 'Make and model')),
          const SizedBox(height: 8),
          TextField(controller: _vehiclePlate, decoration: bizInput(context, 'Registration')),
          const SizedBox(height: 8),
          TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: bizInput(context, 'Capacity (kg)')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              final capacity = num.tryParse(_capacity.text);
              if (_vehicleCategory.text.trim().isEmpty || _vehicleModel.text.trim().isEmpty || _vehiclePlate.text.trim().isEmpty || capacity == null) {
                bizSnack(context, 'Enter the vehicle and its capacity');
                return;
              }
              final result = await runBusy(
                context,
                () => EcosystemApi.addVehicle(
                  category: _vehicleCategory.text.trim(),
                  makeModel: _vehicleModel.text.trim(),
                  registration: _vehiclePlate.text.trim(),
                  capacityKg: capacity,
                ),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Add vehicle'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _driver, decoration: bizInput(context, 'Driver legal name')),
          const SizedBox(height: 8),
          TextField(controller: _licence, decoration: bizInput(context, 'Licence reference')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              if (_driver.text.trim().isEmpty || _licence.text.trim().isEmpty) return;
              final result = await runBusy(
                context,
                () => EcosystemApi.addDriver(legalName: _driver.text.trim(), licenceRef: _licence.text.trim()),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Add driver'),
          ),
          const SizedBox(height: 16),
          Text('Proof of delivery', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _proof,
            decoration: bizInput(context, 'Method'),
            items: const [
              DropdownMenuItem(value: 'otp', child: Text('One-time code')),
              DropdownMenuItem(value: 'signature', child: Text('Signature reference')),
              DropdownMenuItem(value: 'photo', child: Text('Photo link')),
            ],
            onChanged: (value) => setState(() => _proof = value ?? 'otp'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _proofRef, decoration: bizInput(context, 'Reference (https for a photo)')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              if (_job.text.trim().isEmpty) {
                bizSnack(context, 'Enter the job ID below');
                return;
              }
              if (_proof == 'photo' && !httpsReference(_proofRef.text)) {
                bizSnack(context, 'A photo reference must be an https link');
                return;
              }
              final result = await runBusy(
                context,
                () => EcosystemApi.jobProof(jobId: _job.text.trim(), method: _proof, reference: _proofRef.text.trim()),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Record proof'),
          ),
          const SizedBox(height: 8),
          TextField(controller: _otp, decoration: bizInput(context, 'Code from the recipient')),
          const SizedBox(height: 8),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () async {
              if (_job.text.trim().isEmpty || _otp.text.trim().isEmpty) return;
              final result = await runBusy(
                context,
                () => EcosystemApi.verifyProof(jobId: _job.text.trim(), code: _otp.text.trim()),
              );
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Verify code'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () async {
              if (_job.text.trim().isEmpty) return;
              final auth = await confirmWithPin(
                context,
                title: 'Confirm delivery',
                message: 'This schedules the cargo payout. It does not send a new payment. Confirm with your PIN or biometrics.',
              );
              if (auth == null || !mounted) return;
              final result = await runBusy(context, () => EcosystemApi.deliverJob(_job.text.trim()), success: 'Delivery confirmed');
              if (mounted) setState(() => _result = result);
            },
            child: const Text('Confirm delivery'),
          ),
          const SizedBox(height: 12),
          _Result(_result),
        ],
        const SizedBox(height: 16),
        Text('Admin assignment', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 8),
        TextField(controller: _shipment, decoration: bizInput(context, 'Shipment ID')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            if (_shipment.text.trim().isEmpty) return;
            await runBusy(context, () => EcosystemApi.openJob(_shipment.text.trim()), success: 'Job opened');
          },
          child: const Text('Open job'),
        ),
        const SizedBox(height: 8),
        TextField(controller: _job, decoration: bizInput(context, 'Job ID')),
        const SizedBox(height: 8),
        TextField(controller: _partner, decoration: bizInput(context, 'Approved partner ID')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_job.text.trim().isEmpty || _partner.text.trim().isEmpty) return;
            await runBusy(
              context,
              () => EcosystemApi.assignJob(jobId: _job.text.trim(), partnerId: _partner.text.trim()),
              success: 'Assigned',
            );
          },
          child: const Text('Assign partner'),
        ),
      ]),
    );
  }
}

class SettlementPage extends StatefulWidget {
  const SettlementPage({super.key});
  @override
  State<SettlementPage> createState() => _SettlementPageState();
}

class _SettlementPageState extends State<SettlementPage> {
  final _order = TextEditingController();
  Map<String, dynamic>? _authority;
  Map<String, dynamic>? _record;

  @override
  void initState() {
    super.initState();
    EcosystemApi.aiAuthority().then((value) {
      if (mounted) setState(() => _authority = value);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authority = _authority;
    final data = authority == null
        ? null
        : authority['data'] is Map
            ? authority['data'] as Map
            : authority;
    return BizScaffold(
      title: 'Settlements',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(settlementRecordNote),
        const SizedBox(height: 8),
        Text(autonomousPayNote, style: TextStyle(color: mutedColor(context))),
        if (data != null) ...[
          const SizedBox(height: 12),
          KeyValue('Autonomous payments', '${data['autonomous_payments']}'),
          KeyValue('PIN or biometrics', '${data['pin_or_biometric_required']}'),
        ],
        const SizedBox(height: 16),
        TextField(controller: _order, decoration: bizInput(context, 'Paid order ID')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_order.text.trim().isEmpty) return;
            final auth = await confirmWithPin(
              context,
              title: 'Record settlement',
              message: '$settlementRecordNote\n\nThis does not pay anyone. Confirm with your PIN or biometrics.',
            );
            if (auth == null || !mounted) return;
            final result = await runBusy(context, () => EcosystemApi.recordSettlement(_order.text.trim()), success: 'Recorded');
            if (mounted) setState(() => _record = result);
          },
          child: const Text('Record settlement'),
        ),
        const SizedBox(height: 12),
        _Result(_record),
      ]),
    );
  }
}

class CargoAdminPage extends StatefulWidget {
  const CargoAdminPage({super.key});
  @override
  State<CargoAdminPage> createState() => _CargoAdminPageState();
}

class _CargoAdminPageState extends State<CargoAdminPage> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _base = TextEditingController();
  final _perKg = TextEditingController();
  final _rateId = TextEditingController();
  final _farmShare = TextEditingController(text: '2000');
  final _partnerShare = TextEditingController(text: '8000');
  List<Map<String, dynamic>> _rates = const [];
  List<String> _zones = const [];

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _base.dispose();
    _perKg.dispose();
    _rateId.dispose();
    _farmShare.dispose();
    _partnerShare.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Cargo rates',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Admin only. A rate is a base fee plus a per-kilogram fee. There is no map and no arrival time.'),
        const SizedBox(height: 12),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            final rates = await runBusy(context, EcosystemApi.cargoRates);
            final zones = await runBusy(context, EcosystemApi.cargoZones);
            if (mounted) {
              setState(() {
                _rates = recordList(rates);
                _zones = zoneNames(zones);
              });
            }
          },
          child: const Text('Load rates and zones'),
        ),
        const SizedBox(height: 8),
        if (_zones.isNotEmpty)
          Text('Zones: ${_zones.join(', ')}', style: TextStyle(color: mutedColor(context))),
        _RecordTiles(_rates, onTap: (row) => _rateId.text = '${row['id'] ?? ''}'),
        const SizedBox(height: 8),
        TextField(controller: _from, decoration: bizInput(context, 'From zone')),
        const SizedBox(height: 8),
        TextField(controller: _to, decoration: bizInput(context, 'To zone')),
        const SizedBox(height: 8),
        TextField(controller: _base, keyboardType: TextInputType.number, decoration: bizInput(context, 'Base fee (FARM)')),
        const SizedBox(height: 8),
        TextField(controller: _perKg, keyboardType: TextInputType.number, decoration: bizInput(context, 'Per kg (FARM)')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            final base = num.tryParse(_base.text);
            final perKg = num.tryParse(_perKg.text);
            if (_from.text.trim().isEmpty || _to.text.trim().isEmpty || base == null || perKg == null || (base == 0 && perKg == 0)) {
              bizSnack(context, 'Enter both zones and a fee');
              return;
            }
            await runBusy(
              context,
              () => EcosystemApi.createCargoRate(
                fromZone: _from.text.trim(),
                toZone: _to.text.trim(),
                baseFeeFarm: base,
                perKgFarm: perKg,
              ),
              success: 'Rate saved',
            );
          },
          child: const Text('Save rate'),
        ),
        const SizedBox(height: 8),
        TextField(controller: _rateId, decoration: bizInput(context, 'Rate ID')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () => _active(false),
            child: const Text('Deactivate'),
          ),
          OutlinedButton(
            style: secondaryButtonStyle(context),
            onPressed: () => _active(true),
            child: const Text('Activate'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(controller: _farmShare, keyboardType: TextInputType.number, decoration: bizInput(context, 'FARM share (bps)')),
        const SizedBox(height: 8),
        TextField(controller: _partnerShare, keyboardType: TextInputType.number, decoration: bizInput(context, 'Partner share (bps)')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            final farm = int.tryParse(_farmShare.text);
            final partner = int.tryParse(_partnerShare.text);
            if (farm == null || partner == null || !cargoSplitValid(farm, partner)) {
              bizSnack(context, 'The two shares must add up to 10000');
              return;
            }
            await runBusy(
              context,
              () => EcosystemApi.setCargoSplit(farmShareBps: farm, partnerShareBps: partner),
              success: 'Split saved',
            );
          },
          child: const Text('Save split'),
        ),
      ]),
    );
  }

  Future<void> _active(bool active) async {
    if (_rateId.text.trim().isEmpty) return;
    await runBusy(context, () => EcosystemApi.setCargoRateActive(id: _rateId.text.trim(), active: active));
  }
}

/// Cargo for a personal account. Hidden until the platform module list includes cargo.
class PersonalCargoButton extends StatefulWidget {
  const PersonalCargoButton({super.key});
  @override
  State<PersonalCargoButton> createState() => _PersonalCargoButtonState();
}

class _PersonalCargoButtonState extends State<PersonalCargoButton> {
  EcosystemFlags _flags = EcosystemFlags.hidden;

  @override
  void initState() {
    super.initState();
    EcosystemApi.flags().then((flags) {
      if (mounted) setState(() => _flags = flags);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_flags.cargo && !_flags.cargoList) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FloatingActionButton.extended(
        heroTag: 'personal-cargo',
        tooltip: 'FARM Cargo',
        onPressed: () => pushPage(
          context,
          CargoPage(history: _flags.cargoList, addresses: _flags.cargoList),
        ),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Cargo'),
      ),
    );
  }
}
