import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/app_theme.dart';
import '/core/theme_extensions.dart';
import 'admin_dashboard_page.dart';
import 'support_inbox_page.dart';
import 'user_management_page.dart';
import 'kyc_management_page.dart';
import 'transactions_management_page.dart';
import 'escrow_management_page.dart';
import 'deposits_management_page.dart';
import 'withdrawals_management_page.dart';
import 'notifications_management_page.dart';
import 'merchant_kyb_management_page.dart';
import 'business_review_page.dart';
import 'payouts_page.dart';
import '../services/admin_api_service.dart';
import '/services/auth/auth_service.dart';
import '/core/localization/app_locale_service.dart';
import '../../pages/loginpage/loginpage_widget.dart';
import '../widgets/admin_sidebar.dart';
import '../core/admin_navigation.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _pageRevision = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_refreshAdminSession(force: true));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startPeriodicRefresh();
      unawaited(_refreshAdminSession(force: true));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      unawaited(_refreshAdminSession());
    });
  }

  Future<void> _refreshAdminSession({bool force = false}) async {
    if (!mounted) return;
    try {
      final token = await AdminApiService.getValidAccessToken(force: force);
      if (token.isNotEmpty && mounted) {
        setState(() {
          _pageRevision += 1;
        });
      }
    } catch (e) {
      debugPrint('[AUTH] Admin refresh unavailable; preserving session: $e');
    }
  }

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.people_rounded, label: 'Users'),
    _NavItem(icon: Icons.verified_user_rounded, label: 'KYC'),
    _NavItem(icon: Icons.swap_horiz_rounded, label: 'Transactions'),
    _NavItem(icon: Icons.security_rounded, label: 'Escrow'),
    _NavItem(icon: Icons.south_west_rounded, label: 'Deposits'),
    _NavItem(icon: Icons.north_east_rounded, label: 'Withdrawals'),
    _NavItem(icon: Icons.payments_rounded, label: 'Payouts'),
    _NavItem(icon: Icons.campaign_rounded, label: 'Notifications'),
    _NavItem(icon: Icons.support_agent_rounded, label: 'Live Support'),
    _NavItem(icon: Icons.badge_rounded, label: 'Merchant KYB'),
    _NavItem(icon: Icons.business_rounded, label: 'Business KYB'),
  ];

  void _goToDashboard() {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
    }
  }

  List<Widget> get _pages => [
        AdminDashboardPage(onGoBack: _goToDashboard),
        UserManagementPage(onGoBack: _goToDashboard),
        KycManagementPage(onGoBack: _goToDashboard),
        TransactionsManagementPage(onGoBack: _goToDashboard),
        EscrowManagementPage(onGoBack: _goToDashboard),
        DepositsManagementPage(onGoBack: _goToDashboard),
        WithdrawalsManagementPage(onGoBack: _goToDashboard),
        PayoutsPage(onGoBack: _goToDashboard),
        NotificationsManagementPage(onGoBack: _goToDashboard),
        SupportInboxPage(onGoBack: _goToDashboard),
        MerchantKybManagementPage(onGoBack: _goToDashboard),
        BusinessReviewPage(onGoBack: _goToDashboard),
      ];

  Widget _buildCurrentPage() {
    final page = _pages[_selectedIndex];
    return KeyedSubtree(
      key: ValueKey('admin-page-$_selectedIndex-$_pageRevision'),
      child: page,
    );
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      await AppLocaleService.resetToEnglish(context);
      AuthNavigation.replaceAllWithBuilder(
        context,
        (_) => LoginpageWidget(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme(),
      child: Builder(
        builder: (adminContext) {
          final isWide = MediaQuery.of(adminContext).size.width > 700;

          return Scaffold(
            backgroundColor: Colors.white,
            drawer: const AdminSidebar(),
            body: Row(
              children: [
                if (isWide) _buildSidebar(adminContext),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(adminContext, isWide),
                      Expanded(child: _buildCurrentPage()),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isWide ? null : _buildBottomNav(adminContext),
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: context.onSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text('FARM',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 8),
                Text('Admin',
                    style: GoogleFonts.plusJakartaSans(
                        color: context.onBackground.withOpacity(0.54),
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (_, i) {
                final item = _navItems[i];
                final selected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.onSurface.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon,
                            color: selected
                                ? context.onSurface
                                : context.onSurface.withOpacity(0.38),
                            size: 20),
                        const SizedBox(width: 12),
                        Text(item.label,
                            style: GoogleFonts.plusJakartaSans(
                              color: selected
                                  ? context.onSurface
                                  : context.onSurface.withOpacity(0.54),
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 14,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.logout_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text('Logout',
                      style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isWide) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isWide)
            Text('FARM Admin',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.onSurface)),
          if (isWide)
            Text(_navItems[_selectedIndex].label,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: context.onSurface)),
          Row(children: [
            Icon(Icons.notifications_none_rounded,
                color: context.onSurface.withOpacity(0.7)),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        size: 16, color: context.onSurface),
                    const SizedBox(width: 6),
                    Text(
                      'Logout',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFF0A0F18), shape: BoxShape.circle),
              child: Center(
                  child: Text('AD',
                      style: TextStyle(
                          color: context.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final selected = i == _selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedIndex = i),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 90,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEAF2FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: selected
                              ? const Color(0xFF0D47A1)
                              : context.onSurface.withOpacity(0.64),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? const Color(0xFF0D47A1)
                                : context.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
