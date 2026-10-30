import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '/backend/api_requests/nfc_pay_api.dart';
import '/pages/business/ops/ops_ui.dart';
import 'tap_pay_platform.dart';

String _err(Object e) => '$e'.replaceFirst('Exception: ', '');

/// Payee: enter an amount, then hold phones together (Android HCE) or show a QR.
class TapReceivePage extends StatefulWidget {
  const TapReceivePage({super.key});
  static String routeName = 'TapReceive';
  static String routePath = '/tap-receive';
  @override
  State<TapReceivePage> createState() => _TapReceiveState();
}

class _TapReceiveState extends State<TapReceivePage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  Map<String, dynamic>? _req;
  String _status = 'idle'; // idle | creating | pending | paid | expired | error
  String? _error;
  bool _nfc = false;
  bool _showQr = false;
  int _left = 0;
  Timer? _tick;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    TapPayPlatform.canEmit().then((v) => mounted ? setState(() => _nfc = v) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    TapPayPlatform.stopEmit();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final v = double.tryParse(_amount.text.trim());
    if (v == null || v <= 0) return setState(() => _error = 'Enter an amount');
    setState(() {
      _status = 'creating';
      _error = null;
    });
    try {
      final r = await NfcPayApi.create(v, description: _note.text);
      final exp = DateTime.parse('${r['expires_at']}').toLocal();
      if (_nfc) await TapPayPlatform.startEmit('${r['token']}', exp);
      setState(() {
        _req = r;
        _status = 'pending';
        _showQr = !_nfc; // iOS/web/NFC off: QR automatically
        _left = exp.difference(DateTime.now()).inSeconds;
      });
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left = exp.difference(DateTime.now()).inSeconds);
        if (_left <= 0 && _status == 'pending') _finish('expired');
      });
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final s = await NfcPayApi.status('${r['id']}');
          if (s['status'] == 'paid') _finish('paid');
        } catch (_) {}
      });
    } catch (e) {
      setState(() {
        _status = 'error';
        _error = _err(e);
      });
    }
  }

  void _finish(String s) {
    _tick?.cancel();
    _poll?.cancel();
    TapPayPlatform.stopEmit();
    if (mounted) setState(() => _status = s);
  }

  void _reset() {
    _finish('idle');
    setState(() => _req = null);
  }

  @override
  Widget build(BuildContext context) => BizScaffold(
        title: 'Receive by tap',
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (_status == 'idle' || _status == 'creating' || _status == 'error') ..._form(),
          if (_status == 'pending' && _req != null) ..._pending(),
          if (_status == 'paid') ..._done(Icons.check_circle_outline, 'Paid', 'You received ${money(_req?['payee_receives'])}.'),
          if (_status == 'expired') ..._done(Icons.timer_off_outlined, 'Request expired', 'Nobody paid in time. Create a new request.'),
        ]),
      );

  List<Widget> _form() => [
        Text('Amount to receive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fgColor(context))),
        const SizedBox(height: 12),
        TextField(
            key: const Key('tap-amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: bizInput(context, 'Amount (FARM)')),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 140, decoration: bizInput(context, 'Note (optional)')),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, key: const Key('tap-error'), style: TextStyle(color: fgColor(context))),
          ),
        const SizedBox(height: 16),
        ElevatedButton(
key: const Key('tap-create'),
          style: primaryButtonStyle(context),
          onPressed: _status == 'creating' ? null : _create,
          child: _status == 'creating'
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_status == 'error' ? 'Try again' : 'Create request'),
        ),
        const SizedBox(height: 12),
        Text(
            _nfc
                ? 'The payer holds their phone to yours. The request lasts about 60 seconds and can be paid once.'
                : 'NFC is not available on this device, so a QR code will be shown instead.',
            style: TextStyle(color: mutedColor(context), fontSize: 13)),
      ];

  List<Widget> _pending() {
    final r = _req!;
    return [
      Center(child: Text(money(r['amount']), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: fgColor(context)))),
      const SizedBox(height: 6),
      Center(child: Text('Expires in ${_left.clamp(0, 999)}s', key: const Key('tap-countdown'), style: TextStyle(color: mutedColor(context)))),
      const SizedBox(height: 20),
      if (_showQr)
        Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(key: const Key('tap-qr'), data: 'farmpay:${r['token']}', size: 220),
          ),
        )
      else
        Column(children: [
          Icon(Icons.contactless_outlined, size: 96, color: fgColor(context)),
          const SizedBox(height: 8),
          Text('Hold the payer\'s phone to the back of yours', style: TextStyle(color: fgColor(context))),
        ]),
      const SizedBox(height: 16),
      if (r['kind'] == 'merchant')
        KeyValue('Merchant fee (paid by you)', money(r['merchant_fee']))
      else
        KeyValue('Payer fee', money(r['payer_fee'])),
      KeyValue('You receive', money(r['payee_receives'])),
      const SizedBox(height: 12),
      Row(children: [
        if (_nfc)
          Expanded(
              child: OutlinedButton(
                  onPressed: () => setState(() => _showQr = !_showQr),
                  child: Text(_showQr ? 'Use tap instead' : 'Show QR instead'))),
        if (_nfc) const SizedBox(width: 12),
        Expanded(child: OutlinedButton(onPressed: _reset, child: const Text('Cancel'))),
      ]),
    ];
  }

  List<Widget> _done(IconData i, String t, String m) => [
        const SizedBox(height: 24),
        Icon(i, size: 72, color: fgColor(context)),
        const SizedBox(height: 12),
        Center(child: Text(t, key: Key('tap-$_status'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fgColor(context)))),
        const SizedBox(height: 6),
        Center(child: Text(m, textAlign: TextAlign.center, style: TextStyle(color: mutedColor(context)))),
        const SizedBox(height: 20),
        ElevatedButton(
style: primaryButtonStyle(context),
            onPressed: _reset,
            child: const Text('New request')),
      ];
}

/// Payer: read the tag (Android) or scan the QR, review payee/amount/fee, then PIN.
class TapPayPage extends StatefulWidget {
  const TapPayPage({super.key, this.initialToken});
  static String routeName = 'TapPay';
  static String routePath = '/tap-pay';
  final String? initialToken;
  @override
  State<TapPayPage> createState() => _TapPayState();
}

class _TapPayState extends State<TapPayPage> {
  String _mode = 'starting'; // starting | nfc | qr | loading | review | error | done
  String? _error;
  String? _token;
  Map<String, dynamic>? _req;
  Map<String, dynamic>? _receipt;
  bool _canNfc = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialToken ?? '').isNotEmpty) {
      _got(widget.initialToken!);
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    TapPayPlatform.cancelRead();
    super.dispose();
  }

  Future<void> _start() async {
    _canNfc = await TapPayPlatform.canRead();
    if (!mounted) return;
    if (!_canNfc) return setState(() => _mode = 'qr'); // iOS/web/NFC off: QR automatically
    setState(() => _mode = 'nfc');
    final raw = await TapPayPlatform.readOnce();
    if (!mounted || _mode != 'nfc') return;
    if (raw == null) {
      setState(() {
        _mode = 'error';
        _error = 'No request was read. Hold the phones together and try again, or scan the QR.';
      });
      return;
    }
    _got(raw);
  }

  Future<void> _got(String raw) async {
    final t = NfcPayApi.extractToken(raw);
    if (t == null) {
      setState(() {
        _mode = 'error';
        _error = 'That is not a FARM payment request.';
      });
      return;
    }
    setState(() {
      _token = t;
      _mode = 'loading';
    });
    try {
      final r = await NfcPayApi.resolve(t);
      if (mounted) setState(() {
        _req = r;
        _mode = 'review';
      });
    } catch (e) {
      if (mounted) setState(() {
        _mode = 'error';
        _error = _err(e);
      });
    }
  }

  Future<void> _confirm() async {
    final r = _req!;
    final payee = (r['payee'] as Map?) ?? const {};
    final pin = await confirmWithPin(context,
        title: 'Confirm payment',
        message: 'Pay ${money(r['amount'])} to ${payee['name']}.\n'
            'Your fee: ${money(r['payer_fee'])}\n'
            'Total from your wallet: ${money(r['payer_total'])}');
    if (pin == null || !mounted) return;
    final res = await runBusy(context, () => NfcPayApi.pay(_token!, pin), success: 'Payment sent');
    if (res != null && mounted) setState(() {
      _receipt = res;
      _mode = 'done';
    });
  }

  void _retry() {
    setState(() {
      _error = null;
      _req = null;
      _token = null;
      _mode = 'starting';
    });
    _start();
  }

  @override
  Widget build(BuildContext context) => BizScaffold(title: 'Pay by tap', body: _body());

  Widget _body() {
    switch (_mode) {
      case 'nfc':
        return _center([
          Icon(Icons.contactless_outlined, size: 96, color: fgColor(context)),
          const SizedBox(height: 12),
          Text('Hold your phone to the other phone', style: TextStyle(color: fgColor(context), fontSize: 16)),
          const SizedBox(height: 16),
          OutlinedButton(
              onPressed: () {
                TapPayPlatform.cancelRead();
                setState(() => _mode = 'qr');
              },
              child: const Text('Scan QR instead')),
        ]);
      case 'qr':
        return Column(children: [
          Expanded(
            child: MobileScanner(
              key: const Key('tap-scanner'),
              onDetect: (c) {
                final v = c.barcodes.isEmpty ? null : c.barcodes.first.rawValue;
                if (v != null && _mode == 'qr') _got(v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Scan the payment request QR', style: TextStyle(color: mutedColor(context))),
          ),
        ]);
      case 'review':
        final r = _req!;
        final payee = (r['payee'] as Map?) ?? const {};
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text('Pay', style: TextStyle(color: mutedColor(context))),
          Text('${payee['name']}', key: const Key('tap-payee'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fgColor(context))),
          if (payee['username'] != null) Text('@${payee['username']}', style: TextStyle(color: mutedColor(context))),
          const SizedBox(height: 16),
          KeyValue('Amount', money(r['amount'])),
          KeyValue(r['kind'] == 'merchant' ? 'Your fee (merchant pays its fee)' : 'Your fee', money(r['payer_fee'])),
          KeyValue('Total from your wallet', money(r['payer_total'])),
          if ((r['description'] ?? '').toString().isNotEmpty) KeyValue('Note', '${r['description']}'),
          const SizedBox(height: 20),
          ElevatedButton(
key: const Key('tap-confirm'),
              style: primaryButtonStyle(context),
              onPressed: _confirm,
              child: const Text('Confirm with PIN')),
          TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Cancel')),
        ]);
      case 'done':
        return _center([
          Icon(Icons.check_circle_outline, size: 72, color: fgColor(context)),
          const SizedBox(height: 12),
          Text('Paid ${money(_receipt?['amount'] ?? _req?['amount'])}', key: const Key('tap-done'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fgColor(context))),
          Text('Ref ${_receipt?['transaction_reference'] ?? ''}', style: TextStyle(color: mutedColor(context))),
        ]);
      case 'error':
        return _center([
          Icon(Icons.error_outline, size: 64, color: fgColor(context)),
          const SizedBox(height: 12),
          Text(_error ?? 'Something went wrong', key: const Key('tap-pay-error'), textAlign: TextAlign.center, style: TextStyle(color: fgColor(context))),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _retry, child: const Text('Try again')),
        ]);
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _center(List<Widget> c) => Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: c)));
}
