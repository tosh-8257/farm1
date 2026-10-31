import 'dart:async';
import 'package:flutter/material.dart';
import '/components/farm_coin_icon.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/services/api_service.dart';
// Removed unused import
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/kyc_required_widget.dart';
import '/services/transaction_receipt_service.dart';
import '/services/paystack_inline_checkout.dart';
import '/widgets/searchable_crypto_picker.dart';
import 'crypto_checkout_page.dart';
import '/utils/user_error_message.dart';

class DepositpageWidget extends StatefulWidget {
  const DepositpageWidget({super.key});

  static String routeName = 'DepositPage';
  static String routePath = '/depositpage';

  @override
  State<DepositpageWidget> createState() => _DepositpageWidgetState();
}

class _DepositpageWidgetState extends State<DepositpageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController amountController = TextEditingController();

  String selectedCurrency = 'KES';
  String selectedMethod =
      'MOBILE_MONEY'; // CARD | BANK_TRANSFER | MOBILE_MONEY | CRYPTO
  String? _selectedCryptoToken;
  List<String> _cryptoTokens = [];
  bool _loadingCryptoTokens = false;
  bool _cryptoTokensLoaded = false;
  String? _cryptoTokensError;
  double? _cryptoMinimumAmount;
  double? _cryptoMinimumUsd;
  bool _loadingCryptoMinimum = false;
  String? _cryptoMinimumError;

  bool isLoading = false;
  bool loadingWallet = true;

  double walletBalance = 0;
  List<dynamic> recentDeposits = [];
  final Set<int> _selectedDeposits = <int>{};

  // Deposit fees are disabled. The amount entered by the user is the amount credited.
  final Map<String, double> _feeRates = {
    'CARD': 0.0,
    'BANK_TRANSFER': 0.0,
    'MOBILE_MONEY': 0.0,
    'CRYPTO': 0.0,
  };

  final Map<String, Map<String, double?>> _depositLimits = {
    'CARD': {'min': 10, 'max': 19999},
    'BANK_TRANSFER': {'min': 10, 'max': 999999},
    'MOBILE_MONEY': {'min': 10, 'max': 249000},
    'CRYPTO': {'min': 0, 'max': null},
  };

  double get amount => double.tryParse(amountController.text.trim()) ?? 0;
  double get feeRate => _feeRates[selectedMethod] ?? 0.0;
  double get fee => 0;
  double get total => amount;

  Map<String, double?> get _activeDepositLimits =>
      _depositLimits[selectedMethod] ?? _depositLimits['MOBILE_MONEY']!;
  double get _activeDepositMin => selectedMethod == 'CRYPTO'
      ? (_cryptoMinimumUsd == null
            ? 0
            : (_cryptoMinimumUsd! * 100).ceilToDouble() / 100)
      : (_activeDepositLimits['min'] ?? 10);
  double? get _activeDepositMax => _activeDepositLimits['max'];
  String get _amountCurrency =>
      selectedMethod == 'CRYPTO' ? 'USD' : selectedCurrency;
  bool get _hasValidDepositAmount =>
      amount > 0 &&
      (selectedMethod != 'CRYPTO' || _cryptoMinimumUsd != null) &&
      amount >= _activeDepositMin &&
      (_activeDepositMax == null || amount <= _activeDepositMax!);

  Future<void> _fetchCryptoTokens() async {
    if (_loadingCryptoTokens || _cryptoTokensLoaded) return;
    setState(() {
      _loadingCryptoTokens = true;
      _cryptoTokensError = null;
    });

    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/wallet/deposit/crypto/currencies',
        requiresAuth: true,
      );
      final rawCurrencies = response['data'];
      if (rawCurrencies is! List) {
        throw const FormatException(
          'The server returned an invalid NOWPayments currency list.',
        );
      }
      final tokens =
          rawCurrencies
              .whereType<String>()
              .map((currency) => currency.trim().toUpperCase())
              .where((currency) => currency.isNotEmpty)
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
        _cryptoTokensLoaded = true;
        if (!_cryptoTokens.contains(_selectedCryptoToken)) {
          _selectedCryptoToken = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cryptoTokens = [];
        _cryptoTokensError = userErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _loadingCryptoTokens = false);
    }
  }

  Future<void> _fetchCryptoMinimum(String currency) async {
    setState(() {
      _loadingCryptoMinimum = true;
      _cryptoMinimumAmount = null;
      _cryptoMinimumUsd = null;
      _cryptoMinimumError = null;
    });
    try {
      final response = await ApiService.request(
        method: 'GET',
        path:
            '/wallet/deposit/crypto/minimum/${Uri.encodeComponent(currency.toLowerCase())}',
        requiresAuth: true,
      );
      final data = response['data'];
      final minimumAmount = data is Map
          ? double.tryParse(data['minimumAmount']?.toString() ?? '')
          : null;
      final minimumUsd = data is Map
          ? double.tryParse(data['minimumUsd']?.toString() ?? '')
          : null;
      if (minimumAmount == null ||
          !minimumAmount.isFinite ||
          minimumAmount <= 0 ||
          minimumUsd == null ||
          !minimumUsd.isFinite ||
          minimumUsd <= 0) {
        throw const FormatException(
          'NOWPayments returned an invalid minimum for this currency.',
        );
      }
      if (!mounted || _selectedCryptoToken != currency) return;
      setState(() {
        _cryptoMinimumAmount = minimumAmount;
        _cryptoMinimumUsd = minimumUsd;
      });
    } catch (error) {
      if (!mounted || _selectedCryptoToken != currency) return;
      setState(() => _cryptoMinimumError = userErrorMessage(error));
    } finally {
      if (mounted && _selectedCryptoToken == currency) {
        setState(() => _loadingCryptoMinimum = false);
      }
    }
  }

  String _formatAmount(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value);
  }

  String _formatMinimumUsd(double value) {
    final formatter = NumberFormat('#,##0.########', 'en_US')
      ..minimumFractionDigits = 2;
    return formatter.format(value);
  }

  String _formatMinimumCrypto(double value) {
    return NumberFormat('#,##0.##################', 'en_US').format(value);
  }

  double get _cryptoMinimumUsdToEnter => _cryptoMinimumUsd == null
      ? 0
      : (_cryptoMinimumUsd! * 100).ceilToDouble() / 100;

  String get _depositValidationMessage {
    final currency = _amountCurrency;
    if (selectedMethod == 'CRYPTO' && _selectedCryptoToken == null) {
      return 'Select a cryptocurrency to see its minimum deposit amount';
    }
    if (selectedMethod == 'CRYPTO' && _loadingCryptoMinimum) {
      return 'Loading ${_selectedCryptoToken!.toUpperCase()} minimum...';
    }
    if (selectedMethod == 'CRYPTO' && _cryptoMinimumError != null) {
      return 'Could not load the minimum for ${_selectedCryptoToken!.toUpperCase()}';
    }
    if (selectedMethod == 'CRYPTO' && _cryptoMinimumUsd == null) {
      return 'Select a cryptocurrency to see its minimum deposit amount';
    }
    if (amount <= 0) {
      final minimum = selectedMethod == 'CRYPTO'
          ? _formatMinimumUsd(_activeDepositMin)
          : _formatAmount(_activeDepositMin);
      return 'Range: $currency $minimum${_activeDepositMax == null ? '+' : ' - $currency ${_formatAmount(_activeDepositMax!)}'}';
    }
    if (_hasValidDepositAmount) {
      final minimum = selectedMethod == 'CRYPTO'
          ? _formatMinimumUsd(_activeDepositMin)
          : _formatAmount(_activeDepositMin);
      return 'Range: $currency $minimum${_activeDepositMax == null ? '+' : ' - $currency ${_formatAmount(_activeDepositMax!)}'}';
    }
    final minimum = selectedMethod == 'CRYPTO'
        ? _formatMinimumUsd(_activeDepositMin)
        : _formatAmount(_activeDepositMin);
    final maxText = _activeDepositMax == null
        ? ' and above'
        : ' and $currency ${_formatAmount(_activeDepositMax!)}';
    return 'Amount must be at least $currency $minimum$maxText';
  }

  @override
  void initState() {
    super.initState();
    _fetchWallet();
    _fetchHistory();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  bool get isKycApproved {
    final status = FFAppState().kycStatus.trim().toLowerCase();
    return ['verified', 'approved', 'complete', 'success'].contains(status);
  }

  // ── Fetch wallet balance ─────────────────────────────────────────────────────────────────
  Future<void> _fetchWallet() async {
    try {
      final resp = await ApiService.getWallet();
      if (!mounted) return;
      final data = resp['data'] as Map<String, dynamic>? ?? resp;
      final bal = (data['balance'] ?? data['available_balance'] ?? 0)
          .toString();
      setState(() => walletBalance = double.tryParse(bal) ?? 0);
    } catch (e) {
      debugPrint('fetchWallet error: $e');
    } finally {
      if (mounted) setState(() => loadingWallet = false);
    }
  }

  // ── Fetch deposit history ────────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    try {
      final resp = await ApiService.getDepositHistory();
      if (!mounted) return;
      final items = resp['data'] is List ? resp['data'] as List : [];
      setState(() => recentDeposits = items);
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
  }

  Future<Map<String, String>> _fetchPaystackDepositUserDetails({
    required bool requirePhone,
  }) async {
    final profileResponse = await ApiService.getProfile();
    final profile = profileResponse['data'] is Map
        ? Map<String, dynamic>.from(profileResponse['data'] as Map)
        : profileResponse;
    final email = (profile['email'] ?? FFAppState().email).toString().trim();
    final phone = (profile['phone'] ?? FFAppState().phone).toString().trim();

    if (email.isEmpty) {
      throw StateError(
        'Add an email address to your account before making a Paystack deposit.',
      );
    }
    if (requirePhone && phone.isEmpty) {
      throw StateError(
        'Add a phone number to your account before making a mobile money deposit.',
      );
    }

    FFAppState().email = email;
    if (phone.isNotEmpty) FFAppState().phone = phone;
    return {'email': email, if (phone.isNotEmpty) 'phone': phone};
  }

  Map<String, dynamic> _depositReceipt(
    Map<String, dynamic> deposit,
    Map<String, dynamic> metadata,
  ) {
    final receipt = Map<String, dynamic>.from(deposit);
    final farmAmount =
        deposit['amount_farm'] ?? metadata['amount_farm'] ?? deposit['amount'];
    final reference =
        deposit['reference'] ??
        deposit['transaction_reference'] ??
        metadata['reference'];
    final method = _depositMethodLabel(deposit, metadata);
    final provider =
        deposit['payment_provider'] ??
        deposit['provider'] ??
        metadata['provider'];

    receipt['amount'] = farmAmount;
    receipt['transaction_type'] = 'Deposit';
    receipt['description'] = 'FARM deposit via $method';
    receipt['currency'] = 'FARM';
    receipt['payment_method'] = method;
    if (provider != null) receipt['payment_provider'] = provider;
    if (reference != null) receipt['transaction_reference'] = reference;
    if (deposit['amount_fiat'] != null || metadata['amount_fiat'] != null) {
      receipt['fiat_amount'] =
          metadata['amount_fiat'] ?? deposit['amount_fiat'];
      receipt['fiat_currency'] =
          metadata['currency_fiat'] ?? deposit['currency'] ?? selectedCurrency;
    }
    return receipt;
  }

  List<Map<String, dynamic>> get _selectedDepositReceipts => _selectedDeposits
      .where((index) => index >= 0 && index < recentDeposits.length)
      .map((index) {
        final deposit = Map<String, dynamic>.from(recentDeposits[index] as Map);
        final metadata = deposit['metadata'] is Map
            ? Map<String, dynamic>.from(deposit['metadata'] as Map)
            : <String, dynamic>{};
        return _depositReceipt(deposit, metadata);
      })
      .toList();

  Future<void> _downloadSelectedDeposits() async {
    try {
      await TransactionReceiptService.downloadReceipts(
        _selectedDepositReceipts,
      );
      if (!mounted) return;
      setState(() => _selectedDeposits.clear());
      _snack('Selected receipts saved to gallery');
    } catch (error) {
      if (mounted) _snack('Could not save receipts: $error');
    }
  }

  Future<void> _shareSelectedDeposits() async {
    try {
      await TransactionReceiptService.shareReceipts(_selectedDepositReceipts);
      if (!mounted) return;
      setState(() => _selectedDeposits.clear());
    } catch (error) {
      if (mounted) _snack('Could not share receipts: $error');
    }
  }

  // ── Create a Paystack deposit or an in-app NOWPayments crypto deposit ─────
  Future<void> _createDeposit() async {
    if (isLoading) return;

    if (selectedMethod == 'CRYPTO' &&
        (_selectedCryptoToken == null ||
            !_cryptoTokens.contains(_selectedCryptoToken))) {
      _snack('Choose a cryptocurrency before continuing');
      return;
    }
    if (selectedMethod == 'CRYPTO' &&
        (_loadingCryptoMinimum || _cryptoMinimumUsd == null)) {
      _snack(
        _cryptoMinimumError ??
            'Wait for the selected cryptocurrency minimum to load',
      );
      return;
    }

    if (!_hasValidDepositAmount) {
      _snack(_depositValidationMessage);
      return;
    }

    setState(() => isLoading = true);

    try {
      if (selectedMethod == 'CRYPTO') {
        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CryptoCheckoutPage(
              amountUsd: amount,
              tokens: _cryptoTokens,
              initialToken: _selectedCryptoToken,
            ),
          ),
        );
        if (!mounted) return;
        await _fetchHistory();
        await _fetchWallet();
        if (completed == true) {
          amountController.clear();
          _snack('Payment successful. Your wallet is credited.');
        } else if (completed == false) {
          _snack('Payment expired or failed. No funds were credited.');
        }
        return;
      }

      final paymentMethodRaw = switch (selectedMethod) {
        'CARD' => 'card',
        'BANK_TRANSFER' => 'bank_transfer',
        'MOBILE_MONEY' => 'mobile_money',
        _ => 'card',
      };
      final depositUserDetails = selectedMethod == 'CRYPTO'
          ? null
          : await _fetchPaystackDepositUserDetails(
              requirePhone: selectedMethod == 'MOBILE_MONEY',
            );

      final body = {
        'amount_fiat': amount,
        'currency': selectedCurrency,
        'paymentMethod': selectedMethod,
        'payment_method': paymentMethodRaw,
        'method': paymentMethodRaw,
        'payment_channel': paymentMethodRaw,
        if (depositUserDetails != null) ...{
          'email': depositUserDetails['email'],
          'phone': depositUserDetails['phone'],
        },
        'payment_provider': 'paystack',
        'provider': 'paystack',
      };

      const path = '/deposit/create';

      if (!mounted) return;

      final data = await ApiService.request(
        method: 'POST',
        path: path,
        body: body,
        requiresAuth: true,
      );

      if (!mounted) return;

      // ApiService.request returns a non-null map on success; handle unexpected types elsewhere.

      final paymentUrl =
          (data['authorization_url'] ??
                  data['payment_url'] ??
                  data['data']?['authorization_url'] ??
                  data['data']?['payment_url'])
              ?.toString();
      final paystackAccessCode =
          (data['access_code'] ?? data['data']?['access_code'])?.toString();
      final depositRef =
          data['data']?['reference'] ??
          data['data']?['transaction_reference'] ??
          data['reference'] ??
          data['transaction_reference'];

      if (paymentUrl != null) {
        final reference = depositRef?.toString();
        if (reference == null || reference.isEmpty) {
          throw const FormatException(
            'The payment server did not return a transaction reference.',
          );
        }

        final checkoutResult = await PaystackInlineCheckout.show(
          context,
          accessCode: paystackAccessCode,
          paymentUrl: paymentUrl,
        );
        if (!mounted) return;

        try {
          final verification = await ApiService.request(
            method: 'POST',
            path: '/deposit/verify/${Uri.encodeComponent(reference)}',
            body: const {},
            requiresAuth: true,
          );
          final result = verification['data'];
          final status = result is Map
              ? result['status']?.toString().toUpperCase()
              : null;
          final credited = result is Map && result['credited'] == true;
          if (status == 'SUCCESS' || credited) {
            await _fetchHistory();
            await _fetchWallet();
            if (mounted) _snack('Payment successful. Your wallet is credited.');
            amountController.clear();
            return;
          }
          _snack(
            checkoutResult == true
                ? 'Payment received. Waiting for Paystack confirmation...'
                : 'Payment is not confirmed yet. Your wallet will update after confirmation.',
          );
        } catch (error) {
          _snack(
            'Checkout closed, but payment verification is pending: $error',
          );
        }

        // Poll with timeout and handle all statuses: completed, failed, cancelled
        int pollAttempts = 0;
        const maxAttempts = 60; // ~10 minutes (60 * 10 seconds)

        Timer.periodic(const Duration(seconds: 10), (timer) async {
          if (!mounted) {
            timer.cancel();
            return;
          }

          pollAttempts++;

          // Timeout after 10 minutes
          if (pollAttempts > maxAttempts) {
            timer.cancel();
            if (mounted) {
              _snack(
                'Payment verification timed out. '
                'Please check your transaction status on the dashboard.',
              );
            }
            return;
          }

          await _fetchHistory();
          await _fetchWallet();

          // Find the specific deposit by reference if available
          Map<String, dynamic>? targetDeposit;
          if (depositRef != null) {
            targetDeposit = recentDeposits.firstWhere(
              (d) =>
                  d['reference'] == depositRef ||
                  d['transaction_reference'] == depositRef,
              orElse: () => {},
            );
            if ((targetDeposit?.isEmpty ?? false)) targetDeposit = null;
          }

          // Fallback to latest if no specific reference found
          final deposit =
              targetDeposit ??
              (recentDeposits.isNotEmpty ? recentDeposits.first : null);

          if (deposit != null) {
            final status = (deposit['status'] ?? '').toString().toLowerCase();

            // Accept backend `SUCCESS`/`success` as completed as well as legacy `completed`
            if (status == 'completed' || status == 'success') {
              timer.cancel();
              if (mounted && FFAppState().accessToken.isNotEmpty) {
                // Try to surface merchant fee information when available.
                final metadata = deposit['metadata'] is Map
                    ? Map<String, dynamic>.from(deposit['metadata'] as Map)
                    : <String, dynamic>{};

                double? amount;
                if (deposit['amount_farm'] != null) {
                  amount = (deposit['amount_farm'] as num).toDouble();
                } else if (deposit['amount'] != null) {
                  amount = (deposit['amount'] as num).toDouble();
                }

                double? fee;
                // Prefer explicit platform_fee in metadata if provided
                if (metadata.containsKey('platform_fee')) {
                  final v = metadata['platform_fee'];
                  if (v is num) fee = v.toDouble();
                  if (v is String) fee = double.tryParse(v);
                }

                // Fall back to percent if provided
                if (fee == null &&
                    metadata.containsKey('platform_fee_percent') &&
                    amount != null) {
                  final p = metadata['platform_fee_percent'];
                  double? pp;
                  if (p is num) pp = p.toDouble();
                  if (p is String) pp = double.tryParse(p);
                  if (pp != null) fee = (amount * (pp / 100.0));
                }

                // The fee shown is only what the backend recorded (no client-side guess).

                final grossAmount = amount;
                final platformFee = fee;
                if (platformFee != null && grossAmount != null) {
                  final net = grossAmount - platformFee;
                  // Show a dialog summarizing the merchant fee and net amount before redirect
                  showDialog<void>(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => AlertDialog(
                      title: const Text('Payment confirmed'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gross amount: ${grossAmount.toStringAsFixed(2)} FARM',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Platform fee: ${platformFee.toStringAsFixed(2)} FARM',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Net credited to merchant: ${net.toStringAsFixed(2)} FARM',
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // Short delay to allow dialog to close smoothly, then navigate
                            Future.delayed(
                              const Duration(milliseconds: 300),
                              () {
                                if (mounted) context.go('/dashboard');
                              },
                            );
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  _snack('Payment confirmed! Redirecting to dashboard...');
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted) context.go('/dashboard');
                  });
                }
              }
            } else if (status == 'failed' ||
                status == 'cancelled' ||
                status == 'error') {
              timer.cancel();
              if (mounted) {
                _snack(
                  'Payment ${status == 'cancelled' ? 'cancelled' : 'failed'}. '
                  'No funds were deducted. Please try again.',
                );

                // Refresh history and wallet to reflect backend state. Do not call a
                // non-existent DELETE endpoint; backend controls lifecycle.
                await _fetchHistory();
                await _fetchWallet();
              }
            }
          }
        });
      } else {
        _snack(
          data['message'] ??
              data['error']?.toString() ??
              'Deposit failed. Please try again.',
        );
      }

      amountController.clear();
    } catch (e) {
      if (mounted) _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _depositMethodLabel(
    Map<String, dynamic> deposit,
    Map<String, dynamic> metadata,
  ) {
    final rawMethod =
        metadata['method'] ??
        deposit['paymentMethod'] ??
        deposit['payment_method'] ??
        metadata['payment_method'] ??
        deposit['payment_channel'] ??
        deposit['payment_provider'] ??
        metadata['provider'] ??
        deposit['provider'];
    final method = rawMethod?.toString().toLowerCase() ?? '';

    if (method.contains('crypto') || method.contains('ivory')) {
      return 'CRYPTO';
    }
    if (method.contains('mobile')) return 'MOBILE MONEY';
    if (method.contains('bank') && method.contains('transfer')) {
      return 'BANK TRANSFER';
    }
    if (method.contains('card') || method.contains('paystack')) {
      return 'BANK CARD';
    }
    return method.isEmpty ? 'METHOD UNAVAILABLE' : method.toUpperCase();
  }

  String _depositDateLabel(Map<String, dynamic> deposit) {
    final rawDate =
        deposit['created_at'] ??
        deposit['createdAt'] ??
        deposit['deposited_at'] ??
        deposit['timestamp'] ??
        deposit['date'];
    final parsedDate = DateTime.tryParse(rawDate?.toString() ?? '');
    if (parsedDate == null) return 'Date unavailable';
    return DateFormat('dd MMM yyyy, h:mm a').format(parsedDate.toLocal());
  }

  String _depositAmountLabel(
    Map<String, dynamic> deposit,
    Map<String, dynamic> metadata,
  ) {
    final method = _depositMethodLabel(deposit, metadata);
    final farmAmount = deposit['amount_farm'] ?? metadata['amount_farm'];
    final usdAmount = deposit['amount_usd'] ?? metadata['amount_usd'];
    final usdToFarmRate =
        deposit['usd_to_farm_rate'] ?? metadata['usd_to_farm_rate'];

    if (method == 'CRYPTO' && farmAmount != null && usdAmount != null) {
      final rateText = usdToFarmRate == null
          ? ''
          : ' (1 USD = ${_formatDepositNumber(usdToFarmRate)} FARM)';
      return 'USD ${_formatDepositNumber(usdAmount)} = '
          '${_formatDepositNumber(farmAmount)} FARM$rateText';
    }

    final currency = metadata['currency_fiat'] ?? deposit['currency'] ?? 'KES';
    final fiatAmount = metadata['amount_fiat'] ?? deposit['amount'];
    return '$currency ${_formatDepositNumber(fiatAmount)} ≈ '
        '${_formatDepositNumber(farmAmount ?? deposit['amount'])} FARM';
  }

  String _formatDepositNumber(Object? value) {
    final number = double.tryParse(value?.toString() ?? '');
    if (number == null) return value?.toString() ?? '0';
    return number.toStringAsFixed(number == number.roundToDouble() ? 0 : 2);
  }

  // ── Payment method card ──────────────────────────────────────────────────
  Widget _methodCard(
    BuildContext context, {
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
    bool enabled = true,
    String? unavailableMessage,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = selectedMethod == method;
    final cardBackground = selected
        ? (isDark ? const Color(0xFF1F1F1F) : Colors.black)
        : theme.secondaryBackground;
    final cardBorder = selected
        ? (isDark ? const Color(0xFF2A2A2A) : Colors.black)
        : theme.secondaryText.withAlpha(90);
    final textColor = !enabled
        ? theme.secondaryText
        : selected
        ? Colors.white
        : theme.primaryText;
    final subtitleColor = !enabled
        ? theme.secondaryText
        : selected
        ? Colors.white70
        : theme.secondaryText;

    return GestureDetector(
      onTap: () {
        if (!enabled) {
          _snack(unavailableMessage ?? '$title is currently unavailable.');
          return;
        }
        setState(() => selectedMethod = method);
        if (method == 'CRYPTO') unawaited(_fetchCryptoTokens());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isKycApproved) {
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: KycRequiredWidget(
            feature: 'deposit',
            onKycApproved: () => setState(() {}),
          ),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FlutterFlowIconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => context.goNamed('Dashboard'),
                  ),
                  Text(
                    'Deposit Funds',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                  ),
                  Icon(Icons.help_outline, color: theme.secondaryText),
                ],
              ),

              const SizedBox(height: 28),

              // Wallet balance card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111111) : Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: loadingWallet
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wallet Balance',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(mainAxisSize: MainAxisSize.min, children: [const FarmCoinIcon(size: 28), const SizedBox(width: 10), Flexible(child: Text(
                            '${walletBalance.toStringAsFixed(4)} FARM',
                            style: GoogleFonts.plusJakartaSans(
                              color: AppTheme.accent,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ))]),
                        ],
                      ),
              ),

              const SizedBox(height: 28),

              // Amount input
              Center(
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                  decoration: InputDecoration(
                    prefixText: '$_amountCurrency  ',
                    border: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 36,
                      color: theme.secondaryText,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 8),
              Text(
                _depositValidationMessage,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: amount > 0 && !_hasValidDepositAmount
                      ? Colors.redAccent
                      : theme.secondaryText,
                ),
              ),

              const SizedBox(height: 24),

              // Payment method
              Text(
                'Payment Method',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 12),

              _methodCard(
                context,
                method: 'CARD',
                icon: Icons.credit_card,
                title: 'Bank Card',
                subtitle: 'Instant',
              ),
              _methodCard(
                context,
                method: 'BANK_TRANSFER',
                icon: Icons.account_balance,
                title: 'Bank Transfer',
                subtitle: 'Pesalink',
              ),
              _methodCard(
                context,
                method: 'MOBILE_MONEY',
                icon: Icons.phone_android,
                title: 'Mobile Money (M-Pesa)',
                subtitle: 'Instant',
              ),
              _methodCard(
                context,
                method: 'CRYPTO',
                icon: Icons.currency_bitcoin,
                title: 'Crypto',
                subtitle: 'Pay in-app with NOWPayments',
              ),

              if (selectedMethod == 'CRYPTO') ...[
                const SizedBox(height: 4),
                Text(
                  'Cryptocurrency',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingCryptoTokens)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_cryptoTokensError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _cryptoTokensError!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _fetchCryptoTokens,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else
                  SearchableCryptoPicker(
                    currencies: _cryptoTokens,
                    selectedCurrency: _selectedCryptoToken,
                    onSelected: (token) {
                      setState(() {
                        _selectedCryptoToken = token;
                        _cryptoMinimumAmount = null;
                        _cryptoMinimumUsd = null;
                        _cryptoMinimumError = null;
                      });
                      _fetchCryptoMinimum(token);
                    },
                  ),
                if (_loadingCryptoMinimum)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Loading ${_selectedCryptoToken?.toUpperCase() ?? ''} minimum...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                  )
                else if (_cryptoMinimumError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Could not load the minimum payment for ${_selectedCryptoToken?.toUpperCase() ?? 'this currency'}.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  )
                else if (_cryptoMinimumAmount != null &&
                    _cryptoMinimumUsd != null &&
                    _selectedCryptoToken != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NOWPayments minimum: ${_formatMinimumCrypto(_cryptoMinimumAmount!)} ${_selectedCryptoToken!.toUpperCase()}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter at least USD ${_cryptoMinimumUsdToEnter.toStringAsFixed(2)} to meet this coin minimum.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              amountController.text = _cryptoMinimumUsdToEnter
                                  .toStringAsFixed(2);
                              setState(() {});
                            },
                            child: const Text('Use minimum amount'),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // Fee breakdown
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.secondaryText.withAlpha(80)),
                ),
                child: Column(
                  children: [
                    _feeRow(
                      'Amount',
                      '$_amountCurrency ${amount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 10),
                    _feeRow(
                      'Fee (${(feeRate * 100).toStringAsFixed(1)}%)',
                      '$_amountCurrency ${fee.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 20),
                    _feeRow(
                      'Total',
                      '$_amountCurrency ${total.toStringAsFixed(2)}',
                      bold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Deposit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: (isLoading || !_hasValidDepositAmount)
                      ? null
                      : _createDeposit,
                  child: isLoading
                      ? const CircularProgressIndicator(color: AppTheme.onAccent)
                      : Text(
                          'Deposit Funds',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.onAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Recent deposits
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Deposits',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedDeposits.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Share selected receipts',
                          icon: const Icon(Icons.share_rounded),
                          onPressed: _shareSelectedDeposits,
                        ),
                        IconButton(
                          tooltip: 'Download selected receipts',
                          icon: const Icon(Icons.download_rounded),
                          onPressed: _downloadSelectedDeposits,
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (recentDeposits.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No deposits yet',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                )
              else
                ...recentDeposits.asMap().entries.map((entry) {
                  final index = entry.key;
                  final d = entry.value;
                  final deposit = Map<String, dynamic>.from(d as Map);
                  final status = (d['status'] ?? 'pending') as String;
                  final isComplete = status == 'completed';
                  final meta = deposit['metadata'] is Map
                      ? Map<String, dynamic>.from(deposit['metadata'] as Map)
                      : <String, dynamic>{};
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (_selectedDeposits.isNotEmpty) {
                        setState(() {
                          if (!_selectedDeposits.add(index)) {
                            _selectedDeposits.remove(index);
                          }
                        });
                        return;
                      }
                      TransactionReceiptService.showDetails(
                        context,
                        _depositReceipt(deposit, meta),
                        fetchLatest: true,
                      );
                    },
                    onLongPress: () {
                      if (!_selectedDeposits.contains(index)) {
                        setState(() => _selectedDeposits.add(index));
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        border: Border.all(
                          color: theme.secondaryText.withAlpha(70),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (_selectedDeposits.isNotEmpty)
                            Checkbox(
                              value: _selectedDeposits.contains(index),
                              onChanged: (selected) => setState(() {
                                if (selected == true) {
                                  _selectedDeposits.add(index);
                                } else {
                                  _selectedDeposits.remove(index);
                                }
                              }),
                            ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isComplete
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isComplete
                                  ? Icons.check_circle_outline
                                  : Icons.hourglass_top,
                              color: isComplete ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _depositDateLabel(deposit),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: theme.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _depositAmountLabel(deposit, meta),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryText,
                                  ),
                                ),
                                Text(
                                  '≈ ${d['amount']} FARM • $status',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _depositMethodLabel(deposit, meta),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Secured by FARM 🔒',
                  style: TextStyle(color: theme.secondaryText, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool bold = false}) {
    final style = GoogleFonts.plusJakartaSans(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
