import 'dart:async';

import '/backend/services/api_service.dart';
import '/components/button/button_widget.dart';
import '/components/profile_info_tile/profile_info_tile_widget.dart';
import '/components/settings_action_tile/settings_action_tile_widget.dart';
// removed duplicate import
import '/services/app_session_manager.dart';
import '/services/auth/auth_service.dart';
import '/core/localization/app_locale_service.dart';
import '/services/biometric_lock_service.dart';
import '/pages/settings/delete_account_page.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/core/theme_extensions.dart';
import 'package:flutter/material.dart';
import '/pages/change_pin_page/change_pin_page_widget.dart';
import '/pages/forgot_pin_page/forgot_pin_page_widget.dart';
import '/widgets/common/back_chevron.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_settings_model.dart';
import '/pages/chain_wallet/wallet_address_page.dart';
import '/pages/assistant/assistant_pages.dart';
export 'profile_settings_model.dart';

class ProfileSettingsWidget extends StatefulWidget {
  const ProfileSettingsWidget({super.key});

  static String routeName = 'ProfileSettings';
  static String routePath = '/profileSettings';

  @override
  State<ProfileSettingsWidget> createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget>
    with WidgetsBindingObserver {
  late ProfileSettingsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Map<String, dynamic>? profileData;

  bool isProfileLoading = true;

  String fullName = '';
  String username = '';
  String email = '';
  String phone = '';
  String kycStatus = '';
  String walletAddress = '';
  String profileImage = '';
  String initials = '';

  bool hasPin = false;
  bool biometricsEnabled = false;
  bool securityLoading = true;
  bool accountLocked = false;
  int biometricLockTimeoutSeconds = 600;

  String formatBiometricLockTimeoutLabel(int value) {
    if (value <= 0) return '5 sec';
    if (value == 60) return '1 min';
    if (value < 60) return '$value sec';
    return '${value ~/ 60} min';
  }

  bool get _isKycApproved {
    final status = kycStatus.trim().toLowerCase();
    return {'verified', 'approved', 'complete', 'success'}.contains(status);
  }

  String get _kycStatusLabel {
    if (_isKycApproved) return 'APPROVED';
    final status = kycStatus
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (status.isEmpty || status == 'none') {
      return 'NOT STARTED';
    }
    if ({'pending', 'under_review', 'review'}.contains(status)) {
      return 'PENDING - AWAITING APPROVAL';
    }
    if (status == 'rejected') return 'REJECTED - RESUBMIT KYC';
    if (status == 'additional_info_required') {
      return 'ACTION REQUIRED - UPDATE KYC';
    }
    return kycStatus
        .trim()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _model = createModel(context, () => ProfileSettingsModel());
    FFAppState().addListener(_handleAppStateChanged);
    biometricLockTimeoutSeconds = FFAppState().biometricLockTimeoutSeconds;
    biometricsEnabled = FFAppState().biometricsEnabled;
    hasPin = FFAppState().hasPin;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(fetchProfile());
      unawaited(fetchSecuritySettings());
    });
  }

  @override
  void dispose() {
    FFAppState().removeListener(_handleAppStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _model.dispose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      fetchProfile();
      fetchSecuritySettings();
    }
  }

  void _handleAppStateChanged() {
    if (!mounted) return;
    setState(() {
      fullName = FFAppState().firstName;
      username = FFAppState().userName;
      phone = FFAppState().phone;
      kycStatus = FFAppState().kycStatus;
      profileImage = FFAppState().profileImageUrl;
      biometricsEnabled = FFAppState().biometricsEnabled;
      biometricLockTimeoutSeconds = FFAppState().biometricLockTimeoutSeconds;
      hasPin = FFAppState().hasPin;
      isProfileLoading = false;
    });
  }

  Future<void> fetchProfile() async {
    if (!mounted) return;
    setState(() {
      isProfileLoading = true;
    });

    try {
      await AppSessionManager().syncNow(
        profileTimeoutSeconds: 5,
        walletTimeoutSeconds: 5,
        transactionsTimeoutSeconds: 4,
      );

      if (!mounted) return;

      setState(() {
        profileData = {
          'first_name': FFAppState().firstName,
          'last_name': '',
          'username': FFAppState().userName,
          'email': FFAppState().email,
          'phone': FFAppState().phone,
          'kyc_status': FFAppState().kycStatus,
          'profile_image': FFAppState().profileImageUrl,
        };

        fullName = FFAppState().firstName;
        username = FFAppState().userName;
        phone = FFAppState().phone;
        email = FFAppState().email;
        kycStatus = FFAppState().kycStatus;
        profileImage = FFAppState().profileImageUrl;
        initials = FFAppState().firstName.isNotEmpty
            ? FFAppState().firstName[0].toUpperCase()
            : '';
        hasPin = FFAppState().hasPin;
        isProfileLoading = false;
      });
    } catch (e) {
      print('PROFILE ERROR: $e');

      if (mounted) {
        setState(() {
          isProfileLoading = false;
        });
      }
    }
  }

  Future<void> fetchSecuritySettings() async {
    try {
      final resp =
          await ApiService.request(method: 'GET', path: '/security/settings');
      final data = Map<String, dynamic>.from(resp['data'] ?? resp);
      final resolvedBiometricsEnabled = FFAppState().biometricsEnabled;
      final remoteHasPin = data['has_pin'] ?? false;

      if (FFAppState().biometricsEnabled != resolvedBiometricsEnabled) {
        FFAppState().biometricsEnabled = resolvedBiometricsEnabled;
      }
      if (FFAppState().hasPin != remoteHasPin) {
        FFAppState().hasPin = remoteHasPin;
      }

      setState(() {
        hasPin = remoteHasPin;
        biometricsEnabled = resolvedBiometricsEnabled;
        accountLocked = data['pin_locked'] ?? false;

        securityLoading = false;
      });
    } catch (e) {
      print('SECURITY FETCH ERROR: $e');

      setState(() {
        securityLoading = false;
      });
    }
  }

  Future<void> logoutUser() async {
    try {
      await AuthService().logout();
    } catch (e) {
      debugPrint('Logout failed: $e');
    }

    if (!mounted) {
      return;
    }

    await AppLocaleService.resetToEnglish(context);
    context.goNamed('loginpage');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BackChevron(),
              ),
              Container(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    child: Container(
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: const AlignmentDirectional(0.0, 0.0),
                            children: [
                              (profileImage.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(100),
                                      child: Image.network(
                                        profileImage,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 80.0,
                                      height: 80.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment:
                                          const AlignmentDirectional(0.0, 0.0),
                                      child: Text(
                                        isProfileLoading ? '...' : initials,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        style: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              fontSize: 30.4,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                              lineHeight: 1.3,
                                            ),
                                        overflow: TextOverflow.clip,
                                      ),
                                    ),
                            ],
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                isProfileLoading ? 'Loading...' : fullName,
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                      lineHeight: 1.3,
                                    ),
                              ),
                              Text(
                                isProfileLoading ? 'Loading...' : '@$username',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                      lineHeight: 1.5,
                                    ),
                              ),
                            ].divide(const SizedBox(height: 4.0)),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              borderRadius: BorderRadius.circular(9999.0),
                              shape: BoxShape.rectangle,
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  16.0, 4.0, 16.0, 4.0),
                              child: Container(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 14.0,
                                    ),
                                    Text(
                                      kycStatus.toUpperCase(),
                                      style: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .override(
                                            font: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                            lineHeight: 1.2,
                                          ),
                                    ),
                                  ].divide(const SizedBox(width: 4.0)),
                                ),
                              ),
                            ),
                          ),
                        ].divide(const SizedBox(height: 16.0)),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        24.0, 24.0, 24.0, 8.0),
                    child: Container(
                      child: Text(
                        'Personal Information',
                        style: FlutterFlowTheme.of(context).labelLarge.override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelLarge
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelLarge
                                  .fontStyle,
                              lineHeight: 1.3,
                            ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        24.0, 0.0, 24.0, 0.0),
                    child: Container(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(20.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              wrapWithModel(
                                model: _model.profileInfoTileModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: ProfileInfoTileWidget(
                                  icon: Icon(
                                    Icons.email_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  label: 'Email Address',
                                  show_arrow: false,
                                  value: isProfileLoading
                                      ? 'Loading...'
                                      : (email.isNotEmpty
                                          ? email
                                          : 'Not available'),
                                  onTap: null,
                                ),
                              ),
                              wrapWithModel(
                                model: _model.profileInfoTileModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: ProfileInfoTileWidget(
                                  icon: Icon(
                                    Icons.phone_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20.0,
                                  ),
                                  label: 'Phone Number',
                                  show_arrow: false,
                                  value: phone.isNotEmpty
                                      ? phone
                                      : 'Not available',
                                  onTap: null,
                                ),
                              ),
                              wrapWithModel(
                                model: _model.profileInfoTileModel3,
                                updateCallback: () => safeSetState(() {}),
                                child: GestureDetector(
                                  onTap: _isKycApproved
                                      ? null
                                      : () => context.pushNamed(
                                          'KYCPAGE',
                                          queryParameters: const {
                                            'startDidit': 'true',
                                          },
                                        ),
                                  child: ProfileInfoTileWidget(
                                    icon: Icon(
                                      Icons.fingerprint_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20.0,
                                    ),
                                    label: 'KYC Status',
                                    show_arrow: !_isKycApproved,
                                    value: _kycStatusLabel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        24.0, 24.0, 24.0, 8.0),
                    child: Container(
                      child: Text(
                        'Preferences',
                        style: FlutterFlowTheme.of(context).labelLarge.override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelLarge
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelLarge
                                  .fontStyle,
                              lineHeight: 1.3,
                            ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        24.0, 0.0, 24.0, 0.0),
                    child: Container(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(20.0),
                            shape: BoxShape.rectangle,
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
// SECURITY & PIN
                              GestureDetector(
                                onTap: () async {
                                  final result =
                                      await context.pushNamed('pin_setup_page');
                                  if (result == true) {
                                    await fetchSecuritySettings();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.security_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Security & PIN',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (securityLoading)
                                              Text(
                                                'Loading security status...',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 12,
                                                ),
                                              )
                                            else
                                              Text(
                                                accountLocked
                                                    ? 'Account Locked'
                                                    : hasPin
                                                        ? 'PIN already set'
                                                        : 'No PIN Configured',
                                                style: TextStyle(
                                                  color: accountLocked
                                                      ? context.errorColor
                                                      : context.successColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

// CHANGE PIN
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed(
                                    ChangePinPageWidget.routeName,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.primaryColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_reset,
                                          color: context.background),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Change PIN',
                                        style: TextStyle(
                                            color: context.background),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.chevron_right,
                                          color: context.background),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

// FORGOT PIN
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed(
                                    ForgotPinPageWidget.routeName,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: context.primaryColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.help_outline,
                                          color: context.background),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Forgot PIN / Reset Blocked PIN',
                                        style: TextStyle(
                                            color: context.background),
                                      ),
                                      const Spacer(),
                                      Icon(Icons.chevron_right,
                                          color: context.background),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

// DARK MODE
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: Colors.green,
                                value: FFAppState().themeMode == ThemeMode.dark,
                                onChanged: (value) {
                                  FFAppState().themeMode =
                                      value ? ThemeMode.dark : ThemeMode.light;
                                },
                                title: Text('Dark Mode'),
                                subtitle: Text(
                                  FFAppState().themeMode == ThemeMode.dark
                                      ? 'Dark theme enabled'
                                      : 'Light theme enabled',
                                ),
                              ),

                              const SizedBox(height: 12),

// BIOMETRICS
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: Colors.green,
                                value: biometricsEnabled,
                                onChanged: (value) async {
                                  // Do not change the UI until operation succeeds
                                  final biometricLockService =
                                      BiometricLockService();
                                  try {
                                    if (value) {
                                      final ok = await biometricLockService
                                          .enableBiometrics();
                                      if (ok) {
                                        setState(() {
                                          biometricsEnabled = true;
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Biometrics enabled')),
                                        );
                                      }
                                    } else {
                                      // turning off
                                      final ok = await biometricLockService
                                          .disableBiometrics();
                                      if (ok) {
                                        setState(() {
                                          biometricsEnabled = false;
                                        });
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Biometrics disabled')),
                                        );
                                      }
                                    }
                                  } catch (e, stack) {
                                    if (mounted) {
                                      setState(() {
                                        biometricsEnabled =
                                            FFAppState().biometricsEnabled;
                                      });
                                      debugPrint('===== BIOMETRIC ERROR =====');
                                      debugPrint(e.toString());
                                      debugPrint(stack.toString());
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                                title: Text('Enable Biometrics'),
                                subtitle: Text(
                                  biometricsEnabled
                                      ? 'Face ID / Fingerprint active'
                                      : 'Biometric authentication disabled',
                                ),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Biometric lock timeout'),
                                subtitle: Text(
                                  'Unlock after ${formatBiometricLockTimeoutLabel(biometricLockTimeoutSeconds)}',
                                ),
                                trailing: SizedBox(
                                  width: 140,
                                  child: DropdownButton<int>(
                                    value: biometricLockTimeoutSeconds,
                                    items: [5, 15, 30, 60, 300, 600]
                                        .map(
                                          (value) => DropdownMenuItem<int>(
                                            value: value,
                                            child: Text(
                                              formatBiometricLockTimeoutLabel(
                                                  value),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: biometricsEnabled
                                        ? (value) {
                                            if (value == null) return;
                                            setState(() {
                                              biometricLockTimeoutSeconds =
                                                  value;
                                            });
                                            FFAppState()
                                                    .biometricLockTimeoutSeconds =
                                                value;
                                          }
                                        : null,
                                    underline: const SizedBox.shrink(),
                                    disabledHint: Text(
                                      formatBiometricLockTimeoutLabel(
                                          biometricLockTimeoutSeconds),
                                    ),
                                  ),
                                ),
                              ),
                              // WALLET ADDRESS (Algorand, receive USDC)
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => const WalletAddressPage()));
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.account_balance_wallet_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'Wallet address',
                                ),
                              ),
                              // MKULIMA AI ASSISTANT
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => const AssistantChatPage()));
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.smart_toy_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'Mkulima assistant',
                                ),
                              ),
                              // NOTIFICATIONS
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed('NotificationSettingsPage');
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.notifications_none_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'settings.notification_settings'.tr(),
                                ),
                              ),

// LANGUAGE
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed('LanguageSettingsPage');
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.language_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'language'.tr(),
                                ),
                              ),

// PRIVACY POLICY
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed('PrivacyPolicyPage');
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.privacy_tip_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'settings.privacy_policy'.tr(),
                                ),
                              ),

// TERMS OF SERVICE
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed('TermsOfServicePage');
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.description_outlined,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'settings.terms_of_service'.tr(),
                                ),
                              ),

// SUPPORT / HELP CENTER
                              GestureDetector(
                                onTap: () {
                                  context.pushNamed('SupportHelpCenterPage');
                                },
                                child: SettingsActionTileWidget(
                                  icon: Icon(
                                    Icons.help_outline_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                  ),
                                  label: 'settings.support_help'.tr(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 32.0),
                child: Container(
                  child: Container(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          wrapWithModel(
                            model: _model.buttonModel,
                            updateCallback: () => safeSetState(() {}),
                            child: ButtonWidget(
                              content: 'common.sign_out'.tr(),
                              icon: Icon(
                                Icons.logout_rounded,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 16.0,
                              ),
                              icon_present: true,
                              icon_end_present: false,
                              on_tap: '',
                              onTapCallback: logoutUser,
                              color: FlutterFlowTheme.of(context).primaryText,
                              variant: 'outline',
                              size: 'medium',
                              full_width: true,
                              loading: false,
                              disabled: false,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          ButtonWidget(
                            content: 'settings.delete_account'.tr(),
                            icon: Icon(
                              Icons.delete_forever_rounded,
                              color: Colors.white,
                              size: 16.0,
                            ),
                            icon_present: true,
                            icon_end_present: false,
                            on_tap: '',
                            onTapCallback: () {
                              context
                                  .pushNamed(DeleteAccountPageWidget.routeName);
                            },
                            variant: 'destructive',
                            size: 'medium',
                            full_width: true,
                            loading: false,
                            disabled: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 24.0,
                          height: 24.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primaryText,
                            borderRadius: BorderRadius.circular(6.0),
                            shape: BoxShape.rectangle,
                          ),
                          alignment: const AlignmentDirectional(0.0, 0.0),
                          child: Text(
                            'F',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  lineHeight: 1.5,
                                ),
                          ),
                        ),
                        Text(
                          'FARM',
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                                lineHeight: 1.4,
                              ),
                        ),
                      ].divide(const SizedBox(width: 4.0)),
                    ),
                    Text(
                      'a loop of growth',
                      style: FlutterFlowTheme.of(context).labelSmall.override(
                            font: GoogleFonts.plusJakartaSans(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).onSurface,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontStyle,
                            lineHeight: 1.2,
                          ),
                    ),
                  ].divide(const SizedBox(height: 4.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
