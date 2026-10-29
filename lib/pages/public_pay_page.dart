import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/qr_public_payment_api.dart';
import '/widgets/searchable_crypto_picker.dart';

class PublicPayPage extends StatefulWidget {
  const PublicPayPage({super.key, required this.merchantId});

  final String merchantId;

  @override
  State<PublicPayPage> createState() => _PublicPayPageState();
}

class _PublicPayPageState extends State<PublicPayPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _emailController = TextEditingController();

  Map<String, dynamic>? _merchant;
  List<String> _cryptoTokens = [];
  String? _selectedCryptoToken;
  String _method = 'mpesa';
  String? _error;
  bool _loadingMerchant = true;
  bool _loadingCryptoTokens = false;
  bool _submitting = false;
  bool _openingFarmApp = false;
  bool _showWebCheckout = false;

  bool get _invalidMerchantId =>
      widget.merchantId.isEmpty ||
      widget.merchantId == 'ANYID' ||
      widget.merchantId.length < 10;

  @override
  void initState() {
    super.initState();
    if (_invalidMerchantId) {
      _loadingMerchant = false;
      _error = 'Invalid QR Code. Please ask the merchant to regenerate.';
    } else {
      _loadMerchant();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchant() async {
    try {
      final response = await QrPublicPaymentApi.get(
        '/merchants/public/${Uri.encodeComponent(widget.merchantId)}',
      );
      final data = response['data'];
      if (data is! Map) {
        throw const FormatException('Merchant details were not returned.');
      }
      if (!mounted) return;
      setState(() {
        _merchant = Map<String, dynamic>.from(data);
        _loadingMerchant = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loadingMerchant = false;
      });
    }
  }

  Future<void> _startPayment() async {
    if (_method == 'crypto' &&
        (_selectedCryptoToken == null ||
            !_cryptoTokens.contains(_selectedCryptoToken))) {
      setState(() => _error = 'Choose a cryptocurrency before continuing.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final amount = double.parse(_amountController.text.trim());
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response =
          await QrPublicPaymentApi.post('/qr-payments/initialize', {
            'merchantId': widget.merchantId,
            'amount': amount,
            'method': _method,
            'guestEmail': _emailController.text.trim(),
            if (_method == 'crypto') 'crypto': _selectedCryptoToken,
          });
      final data = response['data'];
      final paymentUrl = data is Map
          ? data['authorization_url']?.toString()
          : null;
      final uri = paymentUrl == null ? null : Uri.tryParse(paymentUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the payment provider checkout.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _loadCryptoTokens() async {
    if (_loadingCryptoTokens || _cryptoTokens.isNotEmpty) return;
    setState(() {
      _loadingCryptoTokens = true;
      _error = null;
    });
    try {
      final response = await QrPublicPaymentApi.get(
        '/qr-payments/crypto-options',
      );
      final data = response['data'];
      final rawTokens = data is Map ? data['tokens'] : null;
      if (rawTokens is! List) {
        throw const FormatException(
          'The server returned an invalid NOWPayments currency list.',
        );
      }
      final tokens =
          rawTokens
              .whereType<String>()
              .map((token) => token.trim().toLowerCase())
              .where((token) => token.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (tokens.isEmpty) {
        throw const FormatException(
          'No cryptocurrencies are currently available through NOWPayments.',
        );
      }
      if (!mounted) return;
      setState(() {
        _cryptoTokens = tokens;
        _selectedCryptoToken = tokens.first;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCryptoTokens = false);
    }
  }

  Future<void> _openFarmApp() async {
    final farmName = _merchant?['farmName']?.toString().trim();
    final storedQrPayload = _merchant?['qrPayload']?.toString().trim();
    final qrPayload = storedQrPayload != null && storedQrPayload.isNotEmpty
        ? storedQrPayload
        : 'https://farmpay.africa/checkout/'
              '${Uri.encodeComponent(widget.merchantId)}';
    final deepLink = Uri(
      scheme: 'farm',
      host: 'farm.com',
      path: '/pay',
      queryParameters: {
        'merchantId': widget.merchantId,
        'businessName': farmName == null || farmName.isEmpty
            ? 'Merchant'
            : farmName,
        'qrPayload': qrPayload,
      },
    );

    setState(() {
      _openingFarmApp = true;
      _error = null;
    });
    try {
      final opened = await launchUrl(
        deepLink,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        setState(() {
          _error = 'Could not open FARM. Make sure the app is installed.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not open FARM: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _openingFarmApp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmName = _merchant?['farmName']?.toString() ?? 'merchant';
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
                padding: const EdgeInsets.all(24),
                child: _loadingMerchant
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null && _merchant == null
                    ? _ErrorMessage(message: _error!)
                    : Form(
                        key: _formKey,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            Text(
                              'Pay $farmName',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text('Securely pay this FARM merchant.'),
                            const SizedBox(height: 16),
                            if (!_showWebCheckout) ...[
                              OutlinedButton.icon(
                                onPressed: _openingFarmApp
                                    ? null
                                    : _openFarmApp,
                                icon: _openingFarmApp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.open_in_new),
                                label: const Text('I have the FARM app'),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'No app? Pay securely here with a payment provider.',
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: () =>
                                    setState(() => _showWebCheckout = true),
                                child: const Text('Continue on web'),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: _openingFarmApp
                                    ? null
                                    : _openFarmApp,
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open in the FARM app'),
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text('Pay securely on the web.'),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Amount (KES)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final amount = double.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  if (amount == null ||
                                      !amount.isFinite ||
                                      amount <= 0) {
                                    return 'Enter an amount greater than 0.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _method,
                                decoration: const InputDecoration(
                                  labelText: 'Payment method',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'mpesa',
                                    child: Text('M-Pesa'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'card',
                                    child: Text('Bank card'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'bank',
                                    child: Text('Bank transfer'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'crypto',
                                    child: Text('Crypto (NOWPayments)'),
                                  ),
                                ],
                                onChanged: _submitting
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => _method = value);
                                          if (value == 'crypto') {
                                            _loadCryptoTokens();
                                          }
                                        }
                                      },
                              ),
                              if (_method == 'crypto') ...[
                                const SizedBox(height: 16),
                                if (_loadingCryptoTokens)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else if (_cryptoTokens.isNotEmpty) ...[
                                  SearchableCryptoPicker(
                                    currencies: _cryptoTokens,
                                    selectedCurrency: _selectedCryptoToken,
                                    enabled: !_submitting,
                                    label: 'Preferred cryptocurrency',
                                    onSelected: (token) => setState(
                                      () => _selectedCryptoToken = token,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'NOWPayments will show its full currency list at checkout, where you can choose or change your coin.',
                                    ),
                                  ),
                                ] else
                                  TextButton(
                                    onPressed: _loadCryptoTokens,
                                    child: const Text(
                                      'Retry cryptocurrency list',
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty ||
                                      !RegExp(
                                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                      ).hasMatch(email)) {
                                    return 'Enter a valid email address.';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Email for payment receipt',
                                  hintText: 'you@example.com',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _submitting ? null : _startPayment,
                                child: _submitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Continue to payment'),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LegacyMerchantQrRedirectPage extends StatefulWidget {
  const LegacyMerchantQrRedirectPage({super.key, required this.qrPayload});

  final String? qrPayload;

  @override
  State<LegacyMerchantQrRedirectPage> createState() =>
      _LegacyMerchantQrRedirectPageState();
}

class _LegacyMerchantQrRedirectPageState
    extends State<LegacyMerchantQrRedirectPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveMerchantQr();
  }

  Future<void> _resolveMerchantQr() async {
    final encodedPayload = widget.qrPayload?.trim();
    if (encodedPayload == null || encodedPayload.isEmpty) {
      setState(() => _error = 'Merchant QR information is missing.');
      return;
    }

    String payload;
    try {
      payload = utf8.decode(
        base64Url.decode(base64Url.normalize(encodedPayload)),
      );
    } on FormatException {
      payload = encodedPayload;
    }

    try {
      final response = await QrPublicPaymentApi.get(
        '/qr/checkout/merchant?qr_payload=${Uri.encodeComponent(payload)}',
      );
      final data = response['data'];
      final merchantId = data is Map
          ? data['merchant_id']?.toString().trim()
          : null;
      if (merchantId == null || merchantId.isEmpty) {
        throw const FormatException('Merchant details were not returned.');
      }
      if (mounted) context.go('/pay/${Uri.encodeComponent(merchantId)}');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F6F4),
    body: SafeArea(
      child: Center(
        child: _error == null
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Opening secure merchant checkout…'),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
      ),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
