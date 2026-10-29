import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

class KycRequiredWidget extends StatefulWidget {
  final String feature;
  final VoidCallback? onKycApproved;
  const KycRequiredWidget({
    super.key,
    required this.feature,
    this.onKycApproved,
  });

  @override
  State<KycRequiredWidget> createState() => _KycRequiredWidgetState();
}

class _KycRequiredWidgetState extends State<KycRequiredWidget>
    with WidgetsBindingObserver {
  Timer? _statusRefreshTimer;
  bool _refreshingStatus = false;

  String get _kycStatus => FFAppState().kycStatus
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');
  bool get _isApproved =>
      {'verified', 'approved', 'complete', 'success'}.contains(_kycStatus);
  bool get _isPending =>
      {'pending', 'under_review', 'review'}.contains(_kycStatus);
  bool get _isRejected => _kycStatus == 'rejected';
  bool get _needsMoreInfo =>
      _isRejected || _kycStatus == 'additional_info_required';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FFAppState().addListener(_handleAppStateChanged);
    _refreshKycStatus();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshKycStatus(),
    );
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    FFAppState().removeListener(_handleAppStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshKycStatus();
  }

  void _handleAppStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshKycStatus() async {
    if (_refreshingStatus) return;
    _refreshingStatus = true;
    try {
      final response = await ApiService.getProfile(timeoutSeconds: 10);
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final serverStatus = data['kyc_status'] ?? data['kycStatus'];
      if (serverStatus is String && serverStatus.trim().isNotEmpty) {
        final wasApproved = _isApproved;
        FFAppState().kycStatus = serverStatus;
        if (!wasApproved &&
            {
              'verified',
              'approved',
              'complete',
              'success',
            }.contains(serverStatus.trim().toLowerCase()) &&
            mounted) {
          widget.onKycApproved?.call();
        }
      }
    } catch (error) {
      debugPrint('KYC status refresh failed: $error');
    } finally {
      _refreshingStatus = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = isDarkMode ? Colors.black : Colors.white;
    final buttonTextColor = isDarkMode ? Colors.white : Colors.black;
    final title = _isApproved
        ? 'KYC approved'
        : _isPending
        ? 'KYC verification pending'
        : _needsMoreInfo
        ? 'KYC required'
        : 'common.kyc_title'.tr();
    final message = _isApproved
        ? 'Your identity is approved. Reopen this page to continue.'
        : _isPending
        ? 'Your KYC verification is processing or under review. ${widget.feature} will unlock when FARM receives the signed verification result.'
        : _needsMoreInfo
        ? 'KYC is required before using ${widget.feature}. '
              '${_isRejected ? 'Your last submission was not approved. ' : ''}'
              'Update and resubmit your details for admin approval.'
        : '${'common.kyc_required'.tr()} ${widget.feature}. ${'common.kyc_complete_prompt'.tr()}';
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 60, color: theme.primary),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: ElevatedButton(
                onPressed: _isApproved
                    ? () => Navigator.of(context).maybePop()
                    : () => context.pushNamed(
                        'KYCPAGE',
                        queryParameters: _isPending
                            ? const {}
                            : const {'startDidit': 'true'},
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonTextColor,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  (_isPending
                          ? 'View submitted details'
                          : _isRejected
                          ? 'Resubmit KYC'
                          : _needsMoreInfo
                          ? 'Update KYC details'
                          : _isApproved
                          ? 'Return'
                          : 'common.complete_kyc'.tr())
                      .toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: buttonTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isPending
                  ? 'Your status will update after FARM receives the verification result.'
                  : 'common.kyc_review_notice'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
