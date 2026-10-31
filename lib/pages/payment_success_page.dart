import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/qr_public_payment_api.dart';
import '/utils/user_error_message.dart';

class PaymentSuccessPage extends StatefulWidget {
  const PaymentSuccessPage({super.key, this.reference});

  final String? reference;

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=farmapp.africa';

  Timer? _pollTimer;
  bool _checking = true;
  bool _verified = false;
  String? _error;
  String _merchantName = 'merchant';
  double? _amount;
  String _currency = 'KES';
  bool _pollInProgress = false;
  bool _downloadingReceipt = false;

  @override
  void initState() {
    super.initState();
    if (widget.reference == null || widget.reference!.trim().isEmpty) {
      _checking = false;
      _error = 'Payment reference is missing. Please check your receipt.';
      return;
    }
    _verifyPayment();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _verifyPayment(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _verifyPayment() async {
    if (_pollInProgress || _verified || !mounted) return;
    _pollInProgress = true;
    try {
      final response = await QrPublicPaymentApi.get(
        '/qr-payments/verify/${Uri.encodeComponent(widget.reference!.trim())}',
      );
      final data = response['data'];
      if (data is! Map) {
        throw const FormatException('Payment status was not returned.');
      }
      final status = data['status']?.toString().toLowerCase();
      if (!mounted) return;
      setState(() {
        _merchantName = data['business_name']?.toString() ?? 'merchant';
        _amount = (data['amount'] as num?)?.toDouble();
        _currency = data['currency']?.toString() ?? 'KES';
        _verified = status == 'completed';
        _checking = status != 'completed' && status != 'failed';
        _error = status == 'failed' ? 'The payment was not completed.' : null;
      });
      if (_verified || status == 'failed') {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = true;
        _error = 'We are still checking your payment. ${userErrorMessage(error)}';
      });
    } finally {
      _pollInProgress = false;
    }
  }

  Future<void> _openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store link.')),
      );
    }
  }

  Future<void> _downloadReceipt() async {
    if (_downloadingReceipt || widget.reference == null) return;
    setState(() => _downloadingReceipt = true);
    try {
      final response = await QrPublicPaymentApi.get(
        '/qr-payments/receipt/${Uri.encodeComponent(widget.reference!.trim())}/download',
      );
      final data = response['data'];
      final url = data is Map ? data['url']?.toString() : null;
      final uri = url == null ? null : Uri.tryParse(url);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the receipt download.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not download receipt: ${userErrorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _checking && !_verified
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 20),
                          Text(
                            'Verifying your payment…',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                          ],
                        ],
                      )
                    : _verified
                        ? _successContent(context)
                        : _failureContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successContent(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 72),
          const SizedBox(height: 16),
          Text(
            'Payment Successful to $_merchantName',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (_amount != null) ...[
            const SizedBox(height: 8),
            Text('${_amount!.toStringAsFixed(2)} $_currency'),
          ],
          const SizedBox(height: 24),
          const Text(
            'Payment Done!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get the FARM app to pay merchants quickly from your wallet.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openPlayStore,
            icon: const Icon(Icons.download),
            label: const Text('Download app'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _downloadingReceipt ? null : _downloadReceipt,
            icon: _downloadingReceipt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(
              _downloadingReceipt ? 'Preparing receipt…' : 'Download receipt',
            ),
          ),
        ],
      );

  Widget _failureContent(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Payment status is unavailable.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _checking = true;
              });
              _pollTimer = Timer.periodic(
                const Duration(seconds: 3),
                (_) => _verifyPayment(),
              );
              _verifyPayment();
            },
            child: const Text('Check again'),
          ),
        ],
      );
}
