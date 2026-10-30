import 'dart:async';

import 'package:didit_sdk/sdk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/widgets/common/back_chevron.dart';

import 'kycpage_model.dart';
export 'kycpage_model.dart';

/// Verify Your Identity.
///
/// KYC is done exclusively through Didit. The legacy manual form, document
/// uploads and admin-review/rejection card were removed. The status shown here
/// is driven by the user's `kyc_status`, which the backend updates from
/// Didit's signed decisions.
class KycpageWidget extends StatefulWidget {
  const KycpageWidget({super.key, this.startDiditVerification = false});

  static String routeName = 'KYCPAGE';
  static String routePath = '/kycpage';

  /// When true, Didit is launched as soon as the page opens (unless the user
  /// is already verified or a decision is pending).
  final bool startDiditVerification;

  @override
  State<KycpageWidget> createState() => _KycpageWidgetState();
}

enum _KycView { notStarted, pending, approved, declined }

class _KycpageWidgetState extends State<KycpageWidget> {
  late KycpageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isStarting = false;
  bool _isLoadingStatus = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => KycpageModel());
    _refreshStatus().whenComplete(() {
      if (!mounted) return;
      final view = _view;
      if (widget.startDiditVerification &&
          (view == _KycView.notStarted || view == _KycView.declined)) {
        _startDiditVerification();
      }
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshStatus(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _model.dispose();
    super.dispose();
  }

  String get _rawStatus => FFAppState()
      .kycStatus
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  _KycView get _view {
    switch (_rawStatus) {
      case 'verified':
      case 'approved':
        return _KycView.approved;
      case 'rejected':
      case 'declined':
      case 'additional_info_required':
        return _KycView.declined;
      case 'pending':
      case 'under_review':
      case 'in_review':
        return _KycView.pending;
      default:
        return _KycView.notStarted;
    }
  }

  Future<void> _refreshStatus() async {
    try {
      final response = await ApiService.getProfile(timeoutSeconds: 10);
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      final status = data['kyc_status'] ?? data['kycStatus'];
      if (status is String && status.trim().isNotEmpty && mounted) {
        setState(() => FFAppState().kycStatus = status);
      }
    } catch (error) {
      debugPrint('KYC status refresh failed: $error');
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('already verified')) {
      return 'Your identity is already verified.';
    }
    if (lower.contains('session creation') ||
        lower.contains('not configured') ||
        lower.contains('invalid didit session') ||
        lower.contains('incomplete session')) {
      return 'Identity verification is temporarily unavailable. '
          'Please try again in a little while.';
    }
    if (lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('network')) {
      return 'Could not reach FARM. Check your connection and try again.';
    }
    return 'Could not start identity verification. Please try again.';
  }

  Future<void> _startDiditVerification() async {
    if (_isStarting) return;

    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Before you continue'),
        content: const Text(
          'FARM will open Didit, our identity-verification provider. Didit '
          'will process your identity document, selfie, biometric information, '
          'and related verification data for KYC. Continue only if you consent '
          'to this processing. Your verification decision will be confirmed '
          'by FARM after a signed update from Didit; the app result alone is '
          'not proof of approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I consent and continue'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });
    try {
      // POST /api/verify/create-session
      final session = await ApiService.createDiditSession();
      final data = session['data'] is Map<String, dynamic>
          ? session['data'] as Map<String, dynamic>
          : session;
      final sessionToken = data['session_token'];
      final url = data['url'];

      if (sessionToken is String && sessionToken.isNotEmpty) {
        // Native Didit flow (camera/document capture in-app).
        final result = await DiditSdk.startVerification(sessionToken);
        if (!mounted) return;
        if (result is VerificationCancelled) {
          _snack('Verification was cancelled. You can start again any time.');
        } else if (result is VerificationFailed) {
          setState(() => _errorMessage =
              'Verification could not be completed. Please try again.');
        } else if (result is VerificationCompleted) {
          _snack('Verification submitted. Your status will update shortly.');
          if (mounted) setState(() => FFAppState().kycStatus = 'pending');
        }
      } else if (url is String && url.isNotEmpty) {
        // Fallback: open the hosted Didit verification page.
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          throw Exception('Didit session creation failed');
        }
      } else {
        throw const FormatException('invalid Didit session');
      }
      await _refreshStatus();
    } catch (error) {
      debugPrint('Didit session start failed: $error');
      if (mounted) {
        setState(() => _errorMessage = _friendlyError(error));
        if (error.toString().toLowerCase().contains('already verified')) {
          await _refreshStatus();
        }
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    late final IconData icon;
    late final Color color;
    late final String title;
    late final String body;
    switch (_view) {
      case _KycView.approved:
        icon = Icons.verified_rounded;
        color = theme.success;
        title = 'Identity verified';
        body = 'Your identity has been verified. All features are unlocked.';
        break;
      case _KycView.pending:
        icon = Icons.hourglass_top_rounded;
        color = theme.warning;
        title = 'Verification in progress';
        body = 'Didit is reviewing your verification. This page updates '
            'automatically once a decision is received.';
        break;
      case _KycView.declined:
        icon = Icons.error_outline_rounded;
        color = theme.error;
        title = 'Verification declined';
        body = 'Your verification was not approved. Make sure your document '
            'is clear and fully visible, then try again with Didit.';
        break;
      case _KycView.notStarted:
        icon = Icons.verified_user_outlined;
        color = theme.primary;
        title = 'Not verified yet';
        body = 'Verify your identity with Didit in a few minutes using your '
            'ID document and a selfie.';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body, style: theme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context) {
    final view = _view;
    if (view == _KycView.approved) return const SizedBox.shrink();
    final label = switch (view) {
      _KycView.declined => 'Try again with Didit',
      _KycView.pending => 'Restart verification',
      _ => 'Start identity verification',
    };
    final button = view == _KycView.pending
        ? OutlinedButton.icon(
            onPressed: _isStarting ? null : _startDiditVerification,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_isStarting ? 'Opening verification...' : label),
          )
        : ElevatedButton.icon(
            onPressed: _isStarting ? null : _startDiditVerification,
            icon: _isStarting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(_isStarting ? 'Opening verification...' : label),
          );
    return SizedBox(height: 52, child: button);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: theme.primaryBackground,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStatus,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackChevron(),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 32, color: theme.primary),
                    const SizedBox(height: 20),
                    Text(
                      'Verify Your Identity',
                      style: theme.headlineSmall.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                        ),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Complete KYC verification to unlock deposits, '
                      'withdrawals, escrow services, and higher transaction '
                      'limits.',
                      style: theme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingStatus)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _statusCard(context),
                const SizedBox(height: 16),
                _actionButton(context),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.bodySmall.copyWith(color: theme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
