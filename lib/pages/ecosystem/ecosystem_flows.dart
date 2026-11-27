import 'package:flutter/material.dart';

import '/pages/business/ops/ops_ui.dart';
import 'ecosystem_api.dart';
import 'ecosystem_logic.dart';

class FeeBreakdown extends StatelessWidget {
  const FeeBreakdown(this.lines, {super.key});
  final List<FeeLine> lines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: feeSummary(lines),
      child: BizCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Fee breakdown', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
          const SizedBox(height: 8),
          for (final line in lines) KeyValue(line.label, line.value),
        ]),
      ),
    );
  }
}

class SalesOverviewCard extends StatelessWidget {
  const SalesOverviewCard(this.orders, {super.key});
  final List<Map<String, dynamic>> orders;

  @override
  Widget build(BuildContext context) {
    final totals = salesTotals(orders);
    return BizCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dropshipping sales', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 8),
        KeyValue('Orders', '${totals.count}'),
        KeyValue('Retail', totals.retail == null ? '—' : '${totals.retail} FARM'),
        KeyValue('Supplier cost', totals.supplier == null ? '—' : '${totals.supplier} FARM'),
        KeyValue('FARM commission', totals.commission == null ? 'Not configured' : '${totals.commission} FARM'),
        KeyValue('Seller net', totals.net == null ? 'Shown when every order has a commission' : '${totals.net} FARM'),
      ]),
    );
  }
}

class DropshipSalesPage extends StatefulWidget {
  const DropshipSalesPage({super.key, this.previewOrders});
  final List<Map<String, dynamic>>? previewOrders;
  @override
  State<DropshipSalesPage> createState() => _DropshipSalesPageState();
}

class _DropshipSalesPageState extends State<DropshipSalesPage> {
  List<Map<String, dynamic>> _orders = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewOrders;
    if (preview != null) {
      _orders = preview;
      _loading = false;
      return;
    }
    EcosystemApi.orders().then((value) {
      if (mounted) setState(() {
        _orders = recordList(value);
        _loading = false;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Dropshipping sales',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SalesOverviewCard(_orders),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading && _orders.isEmpty)
          Text('No orders yet.', style: TextStyle(color: mutedColor(context))),
        for (final order in _orders)
          BizTile(
            title: '${order['status'] ?? 'Order'}',
            subtitle: '${order['retail_total'] ?? ''} FARM'.trim(),
            onTap: () => pushPage(context, OrderStatusPage(order: order)),
          ),
      ]),
    );
  }
}

class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key, required this.order});
  final Map<String, dynamic> order;
  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends State<OrderStatusPage> {
  final _reason = TextEditingController();
  String? _payKey;
  String? _caseKey;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _id => '${widget.order['id'] ?? ''}';

  @override
  Widget build(BuildContext context) {
    final lines = orderFeeLines(widget.order);
    return BizScaffold(
      title: 'Order',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Status: ${widget.order['status'] ?? '—'}', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 12),
        FeeBreakdown(lines),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Pay for this order. ${feeSummary(lines)}',
          child: ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: _id.isEmpty ? null : _pay,
            child: const Text('Pay for this order'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(controller: _reason, decoration: bizInput(context, 'Reason for cancel, return, or dispute')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('cancel'), child: const Text('Cancel order')),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('return'), child: const Text('Return')),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _case('dispute'), child: const Text('Dispute')),
        ]),
        const SizedBox(height: 12),
        if (_result != null) Text('${_result!['status'] ?? _result}', style: TextStyle(color: mutedColor(context))),
      ]),
    );
  }

  Future<void> _pay() async {
    final auth = await confirmWithPin(
      context,
      title: 'Pay for this order',
      message: '${feeSummary(orderFeeLines(widget.order))}\n\nThe server charges your wallet into escrow. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    _payKey ??= _flowKey();
    final result = await runBusy(
      context,
      () => EcosystemApi.payOrder(orderId: _id, idempotencyKey: _payKey!, auth: auth.authFields()),
      success: 'Payment sent to escrow',
    );
    if (mounted && result != null) setState(() => _result = result);
  }

  Future<void> _case(String kind) async {
    if (_reason.text.trim().length < 3) {
      bizSnack(context, 'Enter a reason');
      return;
    }
    final auth = await confirmWithPin(
      context,
      title: kind == 'cancel' ? 'Cancel this order' : kind == 'return' ? 'Open a return' : 'Open a dispute',
      message: 'This does not create a new charge. A dispute freezes a scheduled payout. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    _caseKey ??= _flowKey();
    final result = await runBusy(context, () {
      if (kind == 'cancel') {
        return EcosystemApi.cancelOrder(orderId: _id, idempotencyKey: _caseKey!, reason: _reason.text.trim());
      }
      if (kind == 'return') {
        return EcosystemApi.openReturn(orderId: _id, idempotencyKey: _caseKey!, reason: _reason.text.trim());
      }
      return EcosystemApi.openDispute(orderId: _id, idempotencyKey: _caseKey!, reason: _reason.text.trim());
    });
    if (mounted && result != null) setState(() => _result = result);
  }
}

class ShipmentStatusPage extends StatefulWidget {
  const ShipmentStatusPage({super.key, required this.shipment, this.previewDetail});
  final Map<String, dynamic> shipment;
  final Map<String, dynamic>? previewDetail;
  @override
  State<ShipmentStatusPage> createState() => _ShipmentStatusPageState();
}

class _ShipmentStatusPageState extends State<ShipmentStatusPage> {
  final _reason = TextEditingController();
  Map<String, dynamic>? _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.previewDetail;
    if (_detail != null) return;
    final id = '${widget.shipment['id'] ?? ''}';
    if (id.isEmpty) return;
    EcosystemApi.shipment(id).then((value) {
      if (mounted) setState(() => _detail = value);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final data = detail == null
        ? widget.shipment
        : detail['data'] is Map
            ? Map<String, dynamic>.from(detail['data'] as Map)
            : detail;
    final events = shipmentTimeline(detail ?? {'data': widget.shipment});
    return BizScaffold(
      title: 'Shipment',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Status: ${data['status'] ?? widget.shipment['status'] ?? '—'}',
            style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 8),
        Text(cargoQuoteSummary(data), style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Text('No later events are stored yet.', style: TextStyle(color: mutedColor(context)))
        else
          for (final event in events)
            KeyValue('${event['status'] ?? event['type'] ?? 'Event'}', '${event['note'] ?? event['created_at'] ?? ''}'),
        const SizedBox(height: 12),
        TextField(controller: _reason, decoration: bizInput(context, 'Reason to cancel or dispute')),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: _cancel, child: const Text('Cancel shipment')),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: _dispute, child: const Text('Dispute')),
        ]),
      ]),
    );
  }

  String get _id => '${widget.shipment['id'] ?? ''}';

  Future<void> _cancel() async {
    if (_reason.text.trim().length < 3) {
      bizSnack(context, 'Enter a reason');
      return;
    }
    final auth = await confirmWithPin(
      context,
      title: 'Cancel this shipment',
      message: 'The server decides whether this status can be cancelled. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    await runBusy(
      context,
      () => EcosystemApi.cancelShipment(id: _id, reason: _reason.text.trim(), auth: auth.authFields()),
      success: 'Cancellation sent',
    );
  }

  Future<void> _dispute() async {
    if (_reason.text.trim().length < 3) {
      bizSnack(context, 'Enter a reason');
      return;
    }
    final auth = await confirmWithPin(
      context,
      title: 'Dispute this shipment',
      message: 'This freezes a scheduled cargo payout. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    await runBusy(context, () => EcosystemApi.shipmentDispute(id: _id, reason: _reason.text.trim()));
  }
}

class PartnerPortalPage extends StatefulWidget {
  const PartnerPortalPage({super.key, this.previewJobs});
  final List<Map<String, dynamic>>? previewJobs;
  @override
  State<PartnerPortalPage> createState() => _PartnerPortalPageState();
}

class _PartnerPortalPageState extends State<PartnerPortalPage> {
  List<Map<String, dynamic>> _jobs = const [];
  Map<String, dynamic>? _earnings;
  List<Map<String, dynamic>> _documents = const [];
  bool _available = false;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final preview = widget.previewJobs;
    if (preview != null) {
      _jobs = preview;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final jobs = await runBusy(context, EcosystemApi.partnerJobs);
    final earnings = await runBusy(context, EcosystemApi.partnerEarnings);
    final documents = await runBusy(context, EcosystemApi.partnerDocuments);
    if (!mounted) return;
    setState(() {
      _jobs = recordList(jobs);
      _earnings = earnings;
      _documents = recordList(documents);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Partner portal',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(partnerRegistrationNote, style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Available for jobs'),
          value: _available,
          onChanged: (value) async {
            setState(() => _available = value);
            if (widget.previewJobs != null) return;
            await runBusy(context, () => EcosystemApi.setAvailability(value), success: value ? 'Available' : 'Unavailable');
          },
        ),
        const SizedBox(height: 8),
        Text('Jobs', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        if (_jobs.isEmpty) Text('No jobs yet.', style: TextStyle(color: mutedColor(context))),
        for (final job in _jobs)
          BizTile(
            title: '${job['status'] ?? 'Job'}',
            subtitle: '${job['from_zone'] ?? ''} ${job['to_zone'] ?? ''}'.trim(),
            onTap: () {},
          ),
        TextField(controller: _reason, decoration: bizInput(context, 'Reason if you reject')),
        const SizedBox(height: 8),
        for (final job in _jobs)
          Wrap(spacing: 8, children: [
            Text('${job['status'] ?? 'Job'}', style: TextStyle(color: fgColor(context))),
            TextButton(
              onPressed: () => runBusy(context, () => EcosystemApi.acceptJob('${job['id']}'), success: 'Accepted'),
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: () {
                if (_reason.text.trim().length < 3) {
                  bizSnack(context, 'Enter a reason');
                  return;
                }
                runBusy(context, () => EcosystemApi.rejectJob(id: '${job['id']}', reason: _reason.text.trim()), success: 'Rejected');
              },
              child: const Text('Reject'),
            ),
          ]),
        const SizedBox(height: 16),
        Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        if (_earnings == null)
          Text('Earnings appear when this server has them.', style: TextStyle(color: mutedColor(context)))
        else
          for (final entry in (_earnings!['data'] is Map ? _earnings!['data'] as Map : _earnings!).entries)
            if (entry.value is! Map && entry.value is! List) KeyValue('${entry.key}', '${entry.value}'),
        const SizedBox(height: 16),
        Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        if (_documents.isEmpty) Text('No documents yet.', style: TextStyle(color: mutedColor(context))),
        for (final doc in _documents)
          KeyValue('${doc['kind'] ?? doc['type'] ?? 'Document'}', '${doc['status'] ?? doc['reference'] ?? ''}'),
      ]),
    );
  }
}

String _flowKey() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'pay$now';
}
