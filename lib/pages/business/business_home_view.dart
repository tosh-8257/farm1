import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/api_requests/business_api_service.dart';
import '/components/account_switcher/account_switcher_widget.dart';
import '/pages/merchant_dashboard/merchant_dashboard_widget.dart';
import 'business_ui.dart';
import 'business_onboarding_page.dart';
import 'business_status_page.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
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
        if (status == BusinessStatus.approved)
          BizCard(
            child: Text(
              'Your business account is active. Business payments, invoices, '
              'payouts, team and analytics will appear here as they are enabled.',
              style: TextStyle(color: mutedColor(context), height: 1.5),
            ),
          ),
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
            'Use FARM for your business with the same login. Submit your business details for verification (KYB). Approval is done by our team and is not automatic.',
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
