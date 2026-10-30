import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/api_requests/business_api_service.dart';
import '/services/account_context.dart';
import 'business_ui.dart';
import 'business_onboarding_page.dart';

/// KYB status screen: Draft / Under Review / More Information Required /
/// Approved / Rejected, plus the review history. Read-only; decisions are
/// made by admins on the backend.
class BusinessStatusPage extends StatefulWidget {
  const BusinessStatusPage({super.key});

  static String routeName = 'BusinessStatus';
  static String routePath = '/business/status';

  @override
  State<BusinessStatusPage> createState() => _BusinessStatusPageState();
}

class _BusinessStatusPageState extends State<BusinessStatusPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _b;

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
        _b = data['business'] is Map
            ? Map<String, dynamic>.from(data['business'])
            : null;
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

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        foregroundColor: theme.primaryText,
        elevation: 0,
        title: const Text('Verification status'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [_body(context)],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return BizMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load status',
        message: _error!,
        action: _load,
        actionLabel: 'Retry',
      );
    }
    final b = _b;
    if (b == null) {
      return BizMessage(
        icon: Icons.business_center_outlined,
        title: 'No business application yet',
        message: 'Start the upgrade from the Business tab on your dashboard.',
        action: () => context.safePop(),
        actionLabel: 'Back',
      );
    }
    final status = b['status']?.toString();
    final notes = b['review_notes']?.toString();
    final history = (b['verifications'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BizCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon(status), size: 40, color: fgColor(context)),
              const SizedBox(height: 12),
              BusinessStatusBadge(status: status),
              const SizedBox(height: 12),
              Text(
                _headline(status),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: fgColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _explain(status),
                style: TextStyle(color: mutedColor(context), height: 1.5),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Reviewer note',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: fgColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: TextStyle(color: fgColor(context), height: 1.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (BusinessStatus.editable.contains(status))
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () =>
                context.pushReplacementNamed(BusinessOnboardingPage.routeName),
            child: Text(
              status == BusinessStatus.draft
                  ? 'Continue application'
                  : 'Update and resubmit',
            ),
          ),
        if (status == BusinessStatus.approved)
          ElevatedButton(
            style: primaryButtonStyle(context),
            onPressed: () async {
              await AccountContext.instance.setMode(AccountMode.business);
              if (context.mounted) context.goNamed('Dashboard');
            },
            child: const Text('Switch to Business account'),
          ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'History',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: fgColor(context),
            ),
          ),
          const SizedBox(height: 8),
          for (final h in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BizCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Submitted ${_date(h['submitted_at'])}'
                        '${h['reviewed_at'] != null ? '\nDecided ${_date(h['reviewed_at'])}' : ''}',
                        style: TextStyle(
                          color: mutedColor(context),
                          height: 1.5,
                        ),
                      ),
                    ),
                    BusinessStatusBadge(status: h['status']?.toString()),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _date(dynamic v) {
    final d = DateTime.tryParse(v?.toString() ?? '');
    return d == null ? '' : DateFormat('d MMM yyyy, HH:mm').format(d.toLocal());
  }

  IconData _icon(String? s) {
    switch (s) {
      case BusinessStatus.underReview:
        return Icons.hourglass_top_rounded;
      case BusinessStatus.moreInfo:
        return Icons.info_outline_rounded;
      case BusinessStatus.approved:
        return Icons.verified_outlined;
      case BusinessStatus.rejected:
        return Icons.block_outlined;
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _headline(String? s) {
    switch (s) {
      case BusinessStatus.underReview:
        return 'We are reviewing your business';
      case BusinessStatus.moreInfo:
        return 'More information needed';
      case BusinessStatus.approved:
        return 'Business account activated';
      case BusinessStatus.rejected:
        return 'Application not approved';
      default:
        return 'Application in progress';
    }
  }

  String _explain(String? s) {
    switch (s) {
      case BusinessStatus.underReview:
        return 'Our compliance team is checking your details and documents. You will get a notification when a decision is made.';
      case BusinessStatus.moreInfo:
        return 'Please update your application with the requested information and submit it again.';
      case BusinessStatus.approved:
        return 'You can now switch to your Business account at any time without logging out.';
      case BusinessStatus.rejected:
        return 'You can update your details and submit a new application.';
      default:
        return 'Your application has not been submitted yet.';
    }
  }
}
