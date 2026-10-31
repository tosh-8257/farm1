import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/theme_extensions.dart';
import '../core/admin_guard.dart';
import '../core/admin_navigation.dart';
import '../services/admin_api_service.dart';
import '/services/auth/auth_service.dart';
import '/core/localization/app_locale_service.dart';
import '/pages/loginpage/loginpage_widget.dart';
import 'deposits_management_page.dart';
import 'escrow_management_page.dart';
import 'notifications_management_page.dart';
import 'user_management_page.dart';
import 'withdrawals_management_page.dart';
import 'kyc_management_page.dart';
import 'payouts_page.dart';
import '/services/transaction_receipt_service.dart';
import '/utils/user_error_message.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const AdminDashboardPage({super.key, this.onGoBack});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic> _stats = <String, dynamic>{};
  bool _loading = true;
  String? _error;
  String _adminName = 'Admin';
  String _adminRole = 'admin';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    debugPrint('Loading admin profile...');
    try {
      _adminName = await AdminGuard.getAdminName();
      _adminRole = await AdminGuard.getAdminRole();
      debugPrint('Current admin = $_adminName');
      debugPrint('Permissions = $_adminRole');
    } catch (e) {
      debugPrint('Admin profile load failed: $e');
      _adminName = 'Admin';
      _adminRole = 'admin';
    }

    debugPrint('Loading dashboard statistics...');
    try {
      final result = await AdminApiService.getDashboardStats();
      final normalized = _normalizeDashboardPayload(result);
      if (normalized.isEmpty) {
        throw Exception('Dashboard payload was empty or malformed.');
      }
      if (!mounted) return;
      setState(() {
        _stats = normalized;
      });
      debugPrint('Dashboard statistics loaded.');
      debugPrint('Stats payload = $_stats');
    } catch (e) {
      debugPrint('Dashboard statistics load failed: $e');
      if (mounted) {
        setState(() => _error = userErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic> _normalizeDashboardPayload(dynamic payload) {
    if (payload is! Map<String, dynamic> && payload is! Map) {
      debugPrint('Dashboard payload was not a map: ${payload.runtimeType}');
      return <String, dynamic>{};
    }

    final root = payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map<dynamic, dynamic>);
    final maybeData = root['data'];
    if (maybeData is Map<String, dynamic>) {
      return maybeData;
    }
    if (maybeData is Map) {
      return Map<String, dynamic>.from(maybeData);
    }

    debugPrint('Dashboard payload did not contain a usable data map.');
    return <String, dynamic>{};
  }

  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(data: AppTheme.lightTheme(), child: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading dashboard data...',
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _stats.isEmpty) {
      return _errorView(_error ?? 'Unable to load dashboard data.');
    }

    final s = _stats;
    final bgColor = Colors.white;
    final cardColor = Colors.white;
    final accent = AppTheme.accentOn(bgColor);
    final muted = context.onSurface.withOpacity(0.7);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          edgeOffset: 0,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(accent, muted),
                const SizedBox(height: 24),
                _buildOverviewRow(s, cardColor, accent),
                const SizedBox(height: 24),
                _buildQuickActions(cardColor, accent),
                const SizedBox(height: 24),
                _buildTransactionsSection(cardColor, muted),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent, Color muted) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withAlpha((0.16 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('FARM',
                    style: GoogleFonts.plusJakartaSans(
                        color: accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 14),
              Text('Admin Dashboard',
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Signed in as $_adminName ($_adminRole)',
                style: GoogleFonts.plusJakartaSans(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A unified admin control panel for users, deposits, withdrawals, and compliance.',
                style: GoogleFonts.plusJakartaSans(
                    color: muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () async {
                try {
                  await AuthService().logout();
                } catch (_) {}
                if (!mounted) return;
                await AppLocaleService.resetToEnglish(context);
                AuthNavigation.replaceAllWithBuilder(
                  context,
                  (_) => LoginpageWidget(),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Logout',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 22,
              backgroundColor: context.onSurface,
              child: Text('AD',
                  style: GoogleFonts.plusJakartaSans(
                      color: context.background,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewRow(
      Map<String, dynamic> s, Color cardColor, Color accent) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        final cardAspectRatio = isNarrow
            ? 1.1
            : constraints.maxWidth < 700
                ? 1.35
                : 1.55;

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: cardAspectRatio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _metricCard(
                'Total Users',
                '${s['total_users'] ?? 0}',
                'Active people',
                cardColor,
                accent,
                () => _navigateTo(const UserManagementPage()),
                isNarrow: isNarrow),
            _metricCard(
                'Active Escrows',
                '${s['active_escrows'] ?? 0}',
                'Escrow flows',
                cardColor,
                accent,
                () => _navigateTo(const EscrowManagementPage()),
                isNarrow: isNarrow),
            _metricCard(
                'Pending KYC',
                '${s['pending_kyc'] ?? 0}',
                'Review queue',
                cardColor,
                accent,
                () => _navigateTo(const KycManagementPage()),
                isNarrow: isNarrow),
            _metricCard(
                'Pending Payouts',
                '${s['pending_payouts'] ?? 0}',
                'Awaiting settlement',
                cardColor,
                accent,
                () => _navigateTo(const PayoutsPage()),
                isNarrow: isNarrow),
          ],
        );
      },
    );
  }

  Widget _metricCard(String title, String value, String caption,
      Color cardColor, Color accent, VoidCallback onTap,
      {required bool isNarrow}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.all(isNarrow ? 12 : 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.onSurface.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                  color: context.background.withAlpha((0.18 * 255).round()),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.onSurface.withOpacity(0.7),
                          fontSize: isNarrow ? 13 : 15,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isNarrow ? 5 : 8),
                    decoration: BoxDecoration(
                      color: accent.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(isNarrow ? 10 : 14),
                    ),
                    child: Icon(Icons.trending_up_rounded,
                        size: isNarrow ? 15 : 18, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(value,
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontSize: isNarrow ? 26 : 30,
                      height: 1.05,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface.withOpacity(0.54),
                      fontSize: isNarrow ? 12 : 14,
                      height: 1.15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(Color cardColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Actions',
                style: GoogleFonts.plusJakartaSans(
                    color: context.onSurface,
                    fontSize: 21,
                    fontWeight: FontWeight.w800)),
            Text('Manage the platform',
                style: GoogleFonts.plusJakartaSans(
                    color: context.onSurface.withOpacity(0.54),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _actionChip('Manage Users', Icons.manage_accounts_rounded, accent,
                cardColor, () => _navigateTo(const UserManagementPage())),
            _actionChip(
                'Review Deposits',
                Icons.account_balance_rounded,
                accent,
                cardColor,
                () => _navigateTo(const DepositsManagementPage())),
            _actionChip('Withdrawals', Icons.outbox_rounded, accent, cardColor,
                () => _navigateTo(const WithdrawalsManagementPage())),
            _actionChip('Escrows', Icons.verified_user_rounded, accent,
                cardColor, () => _navigateTo(const EscrowManagementPage())),
            _actionChip(
                'Notifications',
                Icons.campaign_rounded,
                accent,
                cardColor,
                () => _navigateTo(const NotificationsManagementPage())),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(Color cardColor, Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity',
            style: GoogleFonts.plusJakartaSans(
                color: context.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.onSurface.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _recentTransactions(),
          ),
        ),
      ],
    );
  }

  Widget _actionChip(String label, IconData icon, Color accent, Color cardColor,
      VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.onSurface.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withAlpha((0.16 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentTransactions() => FutureBuilder<Map<String, dynamic>>(
        future: AdminApiService.getTransactions(page: 1),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final list = (snap.data?['data'] as List? ?? []).take(5).toList();
          return list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No transactions yet')))
              : Column(
                  children: list.map((t) {
                    final isCredit = ['deposit', 'escrow_release', 'roi_payout']
                        .contains(t['transaction_type']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: context.onSurface.withOpacity(0.1)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        onTap: () => TransactionReceiptService.showDetails(
                          context,
                          t,
                          fetchLatest: true,
                          detailsLoader: AdminApiService.getTransactionDetails,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCredit
                                ? context.successColor
                                    .withAlpha((0.16 * 255).round())
                                : context.errorColor
                                    .withAlpha((0.16 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            color: isCredit
                                ? context.successColor
                                : context.errorColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          (t['transaction_type'] ?? '')
                              .toString()
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                              color: context.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        subtitle: Text(t['transaction_reference'] ?? '',
                            style: GoogleFonts.plusJakartaSans(
                                color: context.onSurface.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        trailing: Text(
                          '${isCredit ? '+' : '-'}${_fmt(t['amount'] ?? 0)} FARM',
                          style: GoogleFonts.plusJakartaSans(
                            color: isCredit
                                ? context.successColor
                                : context.errorColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
        },
      );

  Widget _errorView(String msg) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.errorColor),
                const SizedBox(height: 12),
                Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: context.onSurface),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );

  String _fmt(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(2);
  }
}
