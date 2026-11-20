import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/pages/business/ops/ops_ui.dart';
import 'ecosystem_api.dart';
import 'ecosystem_logic.dart';

String _key() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(36).toRadixString(36)).join();
}

/// Entry points that stay hidden until the matching backend phase answers.
class EcosystemTools extends StatefulWidget {
  const EcosystemTools({super.key});

  @override
  State<EcosystemTools> createState() => _EcosystemToolsState();
}

class _EcosystemToolsState extends State<EcosystemTools> {
  EcosystemFlags? _flags;

  @override
  void initState() {
    super.initState();
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
      if (flags.dropship) ('Dropshipping', Icons.storefront_outlined, const DropshipPage()),
      if (flags.dropship) ('Supplier', Icons.inventory_2_outlined, const SupplierPage()),
      if (flags.stores) ('Store connections', Icons.shopping_bag_outlined, StoreConnectionsPage(flags: flags)),
      if (flags.cargo) ('FARM Cargo', Icons.local_shipping_outlined, const CargoPage()),
      if (flags.dispatch) ('Delivery partner', Icons.badge_outlined, const PartnerPage()),
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
  const DropshipPage({super.key});
  @override
  State<DropshipPage> createState() => _DropshipPageState();
}

class _DropshipPageState extends State<DropshipPage> {
  final _variant = TextEditingController();
  final _retail = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _order = TextEditingController();
  final _tx = TextEditingController();
  String? _orderKey;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _variant.dispose();
    _retail.dispose();
    _qty.dispose();
    _order.dispose();
    _tx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Dropshipping',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
          'Import an approved supplier variant. Commission is shown only when the server has a rate. There is no catalogue list on this API, so use the variant ID.',
        ),
        const SizedBox(height: 12),
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
        TextField(controller: _tx, decoration: bizInput(context, 'Completed transaction ID')),
        const SizedBox(height: 8),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_order.text.trim().isEmpty || _tx.text.trim().isEmpty) {
              bizSnack(context, 'Enter the order and the completed transaction');
              return;
            }
            final auth = await confirmWithPin(
              context,
              title: 'Link this payment',
              message: 'This does not create a new charge. It links a completed transaction to the order. Confirm with your PIN or biometrics.',
            );
            if (auth == null || !mounted) return;
            final result = await runBusy(
              context,
              () => EcosystemApi.payOrder(orderId: _order.text.trim(), transactionId: _tx.text.trim()),
              success: 'Payment linked',
            );
            if (mounted) setState(() => _result = result);
          },
          child: const Text('Confirm payment link'),
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
        const SizedBox(height: 12),
        _Result(_result),
      ]),
    );
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
  const CargoPage({super.key});
  @override
  State<CargoPage> createState() => _CargoPageState();
}

class _CargoPageState extends State<CargoPage> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _weight = TextEditingController();
  final _tx = TextEditingController();
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _booked;
  String? _keyUsed;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _weight.dispose();
    _tx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'FARM Cargo',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Quotes use configured zone rates only. There is no live map and no courier tracking.'),
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
          TextField(controller: _tx, decoration: bizInput(context, 'Completed transaction ID')),
          const SizedBox(height: 8),
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () async {
              if (_tx.text.trim().isEmpty) {
                bizSnack(context, 'Enter the completed transaction that paid this quote');
                return;
              }
              final weight = num.tryParse(_weight.text);
              if (weight == null) return;
              final auth = await confirmWithPin(
                context,
                title: 'Book this shipment',
                message: '${cargoQuoteSummary(_quote!)}\n\nBooking uses the completed transaction. Confirm with your PIN or biometrics.',
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
                  transactionId: _tx.text.trim(),
                ),
                success: 'Booked',
              );
              if (mounted) setState(() => _booked = result);
            },
            child: const Text('Book shipment'),
          ),
        ],
        if (_booked != null) ...[
          const SizedBox(height: 12),
          const Text('Tracking shows the booked step only. Later steps are not available until a partner can update them.'),
          const SizedBox(height: 8),
          _Result(_booked),
        ],
      ]),
    );
  }
}

class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});
  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _shipment = TextEditingController();
  final _job = TextEditingController();
  final _partner = TextEditingController();

  @override
  void dispose() {
    _shipment.dispose();
    _job.dispose();
    _partner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Delivery partner',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(partnerRegistrationNote),
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
