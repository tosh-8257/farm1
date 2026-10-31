import '/flutter_flow/flutter_flow_util.dart';
import '/core/theme_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '/services/biometric_lock_service.dart';
import '../dashboard/dashboard_widget.dart';
import 'biometric_security_page_model.dart';

export 'biometric_security_page_model.dart';

class BiometricSecurityPageWidget extends StatefulWidget {
  const BiometricSecurityPageWidget({
    super.key,
    this.returnPath,
  });

  final String? returnPath;

  static String routeName = 'biometric_security_page';
  static String routePath = '/biometricSecurityPage';

  @override
  State<BiometricSecurityPageWidget> createState() =>
      _BiometricSecurityPageWidgetState();
}

class _BiometricSecurityPageWidgetState
    extends State<BiometricSecurityPageWidget>
    with TickerProviderStateMixin {
  late BiometricSecurityPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool isLoading = false;
  bool biometricAvailable = false;
  bool isFaceSupported = false;
  bool isFingerprintSupported = false;
  String selectedBiometricMethod = 'faceID';

  bool get _supportsPlatformBiometrics {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  late AnimationController glowController;
  late AnimationController pulseController;

  @override
  void initState() {
    super.initState();

    _model = createModel(
      context,
      () => BiometricSecurityPageModel(),
    );

    glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    checkBiometrics();
  }

  @override
  void dispose() {
    glowController.dispose();
    pulseController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> checkBiometrics() async {
    try {
      if (!_supportsPlatformBiometrics) {
        if (mounted) {
          setState(() {
            biometricAvailable = false;
            isFaceSupported = false;
            isFingerprintSupported = false;
            selectedBiometricMethod = 'faceID';
          });
        }
        return;
      }

      final biometricService = BiometricLockService();
      final canCheck = await biometricService.canUseBiometrics();
      final available = await biometricService.getAvailableBiometrics();

      if (mounted) {
        setState(() {
          biometricAvailable = canCheck;
          isFaceSupported = available.contains(BiometricType.face);
          isFingerprintSupported = available.contains(BiometricType.fingerprint);

          if (!isFaceSupported && !isFingerprintSupported) {
            selectedBiometricMethod = 'faceID';
          } else if (!isFaceSupported && selectedBiometricMethod == 'faceID') {
            selectedBiometricMethod = 'fingerprint';
          } else if (!isFingerprintSupported && selectedBiometricMethod == 'fingerprint') {
            selectedBiometricMethod = 'faceID';
          }
        });
      }
    } catch (e, stack) {
      debugPrint("BIOMETRIC CHECK ERROR: $e");
      debugPrint(stack.toString());
      if (mounted) {
        setState(() {
          biometricAvailable = false;
          isFaceSupported = false;
          isFingerprintSupported = false;
        });
      }
    }
  }

  Future<void> enableBiometrics() async {
    HapticFeedback.mediumImpact();
    setState(() {
      isLoading = true;
    });

    try {
      final biometricService = BiometricLockService();
      final ok = await biometricService.enableBiometrics();
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: context.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Text(
                'Biometric Security Enabled',
                style: TextStyle(
                  color: context.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );

          final destination = widget.returnPath ?? DashboardWidget.routePath;
          context.go(destination);
        }
      }
    } catch (e, stack) {
      debugPrint('BIOMETRIC ERROR: $e');
      debugPrint(stack.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.errorColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Text(
            'Biometric Error: $e',
            style: TextStyle(
              color: context.onSurface,
            ),
          ),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: context.onSurface.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: context.onSurface.withOpacity(0.02),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: context.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: context.onSurface.withOpacity(0.08),
                ),
              ),
              child: Icon(
                icon,
                color: context.onSurface,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: context.onSurface.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSecurityMetric({
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: context.onSurface.withOpacity(0.06),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  color: context.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: context.onSurface.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: context.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                children: [
                  /// TOP HEADER
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.onSurface,
                              borderRadius:
                                  BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Text(
                                "F",
                                style:
                                    GoogleFonts.plusJakartaSans(
                                  color: context.background,
                                  fontWeight:
                                      FontWeight.w900,
                                  fontSize: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                "FARM",
                                style:
                                    GoogleFonts.plusJakartaSans(
                                  color: context.onSurface,
                                  fontWeight:
                                      FontWeight.w900,
                                  fontSize: 28,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                "SECURE DIGITAL BANKING",
                                style: GoogleFonts.inter(
                                  color: context.onSurface.withOpacity(0.54),
                                  fontSize: 10,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.onSurface
                              .withOpacity(0.06),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                            color: context.onSurface
                                .withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: context.onSurface,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Protected",
                              style: GoogleFonts.inter(
                                color: context.onSurface,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  /// HERO BIOMETRIC AREA
                  AnimatedBuilder(
                    animation: pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale:
                            1 +
                                (pulseController.value *
                                    0.03),
                        child: child,
                      );
                    },
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            context.onSurface
                                .withOpacity(0.12),
                            context.onSurface
                                .withOpacity(0.03),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.onSurface
                                    .withOpacity(0.06),
                              ),
                            ),
                          ),
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.onSurface
                                    .withOpacity(0.08),
                              ),
                            ),
                          ),
                          Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0E0E0E,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.onSurface
                                    .withOpacity(0.12),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: context.onSurface
                                      .withOpacity(0.03),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(28),
                              child: Lottie.network(
                                'https://assets2.lottiefiles.com/packages/lf20_touohxv0.json',
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  /// TITLE
                  Text(
                    'Enable Biometric Security',
                    textAlign: TextAlign.center,
                    style:
                        GoogleFonts.plusJakartaSans(
                      color: context.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 38,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// DESCRIPTION
                  Text(
                    'Secure your FARM account using advanced biometric authentication technology. Protect transactions, wallet access, savings vaults, investments, transfers, and sensitive financial operations with Face ID and fingerprint verification.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: context.onSurface.withOpacity(0.7),
                      fontSize: 16,
                      height: 1.9,
                    ),
                  ),

                  const SizedBox(height: 50),

                  /// SECURITY METRICS
                  Row(
                    children: [
                      buildSecurityMetric(
                        value: "256-BIT",
                        label:
                            "Military Grade Encryption",
                      ),
                      const SizedBox(width: 14),
                      buildSecurityMetric(
                        value: "<1 SEC",
                        label:
                            "Authentication Speed",
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      buildSecurityMetric(
                        value: "99.9%",
                        label:
                            "Fraud Prevention Accuracy",
                      ),
                      const SizedBox(width: 14),
                      buildSecurityMetric(
                        value: "24/7",
                        label:
                            "Real-Time Threat Monitoring",
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  /// FEATURE CARDS
                  buildFeatureCard(
                    icon: Icons.shield_outlined,
                    title:
                        "Bank-Level Device Encryption",
                    subtitle:
                        "Your biometric credentials never leave your phone and remain protected by secure hardware-level encryption.",
                  ),

                  const SizedBox(height: 18),

                  buildFeatureCard(
                    icon: Icons.bolt_rounded,
                    title:
                        "Instant Secure Authentication",
                    subtitle:
                        "Login and authorize transactions in under one second with seamless biometric authentication.",
                  ),

                  const SizedBox(height: 18),

                  buildFeatureCard(
                    icon: Icons.verified_user_rounded,
                    title:
                        "Fraud & Intrusion Protection",
                    subtitle:
                        "Advanced biometric identity verification blocks unauthorized account access and suspicious activity.",
                  ),

                  const SizedBox(height: 18),

                  buildFeatureCard(
                    icon: Icons.lock_clock_rounded,
                    title:
                        "Continuous Session Protection",
                    subtitle:
                        "Sensitive account actions require biometric confirmation for an additional layer of security.",
                  ),

                  const SizedBox(height: 18),

                  buildFeatureCard(
                    icon: Icons.phonelink_lock_rounded,
                    title:
                        "Device-Based Security Binding",
                    subtitle:
                        "Biometric security is uniquely tied to your personal trusted device for maximum protection.",
                  ),

                  const SizedBox(height: 50),

                  /// STATUS CARD
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius:
                          BorderRadius.circular(32),
                      border: Border.all(
                        color:
                            context.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: context.onSurface
                                      .withOpacity(0.06),
                                  borderRadius:
                                      BorderRadius.circular(
                                    18,
                                  ),
                                ),
                                child: Icon(
                                  Icons.fingerprint_rounded,
                                  color: context.onSurface,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      "Biometric Compatibility",
                                      style:
                                          GoogleFonts.plusJakartaSans(
                                        color:
                                            context.onSurface,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 6),
                                    Text(
                                      biometricAvailable
                                          ? "Your device supports secure biometric authentication."
                                          : "Biometric authentication unavailable.",
                                      style:
                                          GoogleFonts
                                              .inter(
                                        color:
                                            context.onSurface.withOpacity(0.7),
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(
                                    18,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: context.onSurface
                                        .withOpacity(
                                      0.03,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      20,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.face_rounded,
                                        color:
                                            isFaceSupported
                                                ? Colors
                                                    .white
                                                : Colors
                                                    .white24,
                                        size: 32,
                                      ),
                                      const SizedBox(
                                          height: 12),
                                      Text(
                                        "Face ID",
                                        style:
                                            GoogleFonts
                                                .inter(
                                          color: Colors
                                              .white,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(
                                    18,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color: context.onSurface
                                        .withOpacity(
                                      0.03,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      20,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons
                                            .fingerprint_rounded,
                                        color:
                                            isFingerprintSupported
                                                ? Colors
                                                    .white
                                                : Colors
                                                    .white24,
                                        size: 32,
                                      ),
                                      const SizedBox(
                                          height: 12),
                                      Text(
                                        "Fingerprint",
                                        style:
                                            GoogleFonts
                                                .inter(
                                          color: Colors
                                              .white,
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: context.onSurface.withOpacity(0.08),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your biometric placeholder',
                            style: GoogleFonts.plusJakartaSans(
                              color: context.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Select the unlock method you want to enroll for this device. The app will save the fallback reference and use it for future re-auth after inactivity.',
                            style: GoogleFonts.inter(
                              color: context.onSurface.withOpacity(0.7),
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              ChoiceChip(
                                label: Text('Face ID'),
                                selected: selectedBiometricMethod == 'faceID',
                                selectedColor: AppTheme.accent,
                                backgroundColor: context.onSurface.withOpacity(0.06),
                                labelStyle: TextStyle(
                                  color: selectedBiometricMethod == 'faceID'
                                      ? AppTheme.onAccent
                                      : context.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedBiometricMethod = 'faceID';
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text('Fingerprint'),
                                selected: selectedBiometricMethod == 'fingerprint',
                                selectedColor: AppTheme.accent,
                                backgroundColor: context.onSurface.withOpacity(0.06),
                                labelStyle: TextStyle(
                                  color: selectedBiometricMethod == 'fingerprint'
                                      ? AppTheme.onAccent
                                      : context.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    selectedBiometricMethod = 'fingerprint';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedBiometricMethod == 'faceID'
                                ? 'Face ID will be used when available on this device.'
                                : 'Fingerprint will be used when available on this device.',
                            style: GoogleFonts.inter(
                              color: context.onSurface.withOpacity(0.54),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// BUTTONS
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : enableBiometrics,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            context.onSurface,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                        ),
                      ),
                      child:
                          isLoading
                              ? SizedBox(
                                width: 26,
                                height: 26,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  color: context.background,
                                ),
                              )
                              : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                children: [
                                  Icon(
                                    Icons
                                        .fingerprint_rounded,
                                    color:
                                        context.background,
                                    size: 24,
                                  ),
                                  const SizedBox(
                                      width: 12),
                                  Text(
                                    FFAppState().biometricsEnabled
                                        ? 'Activate Biometric Access'
                                        : 'Enroll Biometric Access',
                                    style:
                                        GoogleFonts
                                            .plusJakartaSans(
                                      color:
                                          context.background,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: OutlinedButton(
                      onPressed: () {
                        context.goNamed(
                          DashboardWidget
                              .routeName,
                        );
                      },
                      style:
                          OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: context.onSurface
                              .withOpacity(0.12),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            24,
                          ),
                        ),
                      ),
                      child: Text(
                        "Skip For Now",
                        style: GoogleFonts.inter(
                          color: context.onSurface,
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  /// FOOTER TEXT
                  Text(
                    'Biometric settings can be updated anytime from your security dashboard.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: context.onSurface.withOpacity(0.38),
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}