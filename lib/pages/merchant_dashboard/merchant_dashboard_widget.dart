import '/components/button/button_widget.dart';
import '/pages/business/business_upgrade_tile.dart';
import '/components/merchant_stat_card/merchant_stat_card_widget.dart';
import '/components/merchant_transaction_item/merchant_transaction_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/services/api_service.dart';
import '/core/app_config.dart';
import '/services/qr_download_service.dart';
import '/services/branded_qr_card_service.dart';
import '/utils/merchant_qr_utils.dart';
import '/services/transaction_receipt_service.dart';

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import 'merchant_dashboard_model.dart';

class MerchantDashboardWidget extends StatefulWidget {
  const MerchantDashboardWidget({super.key});

  static String routeName = 'MerchantDashboard';
  static String routePath = '/merchantDashboard';

  @override
  State<MerchantDashboardWidget> createState() =>
      _MerchantDashboardWidgetState();
}

class _MerchantDashboardWidgetState extends State<MerchantDashboardWidget> {
  late MerchantDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool loading = true;
  bool payoutLoading = false;
  bool regeneratingQr = false;
  bool applyingMerchant = false;
  bool merchantNotFound = false;
  String merchantStatus = 'active';
  String? merchantStatusMessage;

  Map<String, dynamic>? merchant;
  Map<String, dynamic>? stats;

  List<dynamic> recentTransactions = [];
  List<double> weeklyData = List<double>.filled(7, 0);
  List<String> weeklyLabels = List<String>.filled(7, '');
  String? merchantQrImageBase64;

  List<dynamic> get _completedRecentTransactions => recentTransactions
      .where((tx) =>
          tx is Map &&
          tx['status']?.toString().trim().toLowerCase() == 'completed')
      .toList();

  String? get _merchantQrBase64 {
    if (merchantQrImageBase64 != null && merchantQrImageBase64!.isNotEmpty) {
      return merchantQrImageBase64;
    }

    return extractMerchantQrBase64(merchant);
  }

  final TextEditingController amountController = TextEditingController();
  final TextEditingController accountNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();

  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessTypeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  String payoutMethod = 'M-PESA';

  final String baseUrl = AppConfig.api;

  void _goToUserDashboard() {
    context.go('/dashboard');
  }

  Widget _withDashboardBackNavigation(Widget child) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goToUserDashboard();
        }
      },
      child: child,
    );
  }

  Widget _buildBackButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: _goToUserDashboard,
      tooltip: 'Back to dashboard',
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurface,
        shape: const CircleBorder(),
        fixedSize: const Size.square(44),
      ),
      icon: const Icon(Icons.chevron_left_rounded, size: 32),
    );
  }

  Future<String?> getToken() async {
    return FFAppState().accessToken;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MerchantDashboardModel());
    FFAppState().addListener(_handleWalletStateChanged);
    fetchDashboard();
  }

  void _handleWalletStateChanged() {
    if (!mounted || loading || stats == null) return;

    final dashboardBalance =
        double.tryParse(stats?['wallet_balance']?.toString() ?? '');
    if (dashboardBalance == null ||
        (dashboardBalance - FFAppState().walletBalance).abs() < 0.00000001) {
      return;
    }

    fetchDashboard(showLoading: false);
  }

  @override
  void dispose() {
    FFAppState().removeListener(_handleWalletStateChanged);
    _model.dispose();
    amountController.dispose();
    accountNameController.dispose();
    accountNumberController.dispose();
    businessNameController.dispose();
    businessTypeController.dispose();
    emailController.dispose();
    phoneController.dispose();
    countryController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> fetchDashboard({bool showLoading = true}) async {
    try {
      if (showLoading) {
        setState(() {
          loading = true;
          merchantNotFound = false;
          merchantStatusMessage = null;
        });
      }

      final resp =
          await ApiService.request(method: 'GET', path: '/merchant/dashboard');
      final rawData = resp['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : Map<String, dynamic>.from(resp);
      final status = data['application_status']?.toString().toLowerCase() ??
          ((data['merchant'] is Map && data['merchant']['status'] != null)
              ? data['merchant']['status'].toString().toLowerCase()
              : 'active');
      if (status == 'not_submitted' ||
          status == 'pending' ||
          status == 'rejected' ||
          status == 'kyc_required') {
        setState(() {
          merchantStatus = status;
          merchantStatusMessage = data['message']?.toString();
          merchantNotFound = status == 'not_submitted';
          loading = false;
        });
        return;
      }

      final transactions = data['recent_transactions'] is List
          ? data['recent_transactions'] as List
          : <dynamic>[];
      setState(() {
        merchantStatus = status;
        merchant = data['merchant'] is Map
            ? Map<String, dynamic>.from(data['merchant'])
            : null;
        stats = data['stats'] is Map
            ? Map<String, dynamic>.from(data['stats'])
            : null;
        recentTransactions = transactions;
        final weekly = _buildWeeklyData(data['stats'], transactions);
        weeklyData = weekly.amounts;
        weeklyLabels = weekly.labels;
        loading = false;
      });

      if (_merchantQrBase64 == null) {
        await _fetchMerchantQr();
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (message.toLowerCase().contains('merchant account not found')) {
        setState(() {
          merchantStatus = 'not_submitted';
          merchantNotFound = true;
          merchantStatusMessage =
              'Welcome to the Merchant Portal. Submit your business details to get started.';
          loading = false;
        });
        return;
      }
      if (message.toLowerCase().contains('full kyc')) {
        setState(() {
          merchantStatus = 'kyc_required';
          merchantStatusMessage =
              'Complete full identity verification before accessing the Merchant Portal.';
          loading = false;
        });
        return;
      }
      setState(() => loading = false);
      showError(
          message.isEmpty ? 'Unable to load merchant dashboard' : message);
    }
  }

  ({List<double> amounts, List<String> labels}) _buildWeeklyData(
    Map<String, dynamic>? data,
    List<dynamic> transactions,
  ) {
    if (data != null && data['weekly_performance'] is List) {
      final raw = data['weekly_performance'];
      if (raw is List) {
        final converted = raw.whereType<Map>().toList();
        if (converted.length == 7) {
          return (
            amounts: converted
                .map((value) =>
                    double.tryParse(value['amount']?.toString() ?? '0') ?? 0)
                .toList(),
            labels: converted.map((value) {
              final date = DateTime.tryParse(value['date']?.toString() ?? '');
              return date == null ? '-' : '${date.day}/${date.month}';
            }).toList(),
          );
        }
      }
    }

    final now = DateTime.now();
    final totals = List<double>.filled(7, 0);
    for (final tx in transactions) {
      final createdAt = tx['created_at'] ?? tx['createdAt'] ?? tx['timestamp'];
      final date = DateTime.tryParse(createdAt?.toString() ?? '');
      if (date == null) continue;
      final daysAgo = now.difference(date).inDays;
      if (daysAgo < 0 || daysAgo >= 7) continue;
      final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
      totals[(date.weekday + 5) % 7] += amount;
    }
    return (
      amounts: totals,
      labels: List.generate(7, (index) {
        final date = now.subtract(Duration(days: 6 - index));
        return '${date.day}/${date.month}';
      }),
    );
  }

  String _formatMerchantTransactionDate(dynamic value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return dateTimeFormatEastAfricanTime('MMM d, yyyy • h:mm a', parsed);
  }

  Future<Uint8List> _getLabeledQrBytes(String qrSource) async {
    final qrBytes = resolveMerchantQrBytes(qrSource);
    if (qrBytes == null || qrBytes.isEmpty) {
      throw Exception('QR payload could not be decoded');
    }
    final businessName = (merchant?['business_name'] ??
            merchant?['businessName'] ??
            'FARM Merchant')
        .toString()
        .trim();
    return BrandedQrCardService.createBrandedCard(
      qrBytes: Uint8List.fromList(qrBytes),
      displayName: businessName.isEmpty ? 'FARM Merchant' : businessName,
      category: 'BUSINESS PAYMENT',
      invertQrColors: true,
    );
  }

  Widget _buildWeeklySalesChart() {
    final theme = FlutterFlowTheme.of(context);
    final highestSale = weeklyData.fold<double>(
        0, (highest, value) => value > highest ? value : highest);
    final chartMax =
        highestSale <= 0 ? 100.0 : ((highestSale * 1.25) / 50).ceil() * 50.0;
    final barColor = theme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        const leftReserved = 22.0;
        const rightPadding = 8.0;
        const topPadding = 8.0;
        const bottomReserved = 28.0;
        final plotWidth = constraints.maxWidth - leftReserved - rightPadding;
        final plotHeight = 168 - topPadding - bottomReserved - 22;

        return SizedBox(
          height: 168,
          child: Stack(
            children: [
              BarChart(
                BarChartData(
                  minY: 0,
                  maxY: chartMax,
                  alignment: BarChartAlignment.spaceEvenly,
                  barTouchData: BarTouchData(enabled: true),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMax / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.alternate.withValues(alpha: 0.35),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text('FARM', style: theme.bodySmall),
                      axisNameSize: 22,
                      sideTitles: const SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text('Date', style: theme.bodySmall),
                      axisNameSize: 22,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: bottomReserved,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= weeklyLabels.length)
                            return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(weeklyLabels[index],
                                style: theme.bodySmall.copyWith(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    weeklyData.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: weeklyData[index],
                          width: 20,
                          color: barColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: leftReserved, right: rightPadding, top: topPadding),
                  child: SizedBox(
                    height: plotHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(weeklyData.length, (index) {
                        final value = weeklyData[index];
                        final labelOffset =
                            plotHeight * (1 - (value / chartMax)) - 14;
                        return SizedBox(
                          width: plotWidth / weeklyData.length,
                          child: Transform.translate(
                            offset: Offset(
                                0, labelOffset.clamp(0, plotHeight - 14)),
                            child: value == 0
                                ? const SizedBox.shrink()
                                : Text(
                                    _formatChartAmount(value),
                                    textAlign: TextAlign.center,
                                    style: theme.bodySmall.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatChartAmount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> applyMerchant() async {
    final requiredFields = [
      businessNameController.text,
      businessTypeController.text,
      emailController.text,
      phoneController.text,
      countryController.text,
      cityController.text,
    ];
    if (requiredFields.any((value) => value.trim().isEmpty)) {
      showError('Please complete all six business details before submitting.');
      return;
    }

    final businessEmail = emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(businessEmail)) {
      showError('Enter a valid business email address.');
      return;
    }

    try {
      setState(() {
        applyingMerchant = true;
      });

      final body = await ApiService.request(
        method: 'POST',
        path: '/merchant/apply',
        body: {
          'business_name': businessNameController.text.trim(),
          'business_type': businessTypeController.text.trim(),
          'business_email': businessEmail,
          'business_phone': phoneController.text.trim(),
          'country': countryController.text.trim(),
          'city': cityController.text.trim(),
        },
      );

      setState(() {
        applyingMerchant = false;
      });

      Navigator.pop(context);
      showSuccess(body['message'] ?? 'Merchant application submitted');
      fetchDashboard();
    } catch (e) {
      setState(() {
        applyingMerchant = false;
      });
      showError(e.toString());
    }
  }

  Future<void> regenerateQr() async {
    try {
      setState(() {
        regeneratingQr = true;
      });

      final body = await ApiService.regenerateMerchantQr();
      setState(() {
        regeneratingQr = false;
      });

      if (body.isNotEmpty) {
        showSuccess('QR regenerated successfully');
        fetchDashboard();
      } else {
        showError('Failed to regenerate QR');
      }
    } catch (e) {
      setState(() {
        regeneratingQr = false;
      });
      showError(e.toString());
    }
  }

  Future<void> _fetchMerchantQr() async {
    try {
      final body = await ApiService.getMerchantQr();
      final extracted = extractMerchantQrBase64(body);
      if (extracted != null && extracted.isNotEmpty) {
        setState(() {
          merchantQrImageBase64 = extracted;
        });
        return;
      }

      // Some backends return a payload without the QR until a regeneration call is made.
      try {
        final regenerated = await ApiService.regenerateMerchantQr();
        final regeneratedQr = extractMerchantQrBase64(regenerated);
        if (regeneratedQr != null && regeneratedQr.isNotEmpty) {
          setState(() {
            merchantQrImageBase64 = regeneratedQr;
          });
        }
      } catch (_) {}
    } catch (_) {
      // ignore fetch failure; UI can still show placeholder.
    }
  }

  Future<void> requestPayout() async {
    try {
      setState(() {
        payoutLoading = true;
      });

      await ApiService.request(
        method: 'POST',
        path: '/merchant/payout',
        body: {
          'amount': double.parse(amountController.text),
          'payout_method': payoutMethod,
          'account_name': accountNameController.text,
          'account_number': accountNumberController.text,
        },
      );

      setState(() {
        payoutLoading = false;
      });

      Navigator.pop(context);
      showSuccess('Payout request submitted');
      fetchDashboard();
    } catch (e) {
      setState(() {
        payoutLoading = false;
      });
      showError(e.toString());
    }
  }

  Future<void> _downloadQrKit() async {
    String? qrSource = _merchantQrBase64;
    if (qrSource == null || qrSource.isEmpty) {
      qrSource = extractMerchantQrBase64(merchant);
    }

    if (qrSource == null || qrSource.isEmpty) {
      try {
        await _fetchMerchantQr();
      } catch (_) {}
      qrSource = _merchantQrBase64;
    }

    if (qrSource == null || qrSource.isEmpty) {
      try {
        await fetchDashboard();
      } catch (_) {}
      qrSource = _merchantQrBase64;
    }

    if (qrSource == null || qrSource.isEmpty) {
      try {
        final body = await ApiService.getMerchantQr();
        qrSource = extractMerchantQrBase64(body);
      } catch (_) {}
    }

    if (qrSource == null || qrSource.isEmpty) {
      try {
        final body = await ApiService.regenerateMerchantQr();
        qrSource = extractMerchantQrBase64(body);
      } catch (_) {}
    }

    if (qrSource == null || qrSource.isEmpty) {
      if (mounted) {
        showError(
            'No QR code available to download yet. Please try again shortly.');
      }
      return;
    }

    try {
      final bytes = await _getLabeledQrBytes(qrSource);

      final fileName =
          'farm_merchant_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final result = await QrDownloadService.instance.downloadQr(
        Uint8List.fromList(bytes),
        fileName: fileName,
      );

      if (mounted) {
        setState(() {
          merchantQrImageBase64 = qrSource;
        });
      }

      if (!result.success) {
        if (mounted) showError(result.message);
        return;
      }

      if (mounted) {
        _showQrSavedDialog(result);
      }
    } catch (e) {
      if (mounted) {
        showError('Failed to save QR code: ${e.toString()}');
      }
    }
  }

  Future<void> _shareQrKit() async {
    try {
      final qrSource = _merchantQrBase64 ?? extractMerchantQrBase64(merchant);
      if (qrSource == null || qrSource.isEmpty) {
        showError('No QR code available to share.');
        return;
      }

      final bytes = await _getLabeledQrBytes(qrSource);
      await QrDownloadService.instance.shareQr(bytes);
    } catch (e) {
      showError('Failed to share QR code: ${e.toString()}');
    }
  }

  void _showQrSavedDialog(QrDownloadResult result) {
    final message = result.destination == QrDownloadDestination.iosPhotos
        ? 'Saved to Photos'
        : result.destination == QrDownloadDestination.androidDownloads
            ? 'Saved to Downloads/Farm Africa'
            : 'QR Code saved successfully.';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('✓ QR Code Saved'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareQrKit();
              },
              child: const Text('SHARE'),
            ),
          ],
        );
      },
    );
  }

  void _openMerchantSales() {
    if (merchant == null) return;
    context.pushNamed('MerchantSales');
  }

  void openApplyMerchantModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Create Merchant Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                buildInput(businessNameController, 'Business Name'),
                const SizedBox(height: 18),
                buildInput(businessTypeController, 'Business Type'),
                const SizedBox(height: 18),
                buildInput(emailController, 'Business Email'),
                const SizedBox(height: 18),
                buildInput(phoneController, 'Business Phone'),
                const SizedBox(height: 18),
                buildInput(countryController, 'Country'),
                const SizedBox(height: 18),
                buildInput(cityController, 'City'),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: applyingMerchant ? null : applyMerchant,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.accent,
                      foregroundColor:
                          AppTheme.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: applyingMerchant
                        ? const CircularProgressIndicator(color: AppTheme.onAccent)
                        : const Text('Submit Application'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void openPayoutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Request Payout',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 28),
                    buildInput(amountController, 'Amount'),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: payoutMethod,
                      items: ['M-PESA', 'Bank Transfer', 'Wallet']
                          .map((method) => DropdownMenuItem(
                                value: method,
                                child: Text(method),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          payoutMethod = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Payout Method',
                        filled: true,
                        fillColor: const Color(0xFF111B2A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildInput(accountNameController, 'Account Name'),
                    const SizedBox(height: 18),
                    buildInput(accountNumberController, 'Account Number'),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: payoutLoading ? null : requestPayout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.accent,
                          foregroundColor:
                              AppTheme.onAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: payoutLoading
                            ? const CircularProgressIndicator(
                                color: AppTheme.onAccent)
                            : const Text('Submit Payout Request'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message),
      ),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message),
      ),
    );
  }

  String formatAmount(dynamic amount) {
    return (amount ?? 0).toString();
  }

  Widget buildInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF111B2A),
        hintStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _withDashboardBackNavigation(
        Scaffold(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          appBar: AppBar(
            leading: _buildBackButton(),
            title: const Text('Merchant Portal'),
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (merchantNotFound ||
        merchantStatus == 'pending' ||
        merchantStatus == 'rejected' ||
        merchantStatus == 'kyc_required') {
      final needsApplication = merchantNotFound || merchantStatus == 'rejected';
      final needsKyc = merchantStatus == 'kyc_required';
      final title = merchantStatus == 'pending'
          ? 'Application under review'
          : merchantStatus == 'kyc_required'
              ? 'Complete identity verification'
              : merchantStatus == 'rejected'
                  ? 'Application not approved'
                  : 'Welcome to the Merchant Portal';
      final message = merchantStatusMessage ??
          (merchantStatus == 'pending'
              ? 'Your business details are being reviewed. Please wait for an admin decision.'
              : merchantStatus == 'kyc_required'
                  ? 'Complete full identity verification before accessing the Merchant Portal.'
                  : merchantStatus == 'rejected'
                      ? 'Your application was not approved. Review your details and submit again.'
                      : 'Submit your business details to get started.');
      return _withDashboardBackNavigation(
        Scaffold(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .primary
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(
                            merchantStatus == 'kyc_required'
                                ? Icons.verified_user_outlined
                                : merchantStatus == 'pending'
                                    ? Icons.hourglass_top_rounded
                                    : merchantStatus == 'rejected'
                                        ? Icons.info_outline_rounded
                                        : Icons.storefront_rounded,
                            size: 60,
                            color: merchantStatus == 'rejected'
                                ? Colors.orange
                                : Colors.green,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 30,
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        if (needsApplication || needsKyc) ...[
                          const SizedBox(height: 40),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: needsApplication
                                  ? openApplyMerchantModal
                                  : () => context.pushNamed(
                                          'KYCPAGE',
                                          queryParameters: const {
                                            'startDidit': 'true',
                                          },
                                        ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppTheme.accent,
                                foregroundColor:
                                    AppTheme.onAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                needsKyc
                                    ? 'Complete identity verification'
                                    : merchantStatus == 'rejected'
                                        ? 'Update and resubmit details'
                                        : 'Enter business details',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildBackButton(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _withDashboardBackNavigation(
      GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: SingleChildScrollView(
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    shape: BoxShape.rectangle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Container(
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildBackButton(),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merchant Portal',
                                style: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .headlineMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .headlineMedium
                                          .fontStyle,
                                      lineHeight: 1.25,
                                    ),
                              ),
                              Text(
                                'a loop of growth',
                                style: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                      lineHeight: 1.3,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
                  child: BusinessUpgradeTile(),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 24),
                  child: Container(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(24),
                        shape: BoxShape.rectangle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Total Earnings',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .onPrimary80,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                          lineHeight: 1.3,
                                        ),
                                  ),
                                ],
                              ),
                              Text(
                                '${formatAmount(stats?['total_revenue'])} FARM',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .onPrimary,
                                      fontSize: 32,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w800,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                      lineHeight: 1.5,
                                    ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    (stats?['monthly_growth_percentage'] ??
                                                0) >=
                                            0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    size: 16,
                                  ),
                                  Text(
                                    '${(stats?['monthly_growth_percentage'] ?? 0) >= 0 ? '+' : ''}${stats?['monthly_growth_percentage']?.toStringAsFixed(2) ?? '0.00'}% from last month',
                                    style: FlutterFlowTheme.of(context)
                                        .labelSmall
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .onPrimary90,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                          lineHeight: 1.2,
                                        ),
                                  ),
                                ].divide(SizedBox(width: 8)),
                              ),
                            ].divide(SizedBox(height: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.merchantStatCardModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: MerchantStatCardWidget(
                            label: 'Sales Today',
                            value: '${stats?['sales_today_count'] ?? 0}',
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: wrapWithModel(
                          model: _model.merchantStatCardModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: MerchantStatCardWidget(
                            label: 'Revenue',
                            value: '${formatAmount(stats?['sales_today'])}',
                          ),
                        ),
                      ),
                    ].divide(SizedBox(width: 16)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Container(
                    child: Container(
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(20),
                        shape: BoxShape.rectangle,
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Business QR Code',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .override(
                                          font: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                          lineHeight: 1.4,
                                        ),
                                  ),
                                  Icon(
                                    Icons.qr_code_2_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24,
                                  ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFFD6B36A),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          const Color(0xFF0B211C).withAlpha(45),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFD6B36A),
                                      size: 24,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'FARM AFRICA',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFAF8F1),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'BUSINESS PAYMENT',
                                      style: TextStyle(
                                        color: Color(0xFFD6B36A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Builder(
                                        builder: (context) {
                                          final qrBytes =
                                              resolveMerchantQrBytes(
                                            _merchantQrBase64,
                                          );
                                          if (qrBytes == null ||
                                              qrBytes.isEmpty) {
                                            return const SizedBox(
                                              width: 210,
                                              height: 210,
                                              child: Icon(
                                                Icons.qr_code_2_rounded,
                                                size: 120,
                                                color: Color(0xFFD6B36A),
                                              ),
                                            );
                                          }
                                          return ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: ColorFiltered(
                                              colorFilter:
                                                  const ColorFilter.matrix([
                                                -1,
                                                0,
                                                0,
                                                0,
                                                255,
                                                0,
                                                -1,
                                                0,
                                                0,
                                                255,
                                                0,
                                                0,
                                                -1,
                                                0,
                                                255,
                                                0,
                                                0,
                                                0,
                                                1,
                                                0,
                                              ]),
                                              child: Image.memory(
                                                Uint8List.fromList(qrBytes),
                                                width: 210,
                                                height: 210,
                                                fit: BoxFit.contain,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      (merchant?['business_name'] ??
                                              '@merchant')
                                          .toString(),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Scan to pay instantly',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: const Color(0xFFFAF8F1)
                                            .withAlpha(210),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              wrapWithModel(
                                model: _model.buttonModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  content: 'Download Kit',
                                  icon: Icon(
                                    Icons.download_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 16,
                                  ),
                                  icon_present: true,
                                  icon_end_present: false,
                                  onTapCallback: _downloadQrKit,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  variant: 'outline',
                                  size: 'medium',
                                  full_width: true,
                                  loading: false,
                                  disabled: false,
                                ),
                              ),
                              wrapWithModel(
                                model: _model.buttonModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  content: 'Share QR',
                                  icon: Icon(
                                    Icons.share_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 16,
                                  ),
                                  icon_present: true,
                                  icon_end_present: false,
                                  onTapCallback: _shareQrKit,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  variant: 'outline',
                                  size: 'medium',
                                  full_width: true,
                                  loading: false,
                                  disabled: false,
                                ),
                              ),
                            ].divide(SizedBox(height: 24)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 24),
                  child: Container(
                    child: Container(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                        child: Container(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Weekly Performance',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                      lineHeight: 1.4,
                                    ),
                              ),
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  shape: BoxShape.rectangle,
                                  border: Border.all(
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: _buildWeeklySalesChart(),
                                ),
                              ),
                            ].divide(SizedBox(height: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Recent Sales',
                            style: FlutterFlowTheme.of(context)
                                .titleMedium
                                .override(
                                  font: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                  lineHeight: 1.4,
                                ),
                          ),
                          wrapWithModel(
                            model: _model.buttonModel2,
                            updateCallback: () => safeSetState(() {}),
                            child: ButtonWidget(
                              content: 'View All',
                              icon_present: false,
                              icon_end_present: false,
                              onTapCallback: _openMerchantSales,
                              color: FlutterFlowTheme.of(context).primaryText,
                              variant: 'ghost',
                              size: 'small',
                              full_width: false,
                              loading: false,
                              disabled: false,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: _completedRecentTransactions.isEmpty
                            ? [
                                Center(
                                  child: Text(
                                    'No recent transactions',
                                    style:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                  ),
                                ),
                              ]
                            : _completedRecentTransactions
                                .asMap()
                                .entries
                                .map((entry) {
                                int index = entry.key;
                                dynamic tx = entry.value;
                                return wrapWithModel(
                                  model: index == 0
                                      ? _model.merchantTransactionItemModel1
                                      : index == 1
                                          ? _model.merchantTransactionItemModel2
                                          : index == 2
                                              ? _model
                                                  .merchantTransactionItemModel3
                                              : _model
                                                  .merchantTransactionItemModel4,
                                  updateCallback: () => safeSetState(() {}),
                                  child: GestureDetector(
                                    onTap: () =>
                                        TransactionReceiptService.showDetails(
                                            context,
                                            Map<String, dynamic>.from(tx)),
                                    child: MerchantTransactionItemWidget(
                                      amount: '${tx['amount'] ?? 0}',
                                      customer: tx['customer_name']
                                                  ?.toString()
                                                  .trim()
                                                  .isNotEmpty ==
                                              true
                                          ? tx['customer_name']
                                          : '@user',
                                      date: _formatMerchantTransactionDate(
                                          tx['created_at'] ??
                                              tx['createdAt'] ??
                                              tx['timestamp']),
                                      icon: Icon(
                                        Icons.person_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        size: 24,
                                      ),
                                      status: tx['status'] ?? 'COMPLETED',
                                    ),
                                  ),
                                );
                              }).toList(),
                      ),
                    ].divide(SizedBox(height: 16)),
                  ),
                ),
                Container(
                  height: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
