import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '/backend/services/api_service.dart';

/// Full-screen, in-app NOWPayments checkout for wallet deposits.
///
/// Step 1: choose asset, see "Amount to pay X ~ $Y", tap "Next step".
/// Step 2: send to the address (QR, copy, countdown, live status).
/// Pops `true` when credited, `false` when failed/expired, `null` if closed.
class CryptoCheckoutPage extends StatefulWidget {
  const CryptoCheckoutPage({
    super.key,
    required this.amountUsd,
    required this.tokens,
    this.initialToken,
  });

  final double amountUsd;
  final List<String> tokens;
  final String? initialToken;

  @override
  State<CryptoCheckoutPage> createState() => _CryptoCheckoutPageState();
}

class _CryptoCheckoutPageState extends State<CryptoCheckoutPage> {
  static const _brand = Color(0xFF2E7D32);

  String? _token;
  bool _estimating = false;
  double? _estimate;
  double? _minimumUsd;
  bool _meetsMinimum = true;
  String? _estimateError;
  int _estimateSeq = 0;

  bool _creating = false;
  String? _createError;

  // Step 2 state
  String? _paymentId;
  String? _address;
  String? _payAmount;
  String? _payCurrency;
  String? _extraId;
  DateTime? _expiresAt;
  String _status = 'waiting';
  String? _statusError;
  bool _checking = false;
  Timer? _pollTimer;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken ??
        (widget.tokens.isNotEmpty ? widget.tokens.first : null);
    if (_token != null) _loadEstimate();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadEstimate() async {
    final token = _token;
    if (token == null) return;
    final seq = ++_estimateSeq;
    setState(() {
      _estimating = true;
      _estimateError = null;
    });
    try {
      final response = await ApiService.request(
        method: 'GET',
        path:
            '/wallet/deposit/crypto/estimate?amount=${widget.amountUsd.toStringAsFixed(2)}&currency=${Uri.encodeComponent(token.toLowerCase())}',
        requiresAuth: true,
      );
      if (!mounted || seq != _estimateSeq) return;
      final data = response['data'];
      if (data is! Map) throw const FormatException('Invalid estimate');
      setState(() {
        _estimate = double.tryParse('${data['estimated_amount']}');
        _minimumUsd = double.tryParse('${data['minimum_usd']}');
        _meetsMinimum = data['meets_minimum'] != false;
      });
    } catch (e) {
      if (!mounted || seq != _estimateSeq) return;
      setState(() {
        _estimate = null;
        _estimateError = 'Could not get a quote for this asset. Try another.';
      });
    } finally {
      if (mounted && seq == _estimateSeq) setState(() => _estimating = false);
    }
  }

  Future<void> _createPayment() async {
    if (_token == null || _creating) return;
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      final response = await ApiService.request(
        method: 'POST',
        path: '/wallet/deposit/crypto',
        body: {
          'price_amount': widget.amountUsd,
          'price_currency': 'usd',
          'pay_currency': _token!.toLowerCase(),
        },
        requiresAuth: true,
      );
      final p = response['data'];
      if (p is! Map ||
          (p['payment_id']?.toString() ?? '').isEmpty ||
          (p['pay_address']?.toString() ?? '').isEmpty ||
          p['pay_amount'] == null) {
        throw const FormatException(
            'NOWPayments returned incomplete payment instructions.');
      }
      if (!mounted) return;
      setState(() {
        _paymentId = p['payment_id'].toString();
        _address = p['pay_address'].toString();
        _payAmount = p['pay_amount'].toString();
        _payCurrency =
            (p['pay_currency']?.toString() ?? _token!).toUpperCase();
        final extra = p['payin_extra_id']?.toString();
        _extraId = (extra == null || extra.isEmpty || extra == 'null')
            ? null
            : extra;
        _expiresAt = _parseExpiry(
            (p['expiration_estimate'] ?? p['expiration_estimate_date'])
                ?.toString());
        _status = p['payment_status']?.toString() ?? 'waiting';
      });
      _pollTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _checkStatus());
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() => _createError =
            e is ApiServiceException ? e.message : 'Could not start the payment: $e');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  DateTime? _parseExpiry(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toLocal();
    final n = int.tryParse(value);
    if (n == null) return null;
    if (n > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(
          n > 1000000000000 ? n : n * 1000);
    }
    return DateTime.now().add(Duration(seconds: n));
  }

  String get _countdown {
    final r = _expiresAt?.difference(DateTime.now());
    if (r == null) return '--:--';
    if (r.isNegative) return 'Expired';
    final h = r.inHours;
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _checkStatus() async {
    if (_checking || _paymentId == null) return;
    _checking = true;
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/wallet/deposit/status/${Uri.encodeComponent(_paymentId!)}',
        requiresAuth: true,
      );
      final data = response['data'];
      if (data is! Map) throw const FormatException('Invalid status');
      final status = data['status']?.toString().toLowerCase() ?? 'unknown';
      if (!mounted) return;
      setState(() {
        _status = status;
        _statusError = null;
      });
      if (['finished', 'confirmed'].contains(status) &&
          data['credited'] == true) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(true);
      } else if (['failed', 'expired', 'refunded'].contains(status)) {
        _pollTimer?.cancel();
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) setState(() => _statusError = 'Will retry shortly');
    } finally {
      _checking = false;
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label copied')));
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(8);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }

  String get _statusLabel => switch (_status) {
        'waiting' => 'Waiting for payment',
        'confirming' => 'Payment detected, confirming on the network',
        'confirmed' || 'sending' => 'Confirmed, crediting your wallet',
        'partially_paid' => 'Partially paid — send the remaining amount',
        'finished' => 'Completed',
        _ => _status,
      };

  TextStyle _t(double size, {FontWeight w = FontWeight.w500, Color? c}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c);

  @override
  Widget build(BuildContext context) {
    final step2 = _paymentId != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text('Crypto deposit', style: _t(17, w: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 12)
              ],
            ),
            child: step2 ? _buildPay() : _buildChoose(),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _brand,
          child: Text('F', style: _t(18, w: FontWeight.w800, c: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FARM_APP', style: _t(16, w: FontWeight.w700)),
            Text('Wallet deposit',
                style: _t(12, c: Colors.black54)),
          ]),
        ),
        Text('\$${widget.amountUsd.toStringAsFixed(2)}',
            style: _t(16, w: FontWeight.w700)),
      ]);

  Widget _buildChoose() {
    final symbol = (_token ?? '').toUpperCase();
    final canContinue =
        _token != null && !_estimating && _estimate != null && _meetsMinimum;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(),
      const Divider(height: 32),
      Text('Choose asset', style: _t(13, c: Colors.black54)),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: _token,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: [
          for (final t in widget.tokens)
            DropdownMenuItem(
                value: t,
                child: Text(t.toUpperCase(), style: _t(15, w: FontWeight.w600))),
        ],
        onChanged: _creating
            ? null
            : (v) {
                setState(() {
                  _token = v;
                  _estimate = null;
                });
                _loadEstimate();
              },
      ),
      const SizedBox(height: 20),
      Text('Amount to pay', style: _t(13, c: Colors.black54)),
      const SizedBox(height: 6),
      if (_estimating)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        )
      else if (_estimate != null)
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '${_fmt(_estimate!)} $symbol',
                style: _t(22, w: FontWeight.w800, c: Colors.black87)),
            TextSpan(
                text: '  ~ \$${widget.amountUsd.toStringAsFixed(2)}',
                style: _t(14, c: Colors.black54)),
          ]),
        )
      else
        Text('—', style: _t(22, w: FontWeight.w800)),
      if (!_meetsMinimum && _minimumUsd != null)
        _errorBox(
            'Minimum for $symbol is about \$${_minimumUsd!.toStringAsFixed(2)}. Go back and increase the amount or choose another asset.'),
      if (_estimateError != null) _errorBox(_estimateError!),
      if (_createError != null) _errorBox(_createError!),
      const SizedBox(height: 24),
      SizedBox(
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: AppTheme.onAccent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: canContinue && !_creating ? _createPayment : null,
          child: _creating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.onAccent))
              : Text('Next step', style: _t(16, w: FontWeight.w700, c: Colors.white)),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'The final crypto amount is locked when you tap Next step.',
        textAlign: TextAlign.center,
        style: _t(11, c: Colors.black45),
      ),
    ]);
  }

  Widget _buildPay() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(),
      const Divider(height: 32),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Time left', style: _t(13, c: Colors.black54)),
        Text(_countdown, style: _t(15, w: FontWeight.w700)),
      ]),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
              data: _address!, size: 200, backgroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: 16),
      _copyRow('Amount', '$_payAmount $_payCurrency', _payAmount!),
      _copyRow('Address', _address!, _address!),
      if (_extraId != null) _copyRow('Memo / Tag (required)', _extraId!, _extraId!),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _brand)),
          const SizedBox(width: 10),
          Expanded(child: Text(_statusLabel, style: _t(13, w: FontWeight.w600))),
        ]),
      ),
      if (_statusError != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(_statusError!, style: _t(11, c: Colors.black45)),
        ),
      const SizedBox(height: 12),
      Text(
        'Send exactly $_payAmount $_payCurrency on the correct network. Your wallet is credited automatically after confirmation.',
        style: _t(12, c: Colors.black54),
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _checking ? null : _checkStatus,
        child: Text('Check status', style: _t(14, w: FontWeight.w600)),
      ),
    ]);
  }

  Widget _copyRow(String label, String display, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: _t(11, c: Colors.black54)),
                const SizedBox(height: 2),
                SelectableText(display, style: _t(14, w: FontWeight.w700)),
              ]),
            ),
            IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () => _copy(value, label),
            ),
          ]),
        ),
      );

  Widget _errorBox(String msg) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(msg, style: _t(12, c: const Color(0xFFC62828))),
      );
}
