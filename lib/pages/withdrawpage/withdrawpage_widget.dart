import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '/backend/services/api_service.dart';
import '/core/app_config.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/widgets/common/back_chevron.dart';
import '/components/kyc_required_widget.dart';
import '/services/app_session_manager.dart';
import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';
import '/services/transaction_receipt_service.dart';
import '/utils/transaction_history_utils.dart';
import '/widgets/searchable_crypto_picker.dart';

class WithdrawpageWidget extends StatefulWidget {
  const WithdrawpageWidget({super.key});

  static String routeName = 'withdrawpage';
  static String routePath = '/withdrawpage';

  @override
  State<WithdrawpageWidget> createState() => _WithdrawpageWidgetState();
}

class _WithdrawpageWidgetState extends State<WithdrawpageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _amountCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _walletCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _pinEntryEnabled = false;
  bool _isBiometricChecking = false;
  TransactionAuthenticationResult? _lastPinAuthResult;
  String? _withdrawalIdempotencyKey;

  String selectedMethod = 'BANK';
  String selectedCurrency = 'KES';
  String selectedCryptoAsset = 'USDC';
  String? selectedCryptoNetwork;
  bool isLoading = false;
  bool loadingWallet = true;
  bool loadingHistory = true;

  String? _selectedBank;
  String? _selectedBankCode;
  String? _selectedMobileMoneyProvider = 'MPESA';
  List<Map<String, String>> _paystackBanks = [];
  bool _loadingPaystackDestinations = false;
  String? _paystackDestinationError;

  double walletBalance = 0;
  List<dynamic> history = [];
  final Set<int> _selectedWithdrawals = <int>{};
  Timer? _historyTimer;
  final Map<String, List<Map<String, String>>> _cryptoNetworkOptions = {};
  final Set<String> _loadingCryptoNetworks = {};
  final Map<String, String> _cryptoNetworkErrors = {};
  double? _cryptoFarmUsdRate;
  double? _cryptoMinimumFarm;
  bool _loadingCryptoMinimum = false;
  String? _cryptoMinimumError;

  // Fee rates per method
  final Map<String, double> _fees = {
    'BANK': 0.015,
    'MOBILE_MONEY': 0.015,
    'CRYPTO': 0.015,
  };

  final Map<String, Map<String, double?>> _withdrawLimits = {
    'BANK': {'min': 4999, 'max': 999999},
    'MOBILE_MONEY': {'min': 1499, 'max': 249999},
    'CRYPTO': {'min': 1, 'max': null},
  };

  double get amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;
  double get feeRate => _fees[selectedMethod] ?? 0.015;
  double get _amountInFarm => selectedMethod == 'CRYPTO'
      ? (_cryptoFarmUsdRate == null ? 0 : amount / _cryptoFarmUsdRate!)
      : amount;
  double get fee => _amountInFarm * feeRate;
  double get settlement => _amountInFarm - fee;

  Map<String, double?> get _activeWithdrawLimits =>
      _withdrawLimits[selectedMethod] ?? _withdrawLimits['BANK']!;
  double get _activeWithdrawMin => _activeWithdrawLimits['min'] ?? 10;
  double? get _activeWithdrawMax => _activeWithdrawLimits['max'];
  bool get _hasValidWithdrawAmount {
    if (selectedMethod == 'CRYPTO') {
      return _cryptoFarmUsdRate != null &&
          _cryptoMinimumFarm != null &&
          amount >= 1 &&
          _amountInFarm <= walletBalance;
    }
    return amount > 0 &&
        amount >= _activeWithdrawMin &&
        (_activeWithdrawMax == null || amount <= _activeWithdrawMax!);
  }

  String _formatAmount(double value) {
    final formatter = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    return value
        .toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
        .replaceAllMapped(formatter, (match) => '${match[1]},');
  }

  String get _withdrawValidationMessage {
    if (selectedMethod == 'CRYPTO') {
      if (_loadingCryptoMinimum) return 'Loading crypto withdrawal minimum...';
      if (_cryptoMinimumError != null) {
        return 'Could not load crypto minimum: $_cryptoMinimumError';
      }
      final maxUsd = (_cryptoFarmUsdRate ?? 0) * walletBalance;
      if (amount <= 0) {
        return 'Range: USD 1.00+${maxUsd > 0 ? ' - USD ${maxUsd.toStringAsFixed(2)} max' : ''}';
      }
      if (amount < 1) {
        return 'Minimum crypto withdrawal is USD 1.00';
      }
      if (_cryptoFarmUsdRate != null && _amountInFarm > walletBalance) {
        return 'Amount exceeds your available balance (USD ${maxUsd.toStringAsFixed(2)} max)';
      }
      return 'Range: USD 1.00+${maxUsd > 0 ? ' - USD ${maxUsd.toStringAsFixed(2)} max' : ''}';
    }
    if (amount <= 0) {
      return 'Range: FARM ${_formatAmount(_activeWithdrawMin)}${_activeWithdrawMax == null ? '+' : ' - FARM ${_formatAmount(_activeWithdrawMax!)}'}';
    }
    if (_hasValidWithdrawAmount) {
      return 'Range: FARM ${_formatAmount(_activeWithdrawMin)}${_activeWithdrawMax == null ? '+' : ' - FARM ${_formatAmount(_activeWithdrawMax!)}'}';
    }
    final maxText = _activeWithdrawMax == null
        ? ' and above'
        : ' and FARM ${_formatAmount(_activeWithdrawMax!)}';
    return 'Amount must be between FARM ${_formatAmount(_activeWithdrawMin)}$maxText';
  }

  @override
  void initState() {
    super.initState();
    _fetchWallet();
    _fetchHistory();
    _fetchPaystackDestinations();
    _startHistoryPolling();
    _fetchCryptoWithdrawalMinimum();
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    _walletCtrl.dispose();
    _mobileCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  Future<void> _promptBiometricForPinField() async {
    if (_lastPinAuthResult?.biometricUsed == true) {
      return;
    }

    if (!_hasValidWithdrawAmount) {
      _snack(_withdrawValidationMessage);
      return;
    }

    try {
      setState(() => _isBiometricChecking = true);
      final authResult = await TransactionAuthorizationService()
          .authorizeTransaction(localizedReason: 'Confirm withdrawal')
          .then((r) => r.toTransactionAuthenticationResult());

      if (authResult.biometricUsed) {
        if (!mounted) return;
        await _createWithdraw(skipConfirm: true, preAuthResult: authResult);
        return;
      }

      if (!mounted) return;
      setState(() {
        _lastPinAuthResult = authResult;
        _pinEntryEnabled = true;
      });
      _pinFocusNode.requestFocus();
    } finally {
      if (!mounted) return;
      setState(() => _isBiometricChecking = false);
    }
  }

  bool get isKycApproved {
    final status = FFAppState().kycStatus.trim().toLowerCase();
    return ['verified', 'approved', 'complete', 'success'].contains(status);
  }

  Future<void> _fetchPaystackDestinations() async {
    if (mounted) {
      setState(() {
        _loadingPaystackDestinations = true;
        _paystackDestinationError = null;
      });
    }

    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/withdraw/paystack/destinations?type=kepss',
      );
      dynamic raw = response['data'];
      while (raw is Map && raw.containsKey('data')) {
        raw = raw['data'];
      }

      if (raw is! List) {
        throw const FormatException(
          'The server returned an invalid bank destination list.',
        );
      }
      final banks = raw
          .whereType<Map>()
          .map(
            (item) => {
              'name': item['name']?.toString() ?? '',
              'code': (item['bank_code'] ?? item['code'])?.toString() ?? '',
            },
          )
          .where((item) => item['name']!.isNotEmpty && item['code']!.isNotEmpty)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _paystackBanks = banks
            ..sort((left, right) => left['name']!.compareTo(right['name']!));
          if (_paystackBanks.isEmpty) {
            _paystackDestinationError =
                'Paystack returned no Kenyan bank destinations.';
          }
          if (_selectedBank != null &&
              !_paystackBanks.any((bank) => bank['name'] == _selectedBank)) {
            _selectedBank = null;
            _selectedBankCode = null;
          }
          _selectedMobileMoneyProvider = 'MPESA';
        });
      }
    } catch (error) {
      debugPrint('Could not load Paystack payout destinations: $error');
      if (mounted) {
        setState(() {
          _paystackBanks = [];
          _selectedBank = null;
          _selectedBankCode = null;
          _paystackDestinationError =
              'Could not load Paystack bank destinations: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPaystackDestinations = false);
      }
    }
  }

  List<String> get _availableCryptoAssets =>
      _cryptoNetworkOptions.keys.toList()..sort();

  Future<void> _fetchCryptoNetworks() async {
    const lookupKey = 'all';
    if (_loadingCryptoNetworks.contains(lookupKey)) return;
    setState(() {
      _loadingCryptoNetworks.add(lookupKey);
      _cryptoNetworkErrors.remove(lookupKey);
    });
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/withdraw/crypto/currencies',
      );
      final raw = response['data'];
      if (raw is! List) {
        throw const FormatException(
          'The server returned an invalid NOWPayments currency list.',
        );
      }
      final options = raw
          .whereType<String>()
          .map((currency) => currency.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (options.isEmpty) {
        throw Exception('No crypto currencies are enabled for this account.');
      }
      final groupedOptions = <String, List<Map<String, String>>>{};
      for (final currency in options) {
        groupedOptions[currency] = [
          {'token': currency, 'network': currency, 'networkName': currency},
        ];
      }
      if (!mounted) return;
      setState(() {
        _cryptoNetworkOptions
          ..clear()
          ..addAll(groupedOptions);
        if (!_availableCryptoAssets.contains(selectedCryptoAsset)) {
          selectedCryptoAsset = _availableCryptoAssets.first;
        }
        final defaultNetwork =
            (_cryptoNetworkOptions[selectedCryptoAsset] ?? [])
                .firstOrNull?['network'] ??
            selectedCryptoAsset;
        if (!(_cryptoNetworkOptions[selectedCryptoAsset] ?? []).any(
          (option) => option['network'] == selectedCryptoNetwork,
        )) {
          selectedCryptoNetwork = defaultNetwork;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cryptoNetworkOptions.clear();
        _cryptoNetworkErrors[lookupKey] = error.toString();
        selectedCryptoNetwork = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingCryptoNetworks.remove(lookupKey));
      }
    }
  }

  Future<void> _fetchCryptoWithdrawalMinimum() async {
    setState(() {
      _loadingCryptoMinimum = true;
      _cryptoMinimumError = null;
    });
    try {
      final response = await ApiService.request(
        method: 'GET',
        path: '/withdraw/crypto/minimum',
        requiresAuth: true,
      );
      final data = response['data'];
      final farmUsdRate = data is Map
          ? double.tryParse(data['farmUsdRate']?.toString() ?? '')
          : null;
      final minimumFarm = data is Map
          ? double.tryParse(data['minimumFarm']?.toString() ?? '')
          : null;
      if (farmUsdRate == null ||
          !farmUsdRate.isFinite ||
          farmUsdRate <= 0 ||
          minimumFarm == null ||
          !minimumFarm.isFinite ||
          minimumFarm <= 0) {
        throw const FormatException(
          'NOWPayments minimum conversion data is invalid.',
        );
      }
      if (!mounted) return;
      setState(() {
        _cryptoFarmUsdRate = farmUsdRate;
        _cryptoMinimumFarm = minimumFarm;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _cryptoMinimumError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingCryptoMinimum = false);
    }
  }

  void _startHistoryPolling() {
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _fetchWallet();
      _fetchHistory();
    });
  }

  // ── Fetch wallet ─────────────────────────────────────────────────────────
  Future<void> _fetchWallet() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.api}/wallet'),
        headers: {'Authorization': 'Bearer ${FFAppState().accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // Support different backend shapes: { data: { available_balance } } or { balance }
        double bal = 0;
        if (body is Map<String, dynamic>) {
          bal =
              (body['data']?['available_balance'] ??
                      body['data']?['balance'] ??
                      body['available_balance'] ??
                      body['balance'] ??
                      0)
                  .toDouble();
        } else {
          bal = 0;
        }
        setState(() => walletBalance = bal);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingWallet = false);
    }
  }

  // ── Fetch withdrawal history ─────────────────────────────────────────────
  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(
        // Backend withdraw history endpoint
        Uri.parse('${AppConfig.api}/withdraw/history'),
        headers: {'Authorization': 'Bearer ${FFAppState().accessToken}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body is List) {
          setState(
            () =>
                history = body.where(isVisibleTransactionHistoryItem).toList(),
          );
        } else if (body is Map<String, dynamic>) {
          final items = body['data'] ?? body['withdrawals'] ?? [];
          setState(
            () => history = items is List
                ? items.where(isVisibleTransactionHistoryItem).toList()
                : [],
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loadingHistory = false);
    }
  }

  Future<void> _downloadSelectedWithdrawals() async {
    final selected = _selectedWithdrawals
        .where((index) => index >= 0 && index < history.length)
        .map((index) => Map<String, dynamic>.from(history[index] as Map))
        .toList();
    try {
      await TransactionReceiptService.downloadReceipts(selected);
      if (mounted) {
        setState(() => _selectedWithdrawals.clear());
        _snack('Selected receipts saved to gallery');
      }
    } catch (error) {
      if (mounted) _snack('Could not save receipts: $error');
    }
  }

  String _ensureWithdrawalIdempotencyKey() {
    return _withdrawalIdempotencyKey ??= List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _showWithdrawalReceipt(Map<String, dynamic> response) async {
    final withdrawal = response['withdrawal'] is Map
        ? Map<String, dynamic>.from(response['withdrawal'] as Map)
        : <String, dynamic>{};
    final reference = (response['reference'] ?? withdrawal['reference'] ?? '')
        .toString();
    final status = (withdrawal['status'] ?? response['status'] ?? 'PENDING')
        .toString()
        .toUpperCase();
    final destination = selectedMethod == 'MOBILE_MONEY'
        ? _mobileCtrl.text.trim()
        : selectedMethod == 'CRYPTO'
        ? _walletCtrl.text.trim()
        : _selectedBank ?? 'Withdrawal destination';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdrawal submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $status'),
            const SizedBox(height: 6),
            Text('Reference: $reference'),
            const SizedBox(height: 6),
            Text('Destination: $destination'),
            const SizedBox(height: 6),
            Text(
              'Total deduction: ${selectedMethod == 'CRYPTO' ? 'USD ${amount.toStringAsFixed(2)} (${_amountInFarm.toStringAsFixed(4)} FARM)' : '${amount.toStringAsFixed(4)} FARM'}',
            ),
            Text('Transaction fee (1.5%): ${fee.toStringAsFixed(4)} FARM'),
            Text('Net amount: ${settlement.toStringAsFixed(4)} FARM'),
            const SizedBox(height: 8),
            Text(
              selectedMethod == 'CRYPTO'
                  ? 'Crypto withdrawals remain reserved until an administrator approves the payout and NOWPayments confirms it.'
                  : 'Your withdrawal is pending Paystack confirmation. Wallet funds are updated only after verification finishes.',
            ),
            if (response['estimated_crypto_amount'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated payout: ${response['estimated_crypto_amount']} ${response['currency'] ?? selectedCryptoAsset}',
              ),
            ],
            if (response['estimated_network_fee'] != null) ...[
              Text(
                'Estimated network fee: ${response['estimated_network_fee']} ${response['currency'] ?? selectedCryptoAsset}',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Validate destination fields ──────────────────────────────────────────
  bool get _destinationValid {
    switch (selectedMethod) {
      case 'BANK':
        return _selectedBank != null &&
            _selectedBankCode != null &&
            _accountCtrl.text.trim().isNotEmpty;
      case 'MOBILE_MONEY':
        return _selectedMobileMoneyProvider != null &&
            _mobileCtrl.text.trim().isNotEmpty;
      case 'CRYPTO':
        return _availableCryptoAssets.contains(selectedCryptoAsset) &&
            _walletCtrl.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  // ── Submit withdrawal ─────────────────────────────────────────────────────
  Future<void> _createWithdraw({
    bool skipConfirm = false,
    TransactionAuthenticationResult? preAuthResult,
  }) async {
    if (isLoading) return;

    if (!_hasValidWithdrawAmount) {
      _snack(_withdrawValidationMessage);
      return;
    }
    if (_amountInFarm > walletBalance) {
      _snack('Insufficient FARM balance');
      return;
    }
    if (!_destinationValid) {
      _snack('Please fill in your withdrawal destination');
      return;
    }

    if (!skipConfirm) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm Withdrawal'),
          content: Text(
            'Withdraw ${selectedMethod == 'CRYPTO' ? 'USD ${amount.toStringAsFixed(2)} (${_amountInFarm.toStringAsFixed(4)} FARM)' : '${amount.toStringAsFixed(4)} FARM'} via ${selectedMethod.replaceAll('_', ' ')}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => isLoading = true);

    try {
      print('[WITHDRAW] Submitting withdrawal request...');

      final authResult =
          preAuthResult ??
          _lastPinAuthResult ??
          await TransactionAuthorizationService()
              .authorizeTransaction(localizedReason: 'Confirm withdrawal')
              .then((r) => r.toTransactionAuthenticationResult());

      final idempotencyKey = _ensureWithdrawalIdempotencyKey();
      final usedBiometric = authResult?.biometricUsed == true;
      if (usedBiometric) {
        final requestBody = {
          'amount': _amountInFarm,
          'method': _methodToBackend(selectedMethod),
          'pin': null,
          'biometric_auth': true,
          'device_fingerprint': authResult?.deviceFingerprint,
        };

        switch (selectedMethod) {
          case 'BANK':
            requestBody['accountNumber'] = _accountCtrl.text.trim();
            requestBody['bankName'] = _selectedBank ?? '';
            break;
          case 'MOBILE_MONEY':
            requestBody['phoneNumber'] = _mobileCtrl.text.trim();
            requestBody['mobileMoneyProvider'] =
                _selectedMobileMoneyProvider ?? '';
            break;
          case 'CRYPTO':
            requestBody['cryptoAsset'] = selectedCryptoAsset;
            requestBody['cryptoAddress'] = _walletCtrl.text.trim();
            requestBody['network'] = selectedCryptoNetwork ?? '';
            break;
        }

        final endpoint = selectedMethod == 'CRYPTO'
            ? '/withdraw/crypto'
            : '/withdraw/create';
        final res = await http.post(
          Uri.parse('${AppConfig.api}$endpoint'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${FFAppState().accessToken}',
            'Idempotency-Key': idempotencyKey,
          },
          body: jsonEncode(requestBody),
        );

        if (mounted) {
          final decoded = jsonDecode(res.body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            _applyWithdrawalReservation();
            await AppSessionManager().syncNow(
              profileTimeoutSeconds: 5,
              walletTimeoutSeconds: 5,
              transactionsTimeoutSeconds: 5,
            );
            if (decoded is Map<String, dynamic>) {
              await _showWithdrawalReceipt(decoded);
            } else if (decoded is Map) {
              await _showWithdrawalReceipt(Map<String, dynamic>.from(decoded));
            }
            _snack('Withdrawal request submitted successfully');
          } else {
            _snack(
              decoded is Map && decoded['message'] != null
                  ? decoded['message'].toString()
                  : 'Withdrawal failed',
            );
          }
        }
        return;
      }

      if (_pinCtrl.text.trim().isEmpty) {
        _snack('PIN is required to authorize withdrawal');
        return;
      }

      // Build request body with backend-expected field names
      final requestBody = {
        'amount': _amountInFarm,
        'method': _methodToBackend(selectedMethod),
        'pin': _pinCtrl.text.trim(),
      };

      // Add method-specific fields
      switch (selectedMethod) {
        case 'BANK':
          requestBody['accountNumber'] = _accountCtrl.text.trim();
          requestBody['bankName'] = _selectedBank ?? '';
          break;
        case 'MOBILE_MONEY':
          requestBody['phoneNumber'] = _mobileCtrl.text.trim();
          requestBody['mobileMoneyProvider'] =
              _selectedMobileMoneyProvider ?? '';
          break;
        case 'CRYPTO':
          requestBody['cryptoAsset'] = selectedCryptoAsset;
          requestBody['cryptoAddress'] = _walletCtrl.text.trim();
          requestBody['network'] = selectedCryptoNetwork ?? '';
          break;
      }

      final endpoint = selectedMethod == 'CRYPTO'
          ? '/withdraw/crypto'
          : '/withdraw/create';
      final res = await http.post(
        Uri.parse('${AppConfig.api}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${FFAppState().accessToken}',
          'Idempotency-Key': idempotencyKey,
        },
        body: jsonEncode(requestBody),
      );

      if (!mounted) return;
      final data = jsonDecode(res.body);

      print('[WITHDRAW] Response Status: ${res.statusCode}');
      print('[WITHDRAW] Response: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        _applyWithdrawalReservation();
        await AppSessionManager().syncNow(
          profileTimeoutSeconds: 5,
          walletTimeoutSeconds: 5,
          transactionsTimeoutSeconds: 5,
        );
        if (data is Map<String, dynamic>) {
          await _showWithdrawalReceipt(data);
        } else if (data is Map) {
          await _showWithdrawalReceipt(Map<String, dynamic>.from(data));
        }
        _snack('common.transaction_success'.tr());
        _clearFields();
        await _fetchWallet();
        await _fetchHistory();
      } else {
        final errorMsg =
            data['message'] ??
            data['error'] ??
            'common.transaction_failed'.tr();
        print('[WITHDRAW] Backend Error: $errorMsg');
        _snack(errorMsg);
      }
    } catch (e) {
      if (mounted) _snack('common.network_error'.tr());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyWithdrawalReservation() {
    if (!mounted) return;
    setState(() {
      walletBalance = (walletBalance - _amountInFarm)
          .clamp(0, double.infinity)
          .toDouble();
    });
  }

  void _clearFields() {
    _amountCtrl.clear();
    _accountCtrl.clear();
    _walletCtrl.clear();
    _mobileCtrl.clear();
    _pinCtrl.clear();
    setState(() {
      _selectedBank = null;
      _selectedBankCode = null;
      _selectedMobileMoneyProvider = 'MPESA';
      selectedCryptoAsset = 'USDC';
      selectedCryptoNetwork = null;
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  // ── Convert frontend method names to backend format ───────────────────────
  String _methodToBackend(String method) {
    switch (method) {
      case 'BANK':
        return 'BANK_TRANSFER';
      case 'MOBILE_MONEY':
        return 'MOBILE_MONEY';
      case 'CRYPTO':
        return 'CRYPTO';
      default:
        return method;
    }
  }

  // ── Method card ───────────────────────────────────────────────────────────
  Widget _methodCard(
    BuildContext context, {
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
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
    final textColor = selected ? Colors.white : theme.primaryText;
    final subtitleColor = selected ? Colors.white70 : theme.secondaryText;

    return GestureDetector(
      onTap: () {
        setState(() => selectedMethod = method);
        if (method == 'CRYPTO') {
          _fetchCryptoNetworks();
        }
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
                      fontWeight: FontWeight.bold,
                      color: textColor,
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
            if (selected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ── Notification settings ───────────────────────────────────────────────

  // ── Destination fields ────────────────────────────────────────────────────
  Widget _buildDestinationFields() {
    final theme = FlutterFlowTheme.of(context);
    switch (selectedMethod) {
      case 'BANK':
        return Column(
          children: [
            if (_loadingPaystackDestinations)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(),
              )
            else if (_paystackDestinationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _paystackDestinationError!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchPaystackDestinations,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                border: Border.all(color: theme.secondaryText.withAlpha(90)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButton<String>(
                value: _selectedBank,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Select Bank',
                    style: TextStyle(color: theme.secondaryText),
                  ),
                ),
                isExpanded: true,
                underline: const SizedBox(),
                items: _paystackBanks.map((bank) {
                  return DropdownMenuItem(
                    value: bank['name'],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        bank['name']!,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _paystackBanks.isEmpty
                    ? null
                    : (name) {
                        if (name == null) return;
                        final bank = _paystackBanks.firstWhere(
                          (item) => item['name'] == name,
                        );
                        setState(() {
                          _selectedBank = name;
                          _selectedBankCode = bank['code'];
                        });
                      },
              ),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _accountCtrl,
              hint: 'Account Number',
              type: TextInputType.number,
            ),
          ],
        );
      case 'MOBILE_MONEY':
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.secondaryBackground,
                border: Border.all(color: theme.secondaryText.withAlpha(90)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'M-Pesa',
                style: GoogleFonts.plusJakartaSans(
                  color: theme.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _inputField(
              controller: _mobileCtrl,
              hint: 'M-Pesa Phone Number (e.g. +254700...)',
              type: TextInputType.phone,
            ),
          ],
        );
      case 'CRYPTO':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchableCryptoPicker(
              currencies: _availableCryptoAssets,
              selectedCurrency:
                  _availableCryptoAssets.contains(selectedCryptoAsset)
                  ? selectedCryptoAsset
                  : null,
              label: 'Cryptocurrency',
              onSelected: (value) {
                setState(() {
                  selectedCryptoAsset = value;
                  selectedCryptoNetwork = null;
                });
              },
            ),
            const SizedBox(height: 8),
            Text(
              'The network is included in the selected currency ticker.',
              style: TextStyle(color: theme.secondaryText, fontSize: 12),
            ),
            if (_loadingCryptoNetworks.contains('all'))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (_cryptoNetworkErrors.containsKey('all'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Could not load payout networks: ${_cryptoNetworkErrors['all']}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchCryptoNetworks,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _inputField(controller: _walletCtrl, hint: 'Wallet Address'),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: GoogleFonts.plusJakartaSans(
        color: FlutterFlowTheme.of(context).primaryText,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: FlutterFlowTheme.of(context).secondaryText),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).secondaryText.withAlpha(90),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  // ── Fee row ───────────────────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
            feature: 'withdraw',
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
                  const BackChevron(),
                  Text(
                    'Withdraw Funds',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                  ),
                  FlutterFlowIconButton(
                    icon: Icon(Icons.info_outline, color: theme.secondaryText),
                    onPressed: () => _snack(
                      'Bank and M-Pesa payouts are sent through Paystack and may take seconds to a few minutes to complete.',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Balance card
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF111111) : Colors.black,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: loadingWallet
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AVAILABLE BALANCE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${walletBalance.toStringAsFixed(4)} FARM',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 28),

                  // Amount input card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.secondaryText.withAlpha(60),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Withdrawal Amount',
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryText,
                          ),
                          decoration: InputDecoration(
                            prefixText: selectedMethod == 'CRYPTO'
                                ? 'USD '
                                : null,
                            border: InputBorder.none,
                            hintText: '0.00',
                            hintStyle: TextStyle(color: theme.secondaryText),
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedMethod == 'CRYPTO'
                                  ? 'Min: USD 1.00'
                                  : 'Min: FARM ${_formatAmount(_activeWithdrawMin)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _activeWithdrawMax == null
                                  ? selectedMethod == 'CRYPTO'
                                        ? 'Max: USD ${(_cryptoFarmUsdRate == null ? 0 : walletBalance * _cryptoFarmUsdRate!).toStringAsFixed(2)}'
                                        : 'Max: FARM no limit'
                                  : 'Max: FARM ${_formatAmount(_activeWithdrawMax!)}',
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _withdrawValidationMessage,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: amount > 0 && !_hasValidWithdrawAmount
                                ? Colors.redAccent
                                : theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Method selection
                  Text(
                    'Select Method',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _methodCard(
                    context,
                    method: 'BANK',
                    icon: Icons.account_balance,
                    title: 'Bank Transfer',
                    subtitle: 'bank payout',
                  ),
                  _methodCard(
                    context,
                    method: 'MOBILE_MONEY',
                    icon: Icons.phone_android,
                    title: 'Mobile Money',
                    subtitle: 'M-Pesa payout',
                  ),
                  _methodCard(
                    context,
                    method: 'CRYPTO',
                    icon: Icons.currency_bitcoin,
                    title: 'Crypto Wallet',
                    subtitle: 'NOWPayments payout with admin approval',
                  ),

                  const SizedBox(height: 20),

                  // Destination inputs
                  _buildDestinationFields(),

                  const SizedBox(height: 16),

                  if (_pinEntryEnabled)
                    TextField(
                      controller: _pinCtrl,
                      focusNode: _pinFocusNode,
                      readOnly: !_pinEntryEnabled || _isBiometricChecking,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      onTap: () async {
                        if (!_pinEntryEnabled && !_isBiometricChecking) {
                          await _promptBiometricForPinField();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Transaction PIN',
                        hintStyle: TextStyle(color: theme.secondaryText),
                        filled: true,
                        fillColor: theme.secondaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: theme.secondaryText.withAlpha(90),
                          ),
                        ),
                        suffixIcon: _isBiometricChecking
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        counterText: '',
                      ),
                    )
                  else if (!_isBiometricChecking)
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _promptBiometricForPinField,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1F1F1F)
                              : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Fee breakdown
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.secondaryText.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        _feeRow(
                          selectedMethod == 'CRYPTO'
                              ? 'Withdrawal Amount'
                              : 'FARM Amount',
                          selectedMethod == 'CRYPTO'
                              ? 'USD ${amount.toStringAsFixed(2)} (${_amountInFarm.toStringAsFixed(4)} FARM)'
                              : '${amount.toStringAsFixed(4)} FARM',
                        ),
                        const SizedBox(height: 12),
                        _feeRow(
                          'Fee (${(feeRate * 100).toStringAsFixed(1)}%)',
                          '${fee.toStringAsFixed(4)} FARM',
                        ),
                        const Divider(height: 24),
                        _feeRow(
                          'You Receive',
                          '${settlement.toStringAsFixed(4)} FARM',
                          bold: true,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  // Submit button
                  if (_pinEntryEnabled)
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? const Color(0xFF1F1F1F)
                              : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: (isLoading || !_hasValidWithdrawAmount)
                            ? null
                            : _createWithdraw,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'Withdraw Funds',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Withdrawals',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_selectedWithdrawals.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label: Text(
                        'Download selected (${_selectedWithdrawals.length})',
                      ),
                      onPressed: _downloadSelectedWithdrawals,
                    ),
                  TextButton(
                    onPressed: _fetchHistory,
                    child: const Text('Refresh'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              if (loadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: theme.secondaryText.withAlpha(70),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'No withdrawal history',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                )
              else
                ...history.asMap().entries.map((entry) {
                  final index = entry.key;
                  final w = entry.value;
                  final meta = w['metadata'] as Map<String, dynamic>? ?? {};
                  final statusRaw = (w['status'] ?? 'pending').toString();
                  final status = statusRaw.toLowerCase();
                  final isComplete =
                      status == 'completed' || status == 'success';
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onLongPress: () => setState(() {
                      _selectedWithdrawals.add(index);
                    }),
                    onTap: () {
                      if (_selectedWithdrawals.isNotEmpty) {
                        setState(() {
                          if (!_selectedWithdrawals.add(index)) {
                            _selectedWithdrawals.remove(index);
                          }
                        });
                        return;
                      }
                      TransactionReceiptService.showDetails(
                        context,
                        Map<String, dynamic>.from(w as Map),
                        fetchLatest: true,
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.secondaryBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.secondaryText.withAlpha(70),
                        ),
                      ),
                      child: Row(
                        children: [
                          if (_selectedWithdrawals.isNotEmpty)
                            Checkbox(
                              value: _selectedWithdrawals.contains(index),
                              onChanged: (selected) => setState(() {
                                if (selected == true) {
                                  _selectedWithdrawals.add(index);
                                } else {
                                  _selectedWithdrawals.remove(index);
                                }
                              }),
                            ),
                          Container(
                            width: 42,
                            height: 42,
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
                                  meta['method'] ??
                                      w['description'] ??
                                      'Withdrawal',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryText,
                                  ),
                                ),
                                Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '-${w['amount']} FARM',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
