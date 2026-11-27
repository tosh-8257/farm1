import 'package:flutter/material.dart';

import '/pages/business/ops/ops_ui.dart';
import 'ecosystem_api.dart';
import 'ecosystem_logic.dart';
import 'partner_location.dart';

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
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      final earnings = recordList(await EcosystemApi.sellerEarnings());
      if (!mounted) return;
      if (earnings.isNotEmpty) {
        setState(() {
          _orders = earnings;
          _loading = false;
        });
        return;
      }
      final orders = recordList(await EcosystemApi.orders());
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final result = await runBusy(
      context,
      () => EcosystemApi.payOrder(orderId: _id, auth: auth.authFields()),
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
  final _code = TextEditingController();
  final _disputeReason = TextEditingController();
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
    _code.dispose();
    _disputeReason.dispose();
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
        Text('Status updates are picked up, in transit, or cancelled. Cancelling a booked shipment refunds escrow.',
            style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _event('picked_up'), child: const Text('Picked up')),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _event('in_transit'), child: const Text('In transit')),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: () => _event('cancelled'), child: const Text('Cancel shipment')),
        ]),
        const SizedBox(height: 16),
        Text('Delivery code', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 4),
        Text('The code is sent only to you. The delivery partner cannot see it.', style: TextStyle(color: mutedColor(context))),
        const SizedBox(height: 8),
        if (_jobId.isNotEmpty) ...[
          TextField(controller: _code, decoration: bizInput(context, 'Code from your notification')),
          const SizedBox(height: 8),
          OutlinedButton(style: secondaryButtonStyle(context), onPressed: _verifyCode, child: const Text('Confirm delivery code')),
        ],
        const SizedBox(height: 12),
        TextField(controller: _disputeReason, decoration: bizInput(context, 'Dispute reason')),
        const SizedBox(height: 8),
        OutlinedButton(style: secondaryButtonStyle(context), onPressed: _dispute, child: const Text('Dispute')),
      ]),
    );
  }

  String get _id => '${widget.shipment['id'] ?? ''}';
  String get _jobId => '${widget.shipment['job_id'] ?? widget.shipment['jobId'] ?? ''}'.trim();

  Future<void> _event(String status) async {
    await runBusy(context, () => EcosystemApi.shipmentEvent(id: _id, status: status), success: 'Status sent');
  }

  Future<void> _verifyCode() async {
    if (_jobId.isEmpty || _code.text.trim().length < 4) {
      bizSnack(context, 'Enter the code from your delivery notification');
      return;
    }
    await runBusy(
      context,
      () => EcosystemApi.verifyProof(jobId: _jobId, code: _code.text.trim()),
      success: 'Code confirmed',
    );
  }

  Future<void> _dispute() async {
    if (_disputeReason.text.trim().length < 3) {
      bizSnack(context, 'Enter a reason');
      return;
    }
    final auth = await confirmWithPin(
      context,
      title: 'Dispute this shipment',
      message: 'This freezes a scheduled cargo payout. Confirm with your PIN or biometrics.',
    );
    if (auth == null || !mounted) return;
    await runBusy(context, () => EcosystemApi.shipmentDispute(id: _id, reason: _disputeReason.text.trim()));
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
  List<Map<String, dynamic>> _earnings = const [];
  bool _online = false;
  final _kind = TextEditingController();
  final _expires = TextEditingController();

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
    _kind.dispose();
    _expires.dispose();
    super.dispose();
  }

  bool get _assigned => _jobs.any((job) => assignmentJobId(job).isNotEmpty);

  Future<void> _load() async {
    final jobs = await runBusy(context, EcosystemApi.partnerJobs);
    final earnings = await runBusy(context, EcosystemApi.partnerEarnings);
    if (!mounted) return;
    setState(() {
      _jobs = recordList(jobs);
      _earnings = recordList(earnings);
    });
  }

  Future<void> _sendLocation() async {
    if (!partnerMayPostLocation(online: _online, assigned: _assigned)) {
      bizSnack(context, 'Position is sent only while you are available and on an assigned job');
      return;
    }
    final position = await readPartnerPosition();
    if (!mounted) return;
    if (position == null) {
      bizSnack(context, 'Location permission is needed');
      return;
    }
    if (!partnerMayPostLocation(online: _online, assigned: _assigned)) return;
    await runBusy(
      context,
      () => EcosystemApi.postPartnerLocation(lat: position.lat, lng: position.lng),
      success: 'Position sent',
    );
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
          subtitle: const Text('Position is sent only while this is on and you have an assigned job. There is no live map.'),
          value: _online,
          onChanged: (value) async {
            setState(() => _online = value);
            if (widget.previewJobs != null) return;
            await runBusy(context, () => EcosystemApi.setAvailability(value), success: value ? 'Available' : 'Unavailable');
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: partnerMayPostLocation(online: _online, assigned: _assigned) ? _sendLocation : null,
          child: const Text('Send my position'),
        ),
        const SizedBox(height: 8),
        Text('Jobs', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        if (_jobs.isEmpty) Text('No jobs yet.', style: TextStyle(color: mutedColor(context))),
        for (final job in _jobs)
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(assignmentJobId(job).isEmpty ? 'Job' : 'Assigned job', style: TextStyle(color: fgColor(context))),
            TextButton(
              onPressed: assignmentJobId(job).isEmpty
                  ? null
                  : () => runBusy(
                        context,
                        () => EcosystemApi.decideJob(jobId: assignmentJobId(job), decision: 'accepted'),
                        success: 'Accepted',
                      ),
              child: const Text('Accept'),
            ),
            TextButton(
              onPressed: assignmentJobId(job).isEmpty
                  ? null
                  : () => runBusy(
                        context,
                        () => EcosystemApi.decideJob(jobId: assignmentJobId(job), decision: 'rejected'),
                        success: 'Rejected',
                      ),
              child: const Text('Reject'),
            ),
          ]),
        const SizedBox(height: 16),
        Text('Earnings', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        if (_earnings.isEmpty)
          Text('No payouts yet.', style: TextStyle(color: mutedColor(context)))
        else
          for (final row in _earnings)
            KeyValue('${row['status'] ?? 'Payout'}', '${row['amount'] ?? ''} FARM'.trim()),
        const SizedBox(height: 16),
        Text('Documents', style: TextStyle(fontWeight: FontWeight.w700, color: fgColor(context))),
        TextField(controller: _kind, decoration: bizInput(context, 'Document kind')),
        const SizedBox(height: 8),
        TextField(controller: _expires, decoration: bizInput(context, 'Expires at (optional)')),
        const SizedBox(height: 8),
        OutlinedButton(
          style: secondaryButtonStyle(context),
          onPressed: () async {
            if (_kind.text.trim().length < 2) {
              bizSnack(context, 'Enter the document kind');
              return;
            }
            await runBusy(
              context,
              () => EcosystemApi.addPartnerDocument(kind: _kind.text.trim(), expiresAt: _expires.text.trim()),
              success: 'Document saved',
            );
          },
          child: const Text('Add document'),
        ),
      ]),
    );
  }
}

String _flowKey() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return 'pay$now';
}

/// Recipient-only confirmation. The partner is not given this screen or the code.
class RecipientDeliveryCodePage extends StatefulWidget {
  const RecipientDeliveryCodePage({super.key, required this.jobId});
  final String jobId;
  @override
  State<RecipientDeliveryCodePage> createState() => _RecipientDeliveryCodePageState();
}

class _RecipientDeliveryCodePageState extends State<RecipientDeliveryCodePage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BizScaffold(
      title: 'Delivery code',
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          'Enter the code from your notification. Only the person receiving the parcel can confirm it. The partner cannot see this code.',
          style: TextStyle(color: mutedColor(context)),
        ),
        const SizedBox(height: 12),
        TextField(controller: _code, decoration: bizInput(context, 'Delivery code')),
        const SizedBox(height: 12),
        ElevatedButton(
          style: primaryButtonStyle(context),
          onPressed: () async {
            if (_code.text.trim().length < 4) {
              bizSnack(context, 'Enter the delivery code');
              return;
            }
            await runBusy(
              context,
              () => EcosystemApi.verifyProof(jobId: widget.jobId, code: _code.text.trim()),
              success: 'Code confirmed',
            );
          },
          child: const Text('Confirm delivery code'),
        ),
      ]),
    );
  }
}
