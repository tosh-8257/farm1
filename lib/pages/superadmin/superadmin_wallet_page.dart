import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '/backend/services/api_service.dart';
import 'superadmin_dashboard_page.dart';
import 'superadmin_pin_setup_page.dart';
import 'superadmin_change_pin_page.dart';
import '/services/app_session_manager.dart';
import '/services/transaction_authentication_service.dart';
import '/services/transaction_authorization_service.dart';

class SuperadminWalletPage extends StatefulWidget {
  const SuperadminWalletPage({super.key});

  static const String routeName = 'superadmin_wallet';
  static const String routePath = '/superadmin/wallet';

  @override
  State<SuperadminWalletPage> createState() => _SuperadminWalletPageState();
}

class _SuperadminWalletPageState extends State<SuperadminWalletPage> {
  Map<String, dynamic>? _walletData;
  bool _loading = true;
  bool _loadingHistory = true;
  String? _error;
  String _selectedWithdrawalMethod = 'MOBILE_MONEY';
  String? _selectedBank;
  String _selectedCryptoAsset = 'USDC';
  String? _selectedCryptoNetwork;
  List<dynamic> _history = [];

  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _cryptoAddressController = TextEditingController();
  final _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _pinEntryEnabled = false;
  bool _isBiometricChecking = false;
  TransactionAuthenticationResult? _lastPinAuthResult;

  final List<String> _banks = [
    'ABSA Bank Kenya',
    'Barclays Bank Kenya',
    'CFC Stanbic Bank',
    'Co-operative Bank',
    'Equity Bank',
    'I&M Bank',
    'KCB Bank',
    'Kenya Commercial Bank',
    'Kinetic Bank',
    'National Bank of Kenya',
    'Safaricom (M-Pesa)',
    'Standard Chartered Bank',
    'The One Finance Bank',
    'Transnational Bank',
    'UBA Kenya',
  ];

  final List<String> _cryptoAssets = ['USDC', 'USDT'];
  final Map<String, List<String>> _cryptoNetworks = {
    'USDC': [
      'BNB Smart Chain (BEP20)',
      'Polygon',
      'Solana',
      'Base',
      'Starknet',
      'Algorand',
    ],
    'USDT': [
      'BNB Smart Chain (BEP20)',
      'Polygon',
      'Solana',
      'Starknet',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _fetchWithdrawalHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _cryptoAddressController.dispose();
    _pinController.dispose();
    _pinFocusNode.dispose();
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
            localizedReason: 'Confirm withdrawal',
          )
          .then((r) => r.toTransactionAuthenticationResult());

      if (authResult.biometricUsed) {
        if (!mounted) return;
        await _processWithdrawal(preAuthResult: authResult);
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

  Future<void> _loadWalletData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp =
          await ApiService.request(method: 'GET', path: '/admin/wallet');
      setState(() => _walletData = resp['data'] ?? resp);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _processWithdrawal(
      {TransactionAuthenticationResult? preAuthResult}) async {
    final amount = double.tryParse(_amountController.text.trim());
    final validationError = _validateWithdrawal(amount);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    try {
      final authResult = preAuthResult ??
          _lastPinAuthResult ??
          await TransactionAuthorizationService()
              .authorizeTransaction(
                localizedReason: 'Confirm withdrawal',
              )
              .then((r) => r.toTransactionAuthenticationResult());

      final usedBiometric = authResult?.biometricUsed == true;
      if (usedBiometric) {
        final Map<String, dynamic> body = {
          'amount': amount,
          'method': _selectedWithdrawalMethod,
          'pin': null,
          'biometric_auth': true,
          'device_fingerprint': authResult?.deviceFingerprint,
        };
        _appendDestinationFields(body);

        await ApiService.request(
          method: 'POST',
          path: '/withdraw/create',
          body: body,
        );

        await AppSessionManager().syncNow(
          profileTimeoutSeconds: 5,
          walletTimeoutSeconds: 5,
          transactionsTimeoutSeconds: 5,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Withdrawal request submitted successfully')),
        );
        _loadWalletData();
        _fetchWithdrawalHistory();
        return;
      }

      if (_pinController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PIN is required to authorize withdrawal')),
        );
        return;
      }

      // Ensure authenticated; ApiService.request will attempt refresh if needed

      final Map<String, dynamic> body = {
        'amount': amount,
        'method': _selectedWithdrawalMethod,
        'pin': _pinController.text,
      };
      _appendDestinationFields(body);

      final decoded = await ApiService.request(
          method: 'POST', path: '/withdraw/create', body: body);

      _clearWithdrawalForm();
      await _loadWalletData();
      await _fetchWithdrawalHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Withdrawal initiated: ${decoded['reference'] ?? ''}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String? _validateWithdrawal(double? amount) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Enter a valid withdrawal amount';
    }

    final limits = <String, List<double>>{
      'BANK_TRANSFER': [4999, 999999],
      'MOBILE_MONEY': [1499, 249999],
      'CRYPTO': [100, double.infinity],
    }[_selectedWithdrawalMethod]!;
    if (amount < limits[0] || amount > limits[1]) {
      final maximum =
          limits[1].isFinite ? ' - ${limits[1].toStringAsFixed(0)}' : '+';
      return 'Amount must be between FARM ${limits[0].toStringAsFixed(0)}$maximum';
    }

    final available = double.tryParse(
          (_walletData?['available_balance'] ?? _walletData?['balance'] ?? 0)
              .toString(),
        ) ??
        0;
    if (amount > available) return 'Insufficient FARM balance';

    switch (_selectedWithdrawalMethod) {
      case 'MOBILE_MONEY':
        if (_phoneController.text.trim().isEmpty) {
          return 'Phone number required for mobile money';
        }
        break;
      case 'BANK_TRANSFER':
        if (_selectedBank == null ||
            _accountNameController.text.trim().isEmpty ||
            _accountNumberController.text.trim().isEmpty) {
          return 'Bank, account name and account number are required';
        }
        break;
      case 'CRYPTO':
        if (_selectedCryptoAsset.isEmpty ||
            _selectedCryptoNetwork == null ||
            _cryptoAddressController.text.trim().isEmpty) {
          return 'Crypto asset, network and wallet address are required';
        }
        break;
    }
    return null;
  }

  void _appendDestinationFields(Map<String, dynamic> body) {
    switch (_selectedWithdrawalMethod) {
      case 'MOBILE_MONEY':
        body['phoneNumber'] = _phoneController.text.trim();
        break;
      case 'BANK_TRANSFER':
        body['accountName'] = _accountNameController.text.trim();
        body['accountNumber'] = _accountNumberController.text.trim();
        body['bankName'] = _selectedBank;
        break;
      case 'CRYPTO':
        body['cryptoAsset'] = _selectedCryptoAsset;
        body['cryptoAddress'] = _cryptoAddressController.text.trim();
        body['network'] = _selectedCryptoNetwork;
        break;
    }
  }

  Future<void> _fetchWithdrawalHistory() async {
    setState(() {
      _loadingHistory = true;
    });

    try {
      final resp =
          await ApiService.request(method: 'GET', path: '/withdraw/history');
      final decoded = resp['data'] ?? resp;
        final data = decoded is Map<String, dynamic>
          ? decoded['data'] ?? decoded['withdrawals'] ?? []
          : decoded;

        final history = data is List ? data : <dynamic>[];
        if (!mounted) return;
        setState(() => _history = List<dynamic>.from(history));
    } catch (_) {
      setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _openPinSetupPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SuperadminPinSetupPage()),
    );
  }

  Future<void> _openChangePinPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SuperadminChangePinPage()),
    );
  }

  void _clearWithdrawalForm() {
    _amountController.clear();
    _phoneController.clear();
    _accountNameController.clear();
    _accountNumberController.clear();
    _bankNameController.clear();
    _cryptoAddressController.clear();
    _pinController.clear();
    _selectedBank = null;
    _selectedCryptoAsset = 'USDC';
    _selectedCryptoNetwork = null;
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';
    final dateString = dateValue.toString();
    final date = DateTime.tryParse(dateString);
    if (date != null) {
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    return dateString.split('T').first;
  }

  String _resolveHistoryMethod(Map<String, dynamic> item) {
    final rawMethod = item['method'] ??
        item['payment_method'] ??
        item['withdrawal_method'] ??
        item['metadata']?['method'] ??
        item['metadata']?['payment_method'];
    if (rawMethod == null) return 'Unknown';
    return rawMethod.toString().replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF0B1320);
    final cardColor = const Color(0xFF111B2A);
    final accent = const Color(0xFFD4AF37);
    final muted = Colors.white70;

    if (_loading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading wallet',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadWalletData,
                style: ElevatedButton.styleFrom(backgroundColor: accent),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final balance = _asDouble(
      _walletData?['available_balance'] ?? _walletData?['balance']);
    final pendingWithdrawals = _asDouble(_walletData?['pending_withdrawals']);
    final totalWithdrawn = _asDouble(_walletData?['total_withdrawn']);
    final currency = _walletData?['currency'] ?? 'FARM';
    final creationRevenue = _asDouble(_walletData?['escrow_creation_revenue']);
    final releaseRevenue = _asDouble(_walletData?['escrow_release_revenue']);
    final withdrawalRevenue = _asDouble(_walletData?['withdrawal_revenue']);
    final merchantSalesRevenue =
        _asDouble(_walletData?['merchant_sales_revenue']);
    final merchantSalesCount =
        _asDouble(_walletData?['merchant_sales_count']).toInt();
    final totalPlatformRevenue =
        _asDouble(_walletData?['total_platform_revenue']);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to dashboard',
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(SuperadminDashboardPage.routePath);
            }
          },
        ),
        title: Text(
          'Superadmin Wallet',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              _buildBalanceCard(balance, pendingWithdrawals, currency, accent,
                  cardColor, muted),
              const SizedBox(height: 24),

              // Withdrawal Stats
              _buildWithdrawalStats(
                  totalWithdrawn, currency, accent, cardColor, muted),
              const SizedBox(height: 24),

              _buildRevenueBreakdown(
                creationRevenue,
                releaseRevenue,
                withdrawalRevenue,
                merchantSalesRevenue,
                merchantSalesCount,
                totalPlatformRevenue,
                accent,
                cardColor,
                muted,
              ),
              const SizedBox(height: 24),

              Text(
                'Wallet Security',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPinSetupPage,
                      icon: const Icon(Icons.lock_outline_rounded),
                      label: const Text('Create PIN'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openChangePinPage,
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Change PIN'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Withdrawal Method Selection
              Text(
                'Withdraw Funds',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Method Selection Tabs
              _buildMethodTabs(accent, cardColor),
              const SizedBox(height: 16),

              // Dynamic Form Fields
              _buildWithdrawalForm(accent, cardColor, muted),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processWithdrawal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Withdraw Funds',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Withdrawal History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Withdrawal History',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: _fetchWithdrawalHistory,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_loadingHistory)
                const Center(child: CircularProgressIndicator())
              else if (_history.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    'No withdrawal history available',
                    style: GoogleFonts.plusJakartaSans(color: Colors.white54),
                  ),
                )
              else
                Column(
                  children: _history.map((item) {
                    final statusRaw = (item['status'] ?? 'pending').toString();
                    final status = statusRaw.toLowerCase();
                    final isComplete =
                        status == 'completed' || status == 'success';
                    final method =
                        _resolveHistoryMethod(item as Map<String, dynamic>);
                    final date = _formatDate(item['created_at'] ??
                        item['createdAt'] ??
                        item['processed_at'] ??
                        item['date']);
                    final amount = item['amount'] ??
                        item['settlement'] ??
                        item['balance'] ??
                        0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                method,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                date,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'FARM ${double.tryParse(amount.toString())?.toStringAsFixed(4) ?? amount.toString()}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isComplete
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isComplete
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(double balance, double pending, String currency,
      Color accent, Color cardColor, Color muted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.1),
            accent.withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Balance',
            style: GoogleFonts.plusJakartaSans(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${currency.toUpperCase()} ${balance.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currency.toUpperCase()} ${pending.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalStats(double totalWithdrawn, String currency,
      Color accent, Color cardColor, Color muted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Withdrawn',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${currency.toUpperCase()} ${totalWithdrawn.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet_rounded,
                color: accent, size: 24),
          ),
        ],
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildRevenueBreakdown(
      double creation,
      double release,
      double withdrawal,
      double merchantSales,
      int merchantSalesCount,
      double total,
      Color accent,
      Color cardColor,
      Color muted) {
    Widget revenueItem(String label, double value, Color color) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Text(
              '${value.toStringAsFixed(2)} FARM',
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Platform Revenue',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Gross fees earned across escrow, withdrawals, and merchant sales',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Available balance is net of pending locks and completed withdrawals.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              revenueItem('Escrow creation', creation, Colors.greenAccent),
              revenueItem('Escrow release', release, Colors.lightBlueAccent),
              revenueItem('Withdrawals', withdrawal, Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merchant revenue',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.purpleAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Merchant fees from $merchantSalesCount sales',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${merchantSales.toStringAsFixed(2)} FARM',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.purpleAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total platform revenue',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70, fontSize: 13)),
              Text(
                '${total.toStringAsFixed(2)} FARM',
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs(Color accent, Color cardColor) {
    final methods = [
      ('MOBILE_MONEY', 'Mobile Money', Icons.phone_android_rounded),
      ('BANK_TRANSFER', 'Bank Transfer', Icons.account_balance_rounded),
      ('CRYPTO', 'Crypto', Icons.currency_bitcoin_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: methods.map((method) {
          final isSelected = _selectedWithdrawalMethod == method.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _selectedWithdrawalMethod = method.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? accent : cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? accent : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      method.$3,
                      color: isSelected ? Colors.black : accent,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      method.$2,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWithdrawalForm(Color accent, Color cardColor, Color muted) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
              'Amount (FARM)', _amountController, 'Enter amount', accent,
              isNumeric: true),
          const SizedBox(height: 14),
          if (_selectedWithdrawalMethod == 'MOBILE_MONEY') ...[
            _buildInputField(
                'Phone Number', _phoneController, 'e.g. +254712345678', accent),
            const SizedBox(height: 14),
          ] else if (_selectedWithdrawalMethod == 'BANK_TRANSFER') ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(14),
                color: cardColor,
              ),
              child: DropdownButton<String>(
                value: _selectedBank,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Select Bank',
                      style:
                          GoogleFonts.plusJakartaSans(color: Colors.white70)),
                ),
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: cardColor,
                items: _banks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(bank,
                          style:
                              GoogleFonts.plusJakartaSans(color: Colors.white)),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedBank = value),
              ),
            ),
            const SizedBox(height: 14),
            _buildInputField('Account Name', _accountNameController,
                'Name on bank account', accent),
            const SizedBox(height: 14),
            _buildInputField('Account Number', _accountNumberController,
                'Bank account number', accent),
            const SizedBox(height: 14),
          ] else if (_selectedWithdrawalMethod == 'CRYPTO') ...[
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(14),
                color: cardColor,
              ),
              child: DropdownButton<String>(
                value: _selectedCryptoAsset,
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: cardColor,
                items: _cryptoAssets.map((asset) {
                  return DropdownMenuItem(
                    value: asset,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(asset,
                          style:
                              GoogleFonts.plusJakartaSans(color: Colors.white)),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCryptoAsset = value;
                    _selectedCryptoNetwork = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white10),
                borderRadius: BorderRadius.circular(14),
                color: cardColor,
              ),
              child: DropdownButton<String>(
                value: _selectedCryptoNetwork,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Select Network',
                      style:
                          GoogleFonts.plusJakartaSans(color: Colors.white70)),
                ),
                isExpanded: true,
                underline: const SizedBox(),
                dropdownColor: cardColor,
                items: (_cryptoNetworks[_selectedCryptoAsset] ?? [])
                    .map((network) {
                  return DropdownMenuItem(
                    value: network,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(network,
                          style:
                              GoogleFonts.plusJakartaSans(color: Colors.white)),
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedCryptoNetwork = value),
              ),
            ),
            const SizedBox(height: 14),
            _buildInputField('Wallet Address', _cryptoAddressController,
                'Your wallet address', accent),
            const SizedBox(height: 14),
          ],
          if (_pinEntryEnabled)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  readOnly: !_pinEntryEnabled || _isBiometricChecking,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Your transaction PIN',
                    hintStyle:
                        GoogleFonts.plusJakartaSans(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accent),
                    ),
                    suffixIcon: _isBiometricChecking
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  onTap: () async {
                    if (!_pinEntryEnabled && !_isBiometricChecking) {
                      await _promptBiometricForPinField();
                    }
                  },
                ),
              ],
            )
          else if (!_isBiometricChecking)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _promptBiometricForPinField,
                child: const Text('Continue'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField(
      String label, TextEditingController controller, String hint, Color accent,
      {bool isPassword = false, bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }
}
