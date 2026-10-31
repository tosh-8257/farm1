import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/biometric_lock_service.dart';
import '/services/auth/route_guard_service.dart';
import '/admin/pages/admin_shell.dart';
import '/admin/core/admin_navigation.dart';
import '/pages/dashboard/dashboard_widget.dart';
import '/pages/loginpage/loginpage_widget.dart';
import '/utils/user_error_message.dart';

class BiometricUnlockPageWidget extends StatefulWidget {
  const BiometricUnlockPageWidget({super.key, this.returnPath});

  final String? returnPath;

  static String routeName = 'biometric_unlock_page';
  static String routePath = '/biometricUnlock';

  @override
  State<BiometricUnlockPageWidget> createState() => _BiometricUnlockPageWidgetState();
}

class _BiometricUnlockPageWidgetState extends State<BiometricUnlockPageWidget> {
  bool isLoading = true;
  String statusMessage = 'Checking biometric session...';
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptUnlock();
    });
  }

  Future<void> _attemptUnlock() async {
    setState(() {
      isLoading = true;
      statusMessage = 'Unlocking with biometrics...';
      errorMessage = null;
    });

    try {
      final biometricLockService = BiometricLockService();
      final isAuthenticated = await RouteGuardService().isUserAuthenticated();
      if (!isAuthenticated) {
        _navigateToLogin();
        return;
      }

      final shouldLock = await biometricLockService.shouldRequireUnlock();
      if (!shouldLock) {
        _navigateToDestination();
        return;
      }

      final unlocked = await biometricLockService.authenticateAndMarkVerified(
        localizedReason:
            'Confirm your identity to unlock your FARM session.',
      );

      if (!unlocked) {
        throw Exception('Biometric verification failed.');
      }

      _navigateToDestination();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = userErrorMessage(e);
        statusMessage = 'Unable to unlock with biometrics.';
      });
    }
  }

  void _navigateToDestination() {
    if (!mounted) return;
    if (FFAppState().isAdmin) {
      AuthNavigation.replaceAllWithBuilder(
        context,
        (_) => const AdminShell(),
      );
      return;
    }
    final destination = widget.returnPath ?? DashboardWidget.routePath;
    GoRouter.of(context).go(destination == BiometricUnlockPageWidget.routePath
        ? DashboardWidget.routePath
        : destination);
  }

  void _navigateToLogin() {
    if (!mounted) return;
    GoRouter.of(context).go(LoginpageWidget.routePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24.0),
              Icon(
                Icons.fingerprint,
                size: 96,
                color: FlutterFlowTheme.of(context).primary,
              ),
              const SizedBox(height: 24.0),
              Text(
                'Unlock with biometrics',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context)
                    .titleLarge
                    .override(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12.0),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
              const SizedBox(height: 24.0),
              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context)
                      .bodyMedium
                      .override(color: Colors.red),
                ),
                const SizedBox(height: 24.0),
              ],
              if (isLoading)
                Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              else ...[
                ElevatedButton(
                  onPressed: _attemptUnlock,
                  style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  child: Text('common.retry'.tr()),
                ),
                const SizedBox(height: 12.0),
                TextButton(
                  onPressed: _navigateToLogin,
                  child: Text('common.use_password'.tr()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
