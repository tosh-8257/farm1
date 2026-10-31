import 'dart:async';
import 'dart:convert' as convert;

import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/widgets/revenue_overview_chart.dart';
import 'package:go_router/go_router.dart';
import '/core/app_config.dart';
import '/backend/api_requests/api_manager.dart';
import '/pages/loginpage/loginpage_widget.dart';
import '/pages/superadmin/add_admin_page.dart';
import '/admin/pages/add_superadmin_page.dart';
import '/pages/superadmin/superadmin_wallet_page.dart';
import '/pages/settings/support_help_center_page.dart';
import '/admin/pages/user_management_page.dart';
import '/admin/pages/admin_management_page.dart';
import '/admin/pages/kyc_management_page.dart';
import '/admin/pages/transactions_management_page.dart';
import '/admin/pages/escrow_management_page.dart';
import '/admin/core/admin_navigation.dart';
import '/admin/services/admin_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '/services/auth/auth_service.dart';
import '/core/localization/app_locale_service.dart';
import '/services/transaction_receipt_service.dart';

class SuperadminDashboardPage extends StatefulWidget {
  const SuperadminDashboardPage({super.key});

  static const String routeName = 'superadmin_dashboard';
  static const String routePath = '/superadmin/dashboard';

  @override
  State<SuperadminDashboardPage> createState() =>
      _SuperadminDashboardPageState();
}

class _SuperadminDashboardPageState extends State<SuperadminDashboardPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _superadminWallet;
  List<Map<String, dynamic>> _revenueSeries = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  bool _loadingExchangeRates = true;
  bool _savingExchangeRates = false;
  bool _loadingCurrencyRate = true;
  bool _savingCurrencyRate = false;
  final TextEditingController _kesToFarmCtrl = TextEditingController();
  final TextEditingController _farmToKesCtrl = TextEditingController();
  final TextEditingController _usdToKesCtrl = TextEditingController();
  final TextEditingController _farmToUsdCtrl = TextEditingController();

  bool _isCreatingAdmin = false;

  // Current USD/KES rate metadata from /admin/currency-rates/current.
  String? _rateSource;
  bool _rateOverride = false;
  bool _rateLiveEnabled = false;
  bool _rateStale = false;
  DateTime? _rateUpdatedAt;
  bool _clearingOverride = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint(
        '[SuperadminDashboardPage] initState: starting dashboard initialization');
    _loadDashboardData();
    _loadSuperadminWallet();
    _loadExchangeRates();
    _loadCurrencyRate();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _kesToFarmCtrl.dispose();
    _farmToKesCtrl.dispose();
    _usdToKesCtrl.dispose();
    _farmToUsdCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startPeriodicRefresh();
      unawaited(_refreshSessionAndReload());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      unawaited(_refreshSessionAndReload());
    });
  }

  Future<void> _refreshSessionAndReload() async {
    if (!mounted) return;
    try {
      await AdminApiService.ensureValidSession(force: true);
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) return;
      await Future.wait([
        _loadDashboardData(),
        _loadSuperadminWallet(),
        _loadExchangeRates(),
        _loadCurrencyRate(),
      ]);
    } catch (_) {}
  }

  Future<void> _loadSuperadminWallet() async {
    try {
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) throw Exception('Not authenticated');

      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminWallet',
        apiUrl: '${AppConfig.api}/admin/wallet',
        callType: ApiCallType.GET,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        returnBody: true,
      );

      final decoded = response.jsonBody as Map<String, dynamic>?;
      if (decoded == null) throw Exception('Invalid wallet response');
      setState(() => _superadminWallet = decoded['data'] ?? decoded);
    } catch (e) {
      debugPrint('[SuperadminDashboardPage] _loadSuperadminWallet failed: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    debugPrint('[SuperadminDashboardPage] _loadDashboardData started');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AdminApiService.getValidAccessToken();
      debugPrint(
          '[SuperadminDashboardPage] _loadDashboardData token length=${token.length}');
      if (token.isEmpty) {
        throw Exception('Not authenticated');
      }

      // Fetch dashboard data from backend
      debugPrint(
          '[SuperadminDashboardPage] _loadDashboardData calling ${AppConfig.api}/superadmin/dashboard');
      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminDashboard',
        apiUrl: '${AppConfig.api}/superadmin/dashboard',
        callType: ApiCallType.GET,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        returnBody: true,
      );
      debugPrint(
          '[SuperadminDashboardPage] _loadDashboardData response status=${response.statusCode} body=${response.bodyText}');

      final decoded = response.jsonBody as Map<String, dynamic>?;
      if (decoded == null) {
        throw Exception('Invalid dashboard response');
      }

      if (decoded['status'] == 'success' || decoded['data'] != null) {
        setState(() => _dashboardData = decoded['data'] ?? decoded);
      } else {
        throw Exception(decoded['message'] ?? 'Failed to load dashboard');
      }

      try {
        final analytics = await AdminApiService.getAnalytics();
        final analyticsData = analytics['data'] is Map
            ? Map<String, dynamic>.from(analytics['data'] as Map)
            : analytics;
        final rawSeries = analyticsData['revenue_series'];
        final series = rawSeries is List
            ? rawSeries
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .where((item) => item['value'] != null)
                .toList()
            : <Map<String, dynamic>>[];
        if (mounted) setState(() => _revenueSeries = series);
      } catch (error) {
        debugPrint(
            '[SuperadminDashboardPage] Revenue analytics load failed: $error');
        if (mounted) setState(() => _revenueSeries = <Map<String, dynamic>>[]);
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadDashboardData failed: $e');
      debugPrint(st.toString());
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
      // Refresh superadmin wallet info when dashboard refresh completes
      _loadSuperadminWallet();
    }
  }

  Widget _wrapWithWillPop(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (kIsWeb) {
          Navigator.of(context).maybePop();
          return;
        }
        try {
          await SystemNavigator.pop();
        } catch (_) {}
      },
      child: child,
    );
  }

  Future<void> _logout() async {
    debugPrint('[SuperadminDashboardPage] _logout called');
    try {
      await AuthService().logout();
    } catch (e) {
      debugPrint('[SuperadminDashboardPage] logout error: $e');
    }
    if (mounted) {
      await AppLocaleService.resetToEnglish(context);
      AuthNavigation.replaceAllWithBuilder(
        context,
        (_) => LoginpageWidget(),
      );
    }
  }

  Future<void> _loadExchangeRates() async {
    setState(() {
      _loadingExchangeRates = true;
    });
    try {
      final token = await AdminApiService.getValidAccessToken();
      debugPrint(
          '[SuperadminDashboardPage] _loadExchangeRates token length=${token.length}');
      if (token.isEmpty) throw Exception('Not authenticated');

      debugPrint(
          '[SuperadminDashboardPage] _loadExchangeRates calling ${AppConfig.api}/admin/exchange-rates');
      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminExchangeRates',
        apiUrl: '${AppConfig.api}/admin/exchange-rates',
        callType: ApiCallType.GET,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        returnBody: true,
      );

      final decoded = response.jsonBody as Map<String, dynamic>?;
      if (decoded == null) throw Exception('Invalid exchange rate response');
      final rates = decoded['data'] as List<dynamic>? ?? [];

      String kesFarm = '1';
      String farmKes = '1';
      for (final item in rates) {
        final base = item['base_currency']?.toString().toUpperCase();
        final target = item['target_currency']?.toString().toUpperCase();
        final rate = item['rate']?.toString() ?? '';
        if (base == 'KES' && target == 'FARM') {
          kesFarm = rate;
        }
        if (base == 'FARM' && target == 'KES') {
          farmKes = rate;
        }
      }

      if (mounted) {
        _kesToFarmCtrl.text = kesFarm;
        _farmToKesCtrl.text = farmKes;
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadExchangeRates failed: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to load exchange rates: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _loadingExchangeRates = false;
        });
    }
  }

  Future<void> _saveExchangeRates() async {
    if (_kesToFarmCtrl.text.isEmpty || _farmToKesCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill both KES→FARM and FARM→KES rates')),
      );
      return;
    }

    setState(() {
      _savingExchangeRates = true;
    });
    try {
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) throw Exception('Not authenticated');

      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminUpdateExchangeRates',
        apiUrl: '${AppConfig.api}/admin/exchange-rates',
        callType: ApiCallType.PUT,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        body: convert.jsonEncode({
          'rates': [
            {
              'base_currency': 'KES',
              'target_currency': 'FARM',
              'rate': double.parse(_kesToFarmCtrl.text.trim()),
            },
            {
              'base_currency': 'FARM',
              'target_currency': 'KES',
              'rate': double.parse(_farmToKesCtrl.text.trim()),
            },
          ],
        }),
        bodyType: BodyType.JSON,
        returnBody: true,
      );

      final decoded = response.jsonBody as Map<String, dynamic>?;
      final message = decoded?['message'] ?? 'Exchange rates updated';
      if (!response.succeeded) throw Exception(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
      await _loadExchangeRates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error saving exchange rates: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted)
        setState(() {
          _savingExchangeRates = false;
        });
    }
  }

  Future<void> _openSystemUsersPage() async {
    if (!mounted) return;
    await _openAdminPage(const UserManagementPage());
  }

  Future<void> _openAdminPage(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => Theme(data: AppTheme.lightTheme(), child: page)),
    );
  }

  Widget _buildSystemUsersCard(Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Users',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Open the dedicated users page to manage accounts, roles, and KYC statuses.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ),
              Icon(Icons.people, color: accent),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openSystemUsersPage,
              icon: const Icon(Icons.open_in_new_rounded, color: Colors.black),
              label: Text('Open System Users',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddAdminPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddAdminPage()),
    );
    await _loadDashboardData();
  }

  Future<void> _openAddSuperadminPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddSuperadminPage()),
    );
    await _loadDashboardData();
  }

  Future<void> _openAdminManagementPage() async {
    await _openAdminPage(const AdminManagementPage());
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = const Color(0xFF0B1320);
    final cardColor = const Color(0xFF111B2A);
    const accent = AppTheme.accent;
    final muted = Colors.white70;

    if (_loading) {
      return _wrapWithWillPop(Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      ));
    }

    if (_error != null) {
      return _wrapWithWillPop(Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading dashboard',
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
                onPressed: _loadDashboardData,
                style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,backgroundColor: AppTheme.accent),
                child: Text(
                  'Retry',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.onAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    final data = _dashboardData ?? {};

    return _wrapWithWillPop(Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          edgeOffset: 0,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(accent, muted),
                const SizedBox(height: 28),
                _buildKPICards(data, cardColor, accent),
                const SizedBox(height: 28),
                _buildExchangeRatesSection(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildCurrencyConversionRatesSection(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSuperadminFees(
                    _superadminWallet, cardColor, accent, muted),
                const SizedBox(height: 28),
                RevenueOverviewChart(
                  series: _revenueSeries,
                  cardColor: cardColor,
                  accent: accent,
                ),
                const SizedBox(height: 28),
                _buildKYCEarnings(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSystemHealth(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildMonitoringCards(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildAddAdminSection(data, cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildSystemUsersCard(cardColor, accent, muted),
                const SizedBox(height: 28),
                _buildRecentActivities(data, cardColor, muted),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildHeader(Color accent, Color muted) {
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title column. On small screens show a visible logout button here.
        Expanded(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Superadmin Dashboard',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Monitor all platform activities and metrics',
              style: GoogleFonts.plusJakartaSans(
                color: muted,
                fontSize: 13,
              ),
            ),
            if (isPhone) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: Tooltip(
                      message: 'Logout',
                      child: InkWell(
                        onTap: _logout,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        ),

        // Right-side quick actions (wallet + logout). Shield icon removed.
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Wallet',
                child: InkWell(
                  onTap: () {
                    debugPrint('[SuperadminDashboardPage] wallet icon tapped');
                    context.push(SuperadminWalletPage.routePath);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Keep the logout here for non-phone layouts as well.
            if (!isPhone)
              Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Logout',
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminActivityCard(String title, String value, Color accent,
      Color cardColor, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAdminSection(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Admin',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Create a new admin account and monitor approval activity.',
                    style: GoogleFonts.plusJakartaSans(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildAdminActivityCard(
                  'Pending KYC',
                  '${data['pending_kyc'] ?? 0}',
                  accent,
                  cardColor,
                  () => _openAdminPage(const KycManagementPage())),
              const SizedBox(width: 12),
              _buildAdminActivityCard(
                  'Flagged Tx',
                  '${data['flagged_transactions'] ?? 0}',
                  Colors.orange,
                  cardColor,
                  () => _openAdminPage(const TransactionsManagementPage())),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAdminActivityCard(
                  'Open Tickets',
                  '${data['support_tickets'] ?? 0}',
                  Colors.blue,
                  cardColor,
                  () => _openAdminPage(const SupportHelpCenterPageWidget())),
              const SizedBox(width: 12),
              _buildAdminActivityCard(
                  'Disputes',
                  '${data['pending_disputes'] ?? 0}',
                  Colors.red,
                  cardColor,
                  () => _openAdminPage(const EscrowManagementPage())),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openAddSuperadminPage,
              icon: const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.black),
              label: Text(
                'Add Superadmin',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isCreatingAdmin ? null : _openAddAdminPage,
              icon: const Icon(Icons.person_add_alt_1_rounded,
                  color: Colors.black),
              label: Text('Create Admin',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openAdminManagementPage,
              icon: const Icon(Icons.manage_accounts_rounded,
                  color: Colors.black),
              label: Text('Manage Admins',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openSystemUsersPage,
              icon: const Icon(Icons.people_rounded, color: Colors.black),
              label: Text('System Users',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICards(
      Map<String, dynamic> data, Color cardColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Indicators',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            _kpiCard(
                'Total Users',
                '${data['total_users'] ?? 0}',
                'users',
                accent,
                cardColor,
                () => _openAdminPage(const UserManagementPage())),
            _kpiCard(
                'Total Revenue',
                '${formatFarmAmount(data['total_revenue'])} FARM',
                'platform fees',
                accent,
                cardColor,
                () => _openAdminPage(const SuperadminWalletPage())),
            _kpiCard(
                'Active Transactions',
                '${data['active_transactions'] ?? 0}',
                'pending',
                accent,
                cardColor,
                () => _openAdminPage(const TransactionsManagementPage())),
            _kpiCard('System Checks', _checksSummary(data),
                'live checks passing', accent, cardColor, null),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, String subtitle, Color accent,
      Color cardColor, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.trending_up, size: 14, color: accent),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _streamColors = <Color>[
    Color(0xFF4ADE80),
    Color(0xFF60A5FA),
    Color(0xFFC084FC),
    Color(0xFFFB923C),
    Color(0xFF2DD4BF),
    Color(0xFFF472B6),
    Color(0xFFFACC15),
  ];

  Widget _buildKYCEarnings(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    double amount(String key) {
      final value = data[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    int count(String key, [String? fallbackKey]) {
      final value =
          data[key] ?? (fallbackKey == null ? null : data[fallbackKey]);
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final creationEarnings = amount('escrow_creation_earnings');
    final releaseEarnings = amount('escrow_release_earnings');
    final withdrawEarnings = amount('withdraw_fee_earnings');
    final merchantEarnings = amount('merchant_sales_fee_earnings');
    final creationCount = count('escrow_creation_count');
    final releaseCount = count('escrow_release_count');
    final withdrawCount = count('withdraw_transaction_count', 'withdraw_count');
    final merchantSalesCount = count('merchant_sales_count');
    final streams = (data['revenue_streams'] is List)
        ? (data['revenue_streams'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Revenue',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All platform fee sources',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.analytics_rounded,
                      color: accent,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (streams.isNotEmpty) ...[
                for (var i = 0; i < streams.length; i++) ...[
                  _earningsBreakdownCard(
                    '${streams[i]['label'] ?? streams[i]['type']}',
                    '${formatFarmAmount(streams[i]['total'])} FARM',
                    'From ${streams[i]['count'] ?? 0} transactions',
                    _streamColors[i % _streamColors.length],
                    cardColor,
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white24))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Total (${streams.length} streams)',
                            style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                      Text('${formatFarmAmount(data['total_revenue'])} FARM',
                          style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _earningsBreakdownCard(
                      'Creation Fee',
                      '${creationEarnings.toStringAsFixed(2)} FARM',
                      'From $creationCount escrow creations',
                      Colors.green,
                      cardColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _earningsBreakdownCard(
                      'Release Fee',
                      '${releaseEarnings.toStringAsFixed(2)} FARM',
                      'From $releaseCount escrow releases',
                      Colors.blue,
                      cardColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _earningsBreakdownCard(
                'Withdraw Fee',
                '${withdrawEarnings.toStringAsFixed(2)} FARM',
                'From $withdrawCount withdraws',
                Colors.purple,
                cardColor,
              ),
              const SizedBox(height: 12),
              _earningsBreakdownCard(
                'Merchant Revenue',
                '${merchantEarnings.toStringAsFixed(2)} FARM',
                'From $merchantSalesCount merchant sales',
                Colors.orange,
                cardColor,
              ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuperadminFees(Map<String, dynamic>? wallet, Color cardColor,
      Color accent, Color muted) {
    final balance = wallet == null
        ? 0.0
        : (wallet['available_balance'] ?? wallet['balance'] ?? 0.0);
    final displayBalance = (balance is num)
        ? (balance).toDouble()
        : double.tryParse(balance.toString()) ?? 0.0;
    final merchantRevenue = wallet?['merchant_sales_revenue'] is num
        ? (wallet!['merchant_sales_revenue'] as num).toDouble()
        : double.tryParse(
                wallet?['merchant_sales_revenue']?.toString() ?? '') ??
            0.0;
    final merchantSalesCount = wallet?['merchant_sales_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Revenues',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SuperadminWalletPage(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform revenue wallet',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${displayBalance.toStringAsFixed(2)} FARM',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wallet balance. Fee totals by stream are below.',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Merchant revenue: ${merchantRevenue.toStringAsFixed(2)} FARM ($merchantSalesCount sales)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _earningsBreakdownCard(String title, String amount, String description,
      Color colorAccent, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: GoogleFonts.plusJakartaSans(
              color: colorAccent,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _systemChecks(Map<String, dynamic> data) {
    final raw = data['system_checks'];
    final list = raw is Map ? raw['checks'] : raw;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  String _checksSummary(Map<String, dynamic> data) {
    final checks =
        _systemChecks(data).where((c) => c['status'] != 'disabled').toList();
    if (checks.isEmpty) return '—';
    final ok = checks.where((c) => c['status'] == 'ok').length;
    return '$ok/${checks.length}';
  }

  Widget _buildSystemHealth(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    final checks = _systemChecks(data);
    final active = checks.where((c) => c['status'] != 'disabled');
    final hasError = active.any((c) => c['status'] == 'error');
    final hasWarn = active.any((c) => c['status'] == 'degraded');
    final overall = checks.isEmpty
        ? 'Unavailable'
        : hasError
            ? 'Issue'
            : hasWarn
                ? 'Attention'
                : 'Operational';
    final overallColor = checks.isEmpty
        ? Colors.white54
        : hasError
            ? const Color(0xFFF87171)
            : hasWarn
                ? const Color(0xFFFBBF24)
                : const Color(0xFF4ADE80);
    final rawChecked =
        data['system_checks'] is Map ? data['system_checks']['checked_at'] : null;
    final checkedAt = DateTime.tryParse('${rawChecked ?? ''}')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Health',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.15),
                  border: Border.all(color: overallColor.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  overall,
                  style: GoogleFonts.plusJakartaSans(
                    color: overallColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (checkedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Checked ${checkedAt.hour.toString().padLeft(2, '0')}:${checkedAt.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          if (checks.isEmpty)
            Text(
              'Live checks are not available from the server yet.',
              style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
            )
          else
            for (final c in checks) ...[
              _healthItem(
                '${c['name'] ?? ''}',
                '${c['detail'] ?? c['status'] ?? ''}',
                switch ('${c['status']}') {
                  'ok' => const Color(0xFF4ADE80),
                  'degraded' => const Color(0xFFFBBF24),
                  'error' => const Color(0xFFF87171),
                  _ => Colors.white60,
                },
                cardColor,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _healthItem(
      String name, String status, Color statusColor, Color cardColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: GoogleFonts.plusJakartaSans(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExchangeRatesSection(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exchange Rates',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Adjust the KES ⇄ FARM conversion rates used by wallet balance displays and payment calculations.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (_loadingExchangeRates)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildRateField(
                'KES → FARM', _kesToFarmCtrl, 'Example: 1.00', accent),
            const SizedBox(height: 16),
            _buildRateField(
                'FARM → KES', _farmToKesCtrl, 'Example: 1.00', accent),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _savingExchangeRates ? null : _saveExchangeRates,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,backgroundColor: AppTheme.accent),
                  child: Text(
                    _savingExchangeRates ? 'Saving...' : 'Save Rates',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Changes here are reflected in user wallet balance interfaces and deposit/withdraw conversion calculations.',
                    style:
                        GoogleFonts.plusJakartaSans(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadCurrencyRate() async {
    setState(() => _loadingCurrencyRate = true);
    try {
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) throw Exception('Not authenticated');

      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminCurrencyRate',
        apiUrl: '${AppConfig.api}/admin/currency-rates/current',
        callType: ApiCallType.GET,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        returnBody: true,
      );

      final decoded = response.jsonBody as Map<String, dynamic>?;
      final raw = decoded?['data'];
      final current = raw is Map
          ? Map<String, dynamic>.from(raw)
          : (raw is List && raw.isNotEmpty && raw.first is Map)
              ? Map<String, dynamic>.from(raw.first as Map)
              : null;
      if (current == null) return;
      final usdKes =
          double.tryParse('${current['usd_kes_rate'] ?? ''}') ?? 0;
      if (usdKes <= 0) return;
      final farmUsd = double.tryParse('${current['farm_usd_rate'] ?? ''}') ??
          (1 / usdKes);
      if (mounted) {
        setState(() {
          _usdToKesCtrl.text = usdKes.toStringAsFixed(2);
          _farmToUsdCtrl.text = farmUsd.toStringAsFixed(6);
          _rateSource = current['source']?.toString();
          _rateOverride = current['is_override'] == true;
          _rateLiveEnabled = current['live_enabled'] == true;
          _rateStale = current['stale'] == true;
          _rateUpdatedAt = DateTime.tryParse(
                  '${current['updated_at'] ?? current['effective_at'] ?? ''}')
              ?.toLocal();
        });
      }
    } catch (e, st) {
      debugPrint('[SuperadminDashboardPage] _loadCurrencyRate failed: $e');
      debugPrint(st.toString());
    } finally {
      if (mounted) setState(() => _loadingCurrencyRate = false);
    }
  }

  Future<void> _saveCurrencyRate() async {
    if (_usdToKesCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide the USD/KES rate')),
      );
      return;
    }

    setState(() => _savingCurrencyRate = true);
    try {
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) throw Exception('Not authenticated');

      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminUpdateCurrencyRate',
        apiUrl: '${AppConfig.api}/admin/currency-rates',
        callType: ApiCallType.PUT,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: convert.jsonEncode({
          'usd_kes_rate': double.parse(_usdToKesCtrl.text.trim()),
        }),
        bodyType: BodyType.JSON,
        returnBody: true,
      );

      final decoded = response.jsonBody as Map<String, dynamic>?;
      final message = decoded?['message'] ?? 'Conversion rate updated';
      if (!response.succeeded) throw Exception(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      }
      await _loadCurrencyRate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error saving conversion rate: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCurrencyRate = false);
    }
  }

  Future<void> _useLiveRate() async {
    setState(() => _clearingOverride = true);
    try {
      final token = await AdminApiService.getValidAccessToken();
      if (token.isEmpty) throw Exception('Not authenticated');
      final response = await ApiManager.instance.makeApiCall(
        callName: 'superadminClearRateOverride',
        apiUrl: '${AppConfig.api}/admin/currency-rates/override',
        callType: ApiCallType.DELETE,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        params: {},
        returnBody: true,
      );
      if (!response.succeeded) {
        throw Exception(
            (response.jsonBody as Map?)?['message'] ?? 'Could not switch to live');
      }
      await _loadCurrencyRate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _clearingOverride = false);
    }
  }

  String _rateStatusText() {
    final at = _rateUpdatedAt;
    final when = at == null
        ? 'unknown time'
        : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} '
            '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    if (_rateOverride) return 'Manual override · set $when';
    if (_rateSource == 'live') {
      return _rateStale
          ? 'Live feed unavailable · last live rate $when'
          : 'Live market rate · updated $when';
    }
    if (_rateLiveEnabled) return 'Live feed pending · last set $when';
    return 'Manual rate · set $when';
  }

  Widget _buildCurrencyConversionRatesSection(
      Color cardColor, Color accent, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency Conversion Rates',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'USD/KES comes from the live market feed. Saving a value sets a manual override.',
            style: GoogleFonts.plusJakartaSans(color: muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _rateOverride
                    ? Icons.edit_note_rounded
                    : (_rateSource == 'live' && !_rateStale)
                        ? Icons.wifi_tethering_rounded
                        : Icons.schedule_rounded,
                size: 16,
                color: (_rateSource == 'live' && !_rateStale && !_rateOverride)
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFBBF24),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _rateStatusText(),
                  key: const ValueKey('superadmin-rate-status'),
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingCurrencyRate)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildRateField(
                'USD → KES', _usdToKesCtrl, 'Example: 150.00', accent),
            const SizedBox(height: 16),
            _buildRateField(
                'FARM → USD (derived)', _farmToUsdCtrl, 'Auto-derived', accent),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _savingCurrencyRate ? null : _saveCurrencyRate,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,backgroundColor: AppTheme.accent),
                  child: Text(
                    _savingCurrencyRate ? 'Saving...' : 'Save manual override',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_rateOverride && _rateLiveEnabled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _clearingOverride ? null : _useLiveRate,
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: Text(_clearingOverride ? 'Switching...' : 'Use live rate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '1 FARM = 1 KES. 1 FARM = 1 ÷ (USD/KES) USD; USDC and USDT use the same value.',
                  style: GoogleFonts.plusJakartaSans(
                      color: muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRateField(String label, TextEditingController controller,
      String hint, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.plusJakartaSans(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.white30),
            filled: true,
            fillColor: const Color(0xFF0A121F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringCards(
      Map<String, dynamic> data, Color cardColor, Color accent, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Platform Monitoring',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        _monitoringCard(
            'Pending KYC Reviews',
            '${data['pending_kyc'] ?? 0}',
            accent,
            cardColor,
            Icons.verified_user,
            () => _openAdminPage(const KycManagementPage())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Flagged Transactions',
            '${data['flagged_transactions'] ?? 0}',
            accent,
            cardColor,
            Icons.warning_rounded,
            () => _openAdminPage(const TransactionsManagementPage())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Support Tickets',
            '${data['support_tickets'] ?? 0}',
            accent,
            cardColor,
            Icons.support_agent,
            () => _openAdminPage(const SupportHelpCenterPageWidget())),
        const SizedBox(height: 12),
        _monitoringCard(
            'Pending Disputes',
            '${data['pending_disputes'] ?? 0}',
            accent,
            cardColor,
            Icons.gavel_rounded,
            () => _openAdminPage(const EscrowManagementPage())),
      ],
    );
  }

  Widget _monitoringCard(String title, String count, Color accent,
      Color cardColor, IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count,
                style: GoogleFonts.plusJakartaSans(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities(
      Map<String, dynamic> data, Color cardColor, Color muted) {
    final activities = data['recent_activities'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activities',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: activities.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No recent activities',
                      style: GoogleFonts.plusJakartaSans(
                        color: muted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: (activities.length > 5 ? 5 : activities.length),
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final activity = activities[index] as Map<String, dynamic>?;
                    return InkWell(
                      onTap: activity == null
                          ? null
                          : () => TransactionReceiptService.showDetails(
                              context, Map<String, dynamic>.from(activity)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activity?['description'] ?? 'Activity',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    activity?['timestamp'] ?? '',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activity?['type'] ?? '',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
