import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/api_requests/business_api_service.dart';
import '/components/account_switcher/account_switcher_widget.dart';
import '/pages/merchant_dashboard/merchant_dashboard_widget.dart';
import 'business_onboarding_page.dart';
import 'business_status_page.dart';
import '/backend/api_requests/business_ops_api.dart';
import '/services/offline_cache.dart';
import 'ops/business_hub.dart';
import 'ops/ops_ui.dart';
import 'ops/team_pages.dart';

/// What the dashboard shows while the Business account is selected.
/// Phase 1 only shows the KYB state; balances and business tools arrive in
/// Phase 2 and are never faked here.
class BusinessHomeView extends StatefulWidget {
  const BusinessHomeView({super.key});

  @override
  State<BusinessHomeView> createState() => _BusinessHomeViewState();
}

class _BusinessHomeViewState extends State<BusinessHomeView> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _business;
  Map<String, dynamic> _eligibility = const {};
  bool _starting = false;
  Map<String, dynamic>? _opsContext;

  @override
  void initState() {
    super.initState();
    final cached = OfflineCache.read('biz:context');
    if (cached is Map && cached['business_id'] != null) {
      _opsContext = Map<String, dynamic>.from(cached);
      _loading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (mounted && _opsContext == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Approved owners and team members get the operations hub.
      try {
        final ctx = await BusinessOpsApi.context();
        if (!mounted) return;
        if (ctx['business_id'] != null) {
          OfflineCache.write('biz:context', ctx);
          setState(() {
            _opsContext = ctx;
            _loading = false;
          });
          return;
        }
      } catch (_) {
        if (_opsContext == null) _opsContext = null;
      }
      final data = await BusinessApiService.getMine();
      if (!mounted) return;
      setState(() {
        _business = data['business'] is Map
            ? Map<String, dynamic>.from(data['business'])
            : null;
        _eligibility = data['eligibility'] is Map
            ? Map<String, dynamic>.from(data['eligibility'])
            : const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _startUpgrade() async {
    setState(() => _starting = true);
    try {
      await BusinessApiService.upgrade();
      if (!mounted) return;
      await context.pushNamed(BusinessOnboardingPage.routeName);
      if (mounted) _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, top + 16, 24, 120),
        children: [
          Text(
            'Business',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: fgColor(context),
            ),
          ),
          const SizedBox(height: 16),
          const AccountSwitcherWidget(),
          const SizedBox(height: 24),
          _body(context),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return BizMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your business',
        message: _error!,
        action: _load,
        actionLabel: 'Retry',
      );
    }
    if (_opsContext != null) return BusinessHub(context: _opsContext!);
    final b = _business;
    if (b == null) return _noBusiness(context);

    final status = b['status']?.toString();
    final name = (b['trading_name'] ?? b['legal_name'] ?? 'Your business')
        .toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BizCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: fgColor(context),
                      ),
                    ),
                  ),
                  BusinessStatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _statusLine(status),
                style: TextStyle(color: mutedColor(context), height: 1.5),
              ),
              const SizedBox(height: 16),
              if (BusinessStatus.editable.contains(status))
                ElevatedButton(
                  style: primaryButtonStyle(context),
                  onPressed: () async {
                    await context.pushNamed(BusinessOnboardingPage.routeName);
                    if (mounted) _load();
                  },
                  child: Text(
                    status == BusinessStatus.draft
                        ? 'Continue application'
                        : 'Update application',
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: secondaryButtonStyle(context),
                onPressed: () async {
                  await context.pushNamed(BusinessStatusPage.routeName);
                  if (mounted) _load();
                },
                child: const Text('View verification status'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (status == BusinessStatus.approved) ...[
          BizCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                'Your business is approved. Open the team to invite people, set roles, and remove access.',
                style: TextStyle(color: mutedColor(context), height: 1.5),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: primaryButtonStyle(context),
                onPressed: () => pushPage(context, const TeamPage()),
                child: const Text('Team'),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  String _statusLine(String? s) {
    switch (s) {
      case BusinessStatus.draft:
        return 'Finish your business details and submit them for verification.';
      case BusinessStatus.underReview:
        return 'Your application is with our compliance team. We will notify you when there is a decision.';
      case BusinessStatus.moreInfo:
        return 'Our team needs more information. Update your application and submit again.';
      case BusinessStatus.rejected:
        return 'Your application was not approved. You can review the reason, update and resubmit.';
      case BusinessStatus.approved:
        return 'Verified business account.';
      default:
        return '';
    }
  }

  Widget _noBusiness(BuildContext context) {
    final reason = _eligibility['reason']?.toString();
    if (_eligibility['can_upgrade'] == true) {
      return BizMessage(
        icon: Icons.business_center_outlined,
        title: 'Upgrade to a Business account',
        message:
            'Use FARM for your business with the same login. Business verification (KYB) is done only with Didit.',
        action: _starting ? null : _startUpgrade,
        actionLabel: _starting ? 'Starting…' : 'Upgrade to Business',
      );
    }
    return BizMessage(
      icon: Icons.storefront_outlined,
      title: 'No business account yet',
      message: reason == 'merchant_not_approved'
          ? 'Your merchant account is still being reviewed. Once it is approved you can upgrade to a Business account.'
          : 'Business accounts start from an approved merchant account. Set up your merchant account first.',
      action: () => context.pushNamed(MerchantDashboardWidget.routeName),
      actionLabel: 'Go to Merchant Portal',
    );
  }
}
