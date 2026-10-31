import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/services/api_service.dart';
import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/app_session_manager.dart';
import '/widgets/common/back_chevron.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/widgets/searchable_crypto_picker.dart';
import '/utils/user_error_message.dart';

class MerchantPaymentWidget extends StatefulWidget {
  const MerchantPaymentWidget({
    super.key,
    required this.merchantId,
    required this.businessName,
    required this.qrPayload,
  });

  static String routeName = 'MerchantPayment';
  static String routePath = '/merchantPayment';

  final String merchantId;
  final String businessName;
  final String qrPayload;

  @override
  State<MerchantPaymentWidget> createState() => _MerchantPaymentWidgetState();
}

class _MerchantPaymentWidgetState extends State<MerchantPaymentWidget> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final FocusNode pinFocusNode = FocusNode();
  bool isLoading = false;
  bool _pinEntryEnabled = false;
  bool _isBiometricChecking = false;
  bool _loadingQrPayload = false;
  List<String> _cryptoTokens = [];
  String error = '';
  late String _qrPayload;
  TransactionAuthenticationResult? _lastPinAuthResult;

  @override
  void initState() {
    super.initState();
    _qrPayload = widget.qrPayload.trim();
    if (_qrPayload.isEmpty) {
      _loadingQrPayload = true;
      _loadMerchantQrPayload();
    }
  }

  Future<void> _loadMerchantQrPayload() async {
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/merchants/public/${Uri.encodeComponent(widget.merchantId)}',
        requiresAuth: false,
      );
      final data = response['data'];
      final merchant = data is Map ? Map<String, dynamic>.from(data) : response;
      final payload =
          (merchant['qrPayload'] ?? merchant['qr_payload'])?.toString().trim();
      if (payload == null || payload.isEmpty) {
        throw StateError('This merchant QR code is missing its payment data.');
      }
      if (!mounted) return;
      setState(() {
        _qrPayload = payload;
        _loadingQrPayload = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Could not load merchant QR details: ${userErrorMessage(e)}';
        _loadingQrPayload = false;
      });
    }
  }

  Future<void> _startExternalPayment(String paymentMethod) async {
    if (paymentMethod == 'CRYPTO') {
      try {
        final response = await ApiService.request(
          method: 'GET',
          path: '/qr-payments/crypto-options',
          requiresAuth: false,
        );
        final data = response['data'];
        final rawTokens = data is Map ? data['tokens'] : null;
        if (rawTokens is! List) {
          throw const FormatException(
            'The server returned an invalid NOWPayments currency list.',
          );
        }
        _cryptoTokens = rawTokens
            .whereType<String>()
            .map((token) => token.trim().toLowerCase())
            .where((token) => token.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        if (_cryptoTokens.isEmpty) {
          throw const FormatException(
            'No cryptocurrencies are currently available through NOWPayments.',
          );
        }
      } catch (error) {
        _showSnack('Could not load NOWPayments currencies: ${userErrorMessage(error)}');
        return;
      }
    }

    if (_qrPayload.isEmpty) {
      _showSnack('Merchant payment details are still loading. Please retry.');
      return;
    }

    final kesController = TextEditingController();
    final emailController = TextEditingController();
    String? selectedCrypto =
        _cryptoTokens.isNotEmpty ? _cryptoTokens.first : null;
    Map<String, String>? details;

    try {
      details = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text('Pay ${widget.businessName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: kesController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (KES)',
                    ),
                  ),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email for payment receipt',
                    ),
                  ),
                  if (paymentMethod == 'CRYPTO') ...[
                    const SizedBox(height: 12),
                    SearchableCryptoPicker(
                      currencies: _cryptoTokens,
                      selectedCurrency: selectedCrypto,
                      onSelected: (token) =>
                          setDialogState(() => selectedCrypto = token),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, {
                  'amount': kesController.text.trim(),
                  'email': emailController.text.trim(),
                  if (selectedCrypto != null) 'crypto': selectedCrypto!,
                }),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    } finally {
      kesController.dispose();
      emailController.dispose();
    }

    if (details == null) return;
    final amountKes = double.tryParse(details['amount'] ?? '') ?? 0;
    if (!amountKes.isFinite || amountKes <= 0) {
      _showSnack('Enter an amount greater than 0');
      return;
    }
    final email = (details['email'] ?? '').trim();
    if (email.isEmpty) {
      _showSnack('Enter an email address for the payment receipt');
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await ApiService.request(
        method: 'POST',
        path: '/qr/checkout/payment',
        requiresAuth: false,
        body: {
          'qr_payload': _qrPayload,
          'amount_kes': amountKes,
          'payment_method': paymentMethod,
          'email': email,
          if (paymentMethod == 'CRYPTO') 'crypto': details['crypto'],
        },
      );
      final data = response['data'];
      final paymentUrl = data is Map ? data['payment_url']?.toString() : null;
      final uri = paymentUrl == null ? null : Uri.tryParse(paymentUrl);
      if (uri == null ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the payment provider checkout');
      }
    } catch (e) {
      if (mounted) _showSnack('Could not start payment: ${userErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    pinController.dispose();
    pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _promptBiometricForPinField() async {
    if (_lastPinAuthResult?.biometricUsed == true) {
      return;
    }

    try {
      setState(() => _isBiometricChecking = true);
      final authResult = await TransactionAuthorizationService()
          .authorizeTransaction(
            localizedReason: 'Confirm payment',
          )
          .then((r) => r.toTransactionAuthenticationResult());

      if (authResult.biometricUsed) {
        if (mounted) {
          setState(() {
            _lastPinAuthResult = authResult;
          });
        }

        await _submitPayment();
        return;
      }

      if (mounted) {
        setState(() {
          _lastPinAuthResult = authResult;
          _pinEntryEnabled = true;
        });
        pinFocusNode.requestFocus();
      }
    } finally {
      if (mounted) {
        setState(() => _isBiometricChecking = false);
      }
    }
  }

  Future<void> _submitPayment() async {
    if (isLoading) return;
    if (_qrPayload.isEmpty) {
      _showSnack('Merchant payment details are still loading. Please retry.');
      return;
    }
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final pin = pinController.text.trim();

    if (amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }

    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final authResult = _lastPinAuthResult ??
          await TransactionAuthorizationService()
              .authorizeTransaction(
                localizedReason: 'Confirm payment',
              )
              .then((r) => r.toTransactionAuthenticationResult());

      if (authResult?.biometricUsed == true) {
        await ApiService.merchantPay(
          qrPayload: _qrPayload,
          amount: amount,
          pin: null,
          biometricAuth: true,
          deviceFingerprint: authResult?.deviceFingerprint,
        );

        final current = FFAppState().walletBalance;
        FFAppState().walletBalance = current + amount;

        await AppSessionManager().syncNow(
          profileTimeoutSeconds: 5,
          walletTimeoutSeconds: 5,
          transactionsTimeoutSeconds: 5,
        );

        if (!mounted) return;
        _showSnack('common.transaction_success'.tr());
        context.pop();
        return;
      }

      if (authResult?.biometricUsed != true && pin.isEmpty) {
        _showSnack('common.pin_required'.tr());
        return;
      }

      await ApiService.merchantPay(
        qrPayload: _qrPayload,
        amount: amount,
        pin: pin,
        biometricAuth: null,
        deviceFingerprint: authResult?.deviceFingerprint,
      );

      // Optimistic update: ensure the app's main wallet UI reflects
      // the incoming platform credit immediately. The backend should
      // also record this on the server; this client-side increment
      // provides immediate feedback if the server-side platform
      // wallet update is not yet visible.
      final current = FFAppState().walletBalance;
      FFAppState().walletBalance = current + amount;

      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 5,
      );

      if (!mounted) return;
      _showSnack('common.transaction_success'.tr());
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = userErrorMessage(e);
      });
      _showSnack('common.transaction_failed'.tr());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Merchant Payment'),
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.primaryText),
      ),
      backgroundColor: theme.primaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName.isNotEmpty
                  ? 'Pay to ${widget.businessName}'
                  : 'Pay to merchant',
              style: theme.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (widget.businessName.isNotEmpty)
              Text(
                'Business: ${widget.businessName}',
                style: theme.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text('Merchant ID: ${widget.merchantId}', style: theme.bodyMedium),
            const SizedBox(height: 24),
            Text(
              'Pay with FARM wallet',
              style: theme.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Amount',
                style: theme.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                filled: true,
                fillColor: theme.secondaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.alternate),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_pinEntryEnabled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transaction PIN',
                      style: theme.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinController,
                    focusNode: pinFocusNode,
                    readOnly: _isBiometricChecking,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    onTap: () async {
                      if (!_pinEntryEnabled && !_isBiometricChecking) {
                        await _promptBiometricForPinField();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter PIN',
                      filled: true,
                      fillColor: theme.secondaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.alternate),
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Or pay in KES',
                    style:
                        theme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const <Map<String, String>>[
                        {'label': 'Card', 'method': 'CARD'},
                        {'label': 'Mobile money', 'method': 'MOBILE_MONEY'},
                        {'label': 'Bank transfer', 'method': 'BANK_TRANSFER'},
                        {'label': 'Crypto (NOWPayments)', 'method': 'CRYPTO'},
                      ])
                        OutlinedButton(
                          onPressed: isLoading || _loadingQrPayload
                              ? null
                              : () => _startExternalPayment(option['method']!),
                          child: Text(option['label']!),
                        ),
                    ],
                  ),
                ],
              )
            else if (!_isBiometricChecking)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _loadingQrPayload ? null : _promptBiometricForPinField,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Continue',
                      style: theme.titleMedium.copyWith(
                          color: AppTheme.onAccent,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 24),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(error,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            if (_loadingQrPayload)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            if (_pinEntryEnabled)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      isLoading || _loadingQrPayload ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: AppTheme.onAccent)
                      : Builder(builder: (context) {
                          return Text('Pay Merchant',
                              style: theme.titleMedium.copyWith(
                                  color: AppTheme.onAccent,
                                  fontWeight: FontWeight.bold));
                        }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
