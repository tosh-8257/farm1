import '/services/auth/otp_autofill.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as auth_platform;
import 'package:flutter/foundation.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/utils/browser_platform_stub.dart'
    if (dart.library.html) '/utils/browser_platform_web.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/auth/auth_service.dart';
import '/services/biometric_enrollment_prompt.dart';
import '/pages/superadmin/superadmin_dashboard_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'otppage_model.dart';
export 'otppage_model.dart';

class OtppageWidget extends StatefulWidget {
  const OtppageWidget({
    super.key,
    required this.phone,
    required this.pendingLoginId,
    this.countryCode,
  });

  final String phone;
  final String pendingLoginId;
  final String? countryCode;

  static String routeName = 'otppage';
  static String routePath = '/otppage';
  static const phoneVerificationTimeout = Duration(seconds: 120);

  @override
  State<OtppageWidget> createState() => _OtppageWidgetState();
}

class _OtppageWidgetState extends State<OtppageWidget> {
  late OtppageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController otpController = TextEditingController();
  // Web-only confirmation result
  ConfirmationResult? _webConfirmationResult;
  RecaptchaVerifier? _recaptchaVerifier;
  // Shared RecaptchaVerifier across widget instances to avoid double render
  static RecaptchaVerifier? _sharedRecaptchaVerifier;
  static bool _sharedVerifierRendered = false;
  bool _otpRequestInProgress = false;
  bool _verificationStarted = false;
  bool _isCompletingVerification = false;
  bool _verificationRequestFailed = false;

  Timer? _fallbackTimer;
  String _statusTitle = 'Verifying your phone number...';
  String _statusMessage =
      'Please wait while we verify your phone automatically.';
  bool _showManualOtpField = false;
  // Verify button is a fallback: shown ~20s after the field appears or once
  // the user types by hand. Autofilled codes submit on their own.
  bool _showVerifyButton = false;
  bool _settingCodeProgrammatically = false;
  Timer? _verifyButtonTimer;
  bool _isVerifying = true;
  String? _verificationId;
  int? _resendToken;
  int _secondsRemaining = OtppageWidget.phoneVerificationTimeout.inSeconds;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OtppageModel());
    _clearPageState();
    otpController.addListener(_onOtpChanged);

    _startFallbackTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_verificationStarted) {
        _verificationStarted = true;
        _startPhoneVerification();
      }
    });
  }

  void _clearPageState() {
    otpController.clear();
    _model.otp1.clear();
    _model.otp2.clear();
    _model.otp3.clear();
    _model.otp4.clear();
    _model.otp5.clear();
    _model.otp6.clear();
    _model.isLoading = false;
    _model.resendTimer = OtppageWidget.phoneVerificationTimeout.inSeconds;
    _model.canResend = false;

    _webConfirmationResult = null;
    _recaptchaVerifier = null;
    _otpRequestInProgress = false;
    _verificationStarted = false;
    _isCompletingVerification = false;
    _verificationRequestFailed = false;
    _verificationId = null;
    _resendToken = null;
    _showManualOtpField = false;
    _showVerifyButton = false;
    _verifyButtonTimer?.cancel();
    _verifyButtonTimer = null;
    _isVerifying = true;
    _statusTitle = 'Verifying your phone number...';
    _statusMessage = 'Please wait while we verify your phone automatically.';
    _secondsRemaining = OtppageWidget.phoneVerificationTimeout.inSeconds;
  }

  String _normalizePhoneNumberForFirebase(String? value,
      {String? fallbackCountryCode}) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }

    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return '';
    }

    if (raw.startsWith('+')) {
      return '+$digitsOnly';
    }

    if (raw.startsWith('00')) {
      return '+${digitsOnly.substring(2)}';
    }

    final countryCode = (fallbackCountryCode ?? widget.countryCode ?? '')
        .replaceAll(RegExp(r'\D'), '');

    if (countryCode.isNotEmpty) {
      final withoutLeadingZero = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      return '+$countryCode$withoutLeadingZero';
    }

    return '+$digitsOnly';
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _verifyButtonTimer?.cancel();
    OtpAutofill.cancel();
    // Do not clear the shared verifier here; it will be cleared explicitly on resend.
    try {
      // clear any local reference only
      _recaptchaVerifier = null;
    } catch (_) {}
    otpController.removeListener(_onOtpChanged);
    otpController.dispose();
    _model.dispose();
    super.dispose();
  }

  void _revealManualField() {
    if (_verifyButtonTimer != null) return; // already armed
    _verifyButtonTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) setState(() => _showVerifyButton = true);
    });
    _listenForSmsCode();
  }

  /// Android SMS User Consent: one tap fills the code (Firebase SMS has no
  /// app hash, so the silent Retriever cannot be used here).
  Future<void> _listenForSmsCode() async {
    try {
      final code = await OtpAutofill.userConsent();
      if (code == null || !mounted || otpController.text.trim().isNotEmpty) {
        return;
      }
      _settingCodeProgrammatically = true;
      otpController.text = code;
      _settingCodeProgrammatically = false;
    } catch (_) {}
  }

  void _onOtpChanged() {
    if (!_settingCodeProgrammatically &&
        otpController.text.isNotEmpty &&
        !_showVerifyButton &&
        mounted) {
      setState(() => _showVerifyButton = true);
    }
    if (otpController.text.trim().length == 6 && !_isCompletingVerification) {
      _verifyManualCode();
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining <= 1) {
        timer.cancel();
        final hasVerificationSession = _verificationId?.isNotEmpty == true ||
            _webConfirmationResult != null;
        setState(() {
          if (hasVerificationSession) {
            _showManualOtpField = true;
            _revealManualField();
            _statusTitle = 'Automatic detection timed out';
            _statusMessage = 'Enter the code manually to continue.';
          }
          _isVerifying = false;
        });
        return;
      }

      setState(() {
        _secondsRemaining--;
      });
    });
  }

  Future<void> _startPhoneVerification() async {
    if (!mounted) return;

    final firebaseInitialized = Firebase.apps.isNotEmpty;
    final normalizedPhone = _normalizePhoneNumberForFirebase(widget.phone);
    debugPrint('[PHONE AUTH] Starting Firebase phone verification');
    debugPrint(
        '[PHONE AUTH] platform = ${kIsWeb ? 'Web' : defaultTargetPlatform.name}');
    debugPrint('[PHONE AUTH] Firebase initialized = $firebaseInitialized');
    debugPrint('[PHONE AUTH] phone = ${_maskedPhone(normalizedPhone)}');
    debugPrint(
        '[PHONE AUTH] pendingLoginId exists = ${widget.pendingLoginId.isNotEmpty}');

    setState(() {
      _isVerifying = true;
      _statusTitle = 'Verifying your phone number...';
      _statusMessage = 'Please wait while we verify your phone automatically.';
      _verificationRequestFailed = false;
      _showManualOtpField = false;
    });

    try {
      if (kIsWeb) {
        // prevent duplicate requests
        if (_otpRequestInProgress) {
          debugPrint(
              '[OTP] startPhoneVerification: request already in progress');
          return;
        }
        _otpRequestInProgress = true;

        // clear any previous confirmation result
        _webConfirmationResult = null;

        final firebasePhone = _normalizePhoneNumberForFirebase(
          widget.phone,
          fallbackCountryCode: widget.countryCode,
        );

        if (firebasePhone.isEmpty) {
          _otpRequestInProgress = false;
          throw Exception('Phone number was empty after normalization');
        }

        debugPrint('[PHONE AUTH] Web phone auth using RecaptchaVerifier');
        debugPrint('[OTP] normalized phone for Firebase=$firebasePhone');
        debugPrint(
            '[OTP] hostname=${getBrowserHostname()} platform=${getBrowserPlatformLabel()}');

        // Initialize a shared RecaptchaVerifier and render it only once
        if (_sharedRecaptchaVerifier == null) {
          final verifier = RecaptchaVerifier(
            auth: auth_platform.FirebaseAuthPlatform.instance,
            onSuccess: () {
              debugPrint('[OTP] reCAPTCHA completed');
            },
            onError: (e) {
              debugPrint(
                  '[OTP] reCAPTCHA error code=${e.code} message=${e.message}');
            },
            onExpired: () {
              debugPrint('[OTP] reCAPTCHA expired');
            },
          );
          _sharedRecaptchaVerifier = verifier;
          _recaptchaVerifier = verifier;
          debugPrint(
              '[OTP] reCAPTCHA initialized (invisible) - new shared verifier');
          try {
            await _sharedRecaptchaVerifier!.render();
            _sharedVerifierRendered = true;
            debugPrint('[OTP] reCAPTCHA rendered (shared)');
          } catch (e, st) {
            debugPrint('[OTP] reCAPTCHA render failed: $e');
            debugPrintStack(
                label: '[OTP] reCAPTCHA render stack', stackTrace: st);
          }
        } else {
          // reuse the shared verifier
          _recaptchaVerifier = _sharedRecaptchaVerifier;
          debugPrint(
              '[OTP] reCAPTCHA reused (shared) rendered=$_sharedVerifierRendered');
        }

        try {
          debugPrint('[OTP] Calling Firebase signInWithPhoneNumber');
          _webConfirmationResult =
              await FirebaseAuth.instance.signInWithPhoneNumber(
            firebasePhone,
            _recaptchaVerifier!,
          );
          debugPrint(
              '[OTP] Firebase SMS request finished confirmationResult=${_webConfirmationResult != null}');
        } on FirebaseAuthException catch (e, st) {
          debugPrint(
              '[FirebaseAuthException] code=${e.code} message=${e.message}');
          debugPrintStack(
              label: '[FirebaseAuthException] stackTrace', stackTrace: st);
          // map common errors to user-friendly state
          if (e.code == 'quota-exceeded' ||
              e.code == 'auth/quota-exceeded' ||
              e.code == 'too-many-requests' ||
              e.code == 'auth/too-many-requests') {
            _statusTitle = 'Too many requests';
            _statusMessage =
                'SMS quota exceeded or too many attempts. Try again later.';
          } else if (e.code == 'captcha-check-failed' ||
              e.code == 'auth/captcha-check-failed') {
            _statusTitle = 'Captcha failed';
            _statusMessage = 'Captcha verification failed. Please try again.';
          } else if (e.code == 'invalid-phone-number' ||
              e.code == 'auth/invalid-phone-number') {
            _statusTitle = 'Invalid phone number';
            _statusMessage = 'The provided phone number is not valid.';
          } else if (e.code == 'network-request-failed' ||
              e.code == 'auth/network-request-failed') {
            _statusTitle = 'Network error';
            _statusMessage = 'Network error. Check your connection.';
          } else if (e.code == 'app-not-authorized' ||
              e.code == 'auth/app-not-authorized') {
            _statusTitle = 'Android app not authorized';
            _statusMessage =
                'Register this app package and its signing SHA-1/SHA-256 fingerprints in Firebase Console, then try again.';
          }
          // Clear shared verifier on fatal errors so a fresh verifier can be created on resend
          try {
            _sharedRecaptchaVerifier?.clear();
          } catch (_) {}
          _sharedRecaptchaVerifier = null;
          _sharedVerifierRendered = false;
          rethrow;
        } catch (e, st) {
          debugPrint('[OTP] signInWithPhoneNumber unexpected error: $e');
          debugPrintStack(label: '[OTP] unexpected stack', stackTrace: st);
          try {
            _sharedRecaptchaVerifier?.clear();
          } catch (_) {}
          _sharedRecaptchaVerifier = null;
          _sharedVerifierRendered = false;
          rethrow;
        } finally {
          _otpRequestInProgress = false;
        }

        if (!mounted) return;
        setState(() {
          _statusTitle = 'SMS sent';
          _statusMessage = 'Enter the code sent to your phone.';
          _showManualOtpField = true;
          _revealManualField();
          _isVerifying = false;
        });
        return;
      }

      // Mobile platforms use Firebase's normal app verification flow. Android
      // uses Play Integrity when available and falls back to reCAPTCHA; iOS
      // uses silent APNs verification and falls back to reCAPTCHA.
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        forceResendingToken: _resendToken,
        timeout: OtppageWidget.phoneVerificationTimeout,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[PHONE AUTH] verificationCompleted');
          debugPrint(
              '[PHONE AUTH] Firebase automatically retrieved the SMS credential');
          if (!mounted) return;
          await _completeFirebaseVerification(credential);
        },
        verificationFailed: (FirebaseAuthException error) async {
          debugPrint('[PHONE AUTH] verificationFailed');
          debugPrint('[PHONE AUTH] code = ${error.code}');
          debugPrint('[PHONE AUTH] message = ${error.message}');
          if (!mounted) return;
          final isRecaptchaActivityError =
              error.code == 'missing-activity-for-recaptcha' ||
                  error.code == 'auth/missing-activity-for-recaptcha';
          setState(() {
            _isVerifying = false;
            _statusTitle = isRecaptchaActivityError
                ? 'reCAPTCHA could not open'
                : 'Phone verification failed';
            _statusMessage = _friendlyError(error);
            _verificationRequestFailed = true;
            _showManualOtpField = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) async {
          debugPrint('[PHONE AUTH] codeSent');
          debugPrint(
              '[PHONE AUTH] verificationId received = ${verificationId.isNotEmpty}');
          debugPrint(
              '[PHONE AUTH] resendToken received = ${resendToken != null}');
          debugPrint(
              '[PHONE AUTH] codeSent SUCCESS - Firebase accepted SMS request');
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _statusTitle = 'SMS sent';
            _statusMessage =
                'We are waiting for the code to arrive automatically.';
            _verificationRequestFailed = false;
            _showManualOtpField = true;
            _revealManualField();
            _isVerifying = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('[PHONE AUTH] codeAutoRetrievalTimeout');
          debugPrint(
              '[PHONE AUTH] verificationId received = ${verificationId.isNotEmpty}');
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _showManualOtpField = true;
            _revealManualField();
            _statusTitle = 'Automatic detection timed out';
            _statusMessage = 'Enter the code manually to continue.';
            _isVerifying = false;
          });
        },
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        debugPrint('[PHONE AUTH] exception code = ${e.code}');
        debugPrint('[PHONE AUTH] exception message = ${e.message}');
      } else {
        debugPrint('[OTP] startPhoneVerification failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _statusTitle = 'Phone verification failed';
        _statusMessage = _friendlyError(e);
        _verificationRequestFailed = true;
        _showManualOtpField = false;
      });
    }
  }

  Future<void> _completeFirebaseVerification(
      PhoneAuthCredential credential) async {
    if (!mounted || _isCompletingVerification) return;

    _isCompletingVerification = true;

    setState(() {
      _isVerifying = true;
      _statusTitle = 'Verification successful';
      _statusMessage = 'Finishing the secure login process...';
    });

    try {
      debugPrint(
          '[OTP] completeFirebaseVerification signing in with credential');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseToken = await userCredential.user?.getIdToken() ?? '';
      debugPrint(
          '[OTP] completeFirebaseVerification firebaseToken length=${firebaseToken.length} user=${userCredential.user?.uid}');

      if (firebaseToken.isEmpty) {
        throw Exception('Unable to obtain a Firebase ID token.');
      }

      // Use authorized backend verify endpoint (password was already used)
      FFAppState().loginPreferencesPending = true;
      final response = await AuthService().verifyPhone(
        firebaseIdToken: firebaseToken,
        pendingLoginId: widget.pendingLoginId,
      );
      debugPrint('[PHONE AUTH] /api/auth/verify-phone reached = true');

      if (!mounted) {
        FFAppState().loginPreferencesPending = false;
        return;
      }

      if (response['success'] == true) {
        debugPrint('[OTP] completeFirebaseVerification succeeded');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verified. Logging you in...'),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 800), () async {
          if (!mounted) return;
          await _navigateAfterLogin(response);
        });
      } else {
        throw Exception(response['message'] ?? 'Unable to complete login.');
      }
    } catch (e) {
      FFAppState().loginPreferencesPending = false;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isCompletingVerification = false;
        _isVerifying = false;
        _statusTitle = 'Verification failed';
        _statusMessage = e.toString();
        _showManualOtpField = true;
        _revealManualField();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    }
  }

  Future<void> _verifyManualCode() async {
    if (_isCompletingVerification) return;

    final otp = otpController.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code.')),
      );
      return;
    }

    if (kIsWeb) {
      _isCompletingVerification = true;
      debugPrint(
          '[OTP] Starting Firebase phone verification via confirmation.confirm');
      debugPrint('[OTP] verifyManualCode web otp=$otp');
      try {
        final confirmation = _webConfirmationResult;
        if (confirmation == null) {
          debugPrint('[OTP] verifyManualCode missing confirmation result');
          _isCompletingVerification = false;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Confirmation result missing. Please resend code.')));
          return;
        }
        final userCredential = await confirmation.confirm(otp);
        debugPrint(
            '[OTP] Firebase confirmation result received; user=${userCredential.user?.uid}');
        final firebaseToken = await userCredential.user?.getIdToken() ?? '';
        debugPrint(
            '[OTP] verifyManualCode firebaseToken length=${firebaseToken.length}');
        if (firebaseToken.isEmpty)
          throw Exception('Unable to obtain Firebase ID token.');

        FFAppState().loginPreferencesPending = true;
        final response = await AuthService().verifyPhone(
          firebaseIdToken: firebaseToken,
          pendingLoginId: widget.pendingLoginId,
        );

        if (!mounted) {
          FFAppState().loginPreferencesPending = false;
          return;
        }
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Phone verified. Logging you in...'),
              backgroundColor: Colors.green));
          Future.delayed(const Duration(milliseconds: 800), () async {
            if (!mounted) return;
            await _navigateAfterLogin(response);
          });
          return;
        }
        throw Exception(response['message'] ?? 'Unable to complete login.');
      } catch (e) {
        FFAppState().loginPreferencesPending = false;
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        if (e is FirebaseAuthException) {
          debugPrint(
              '[Firebase ERROR] verifyManualCode code=${e.code} message=${e.message}');
        }
        if (!mounted) return;
        setState(() {
          _isCompletingVerification = false;
          _isVerifying = false;
          _statusTitle = 'Verification failed';
          _statusMessage = _friendlyError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Verification failed: ${_friendlyError(e)}')));
        return;
      }
    }

    // Mobile fallback
    if (_verificationId == null || _verificationId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Verification session expired. Request a new code.')),
      );
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    await _completeFirebaseVerification(credential);
  }

  Future<void> _navigateAfterLogin(Map<String, dynamic> response) async {
    final payload =
        response['data'] is Map ? response['data'] as Map : response;
    final user = payload['user'] is Map ? payload['user'] as Map : const {};
    final responseRole = user['role']?.toString().trim().toLowerCase() ?? '';
    final role = responseRole.isEmpty ? 'user' : responseRole;
    if (role != 'admin' && role != 'super_admin') {
      await BiometricEnrollmentPrompt.showAfterLogin(context);
    }
    if (!mounted) return;
    FFAppState().loginPreferencesPending = false;
    if (role == 'super_admin') {
      context.go(SuperadminDashboardPage.routePath);
    } else if (role == 'admin') {
      context.go('/admin');
    } else {
      final paymentRoute = FFAppState().pendingMerchantPaymentRoute;
      if (paymentRoute.startsWith('/merchantPayment')) {
        FFAppState().pendingMerchantPaymentRoute = '';
        context.go(paymentRoute);
        return;
      }
      context.goNamed('Dashboard');
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('invalid-app-credential') ||
        msg.contains('missing a valid app identifier') ||
        msg.contains('app-not-authorized')) {
      return 'Firebase could not verify this Android app. Update the app or contact support if the problem continues.';
    }
    if (msg.contains('missing-activity-for-recaptcha')) {
      return 'Keep the app open while Firebase checks this device, then try again.';
    }
    if (msg.contains('invalid-verification-code') ||
        msg.contains('INVALID_CODE')) return 'The code you entered is invalid.';
    if (msg.contains('session-expired') || msg.contains('EXPIRED'))
      return 'The verification session has expired. Request a new code.';
    if (msg.contains('too-many-requests'))
      return 'Too many requests. Try again later.';
    if (msg.contains('network-request-failed'))
      return 'Network error. Check your connection.';
    if (msg.contains('captcha-check-failed') || msg.contains('recaptcha'))
      return 'Captcha verification failed. Please try again.';
    return msg;
  }

  Future<void> _resendCode() async {
    if (!mounted || _isVerifying) return;
    otpController.clear();
    _verificationId = null;
    _resendToken = null;
    setState(() {
      _showManualOtpField = false;
      _isVerifying = true;
      _verificationRequestFailed = false;
      _statusTitle = 'Resending SMS';
      _statusMessage = 'Please wait while a new code is sent.';
      _secondsRemaining = OtppageWidget.phoneVerificationTimeout.inSeconds;
    });
    _startFallbackTimer();
    // ensure previous verifier/confirmation cleared before resending: clear shared verifier
    try {
      _sharedRecaptchaVerifier?.clear();
    } catch (_) {}
    _sharedRecaptchaVerifier = null;
    _sharedVerifierRendered = false;
    _recaptchaVerifier = null;
    _webConfirmationResult = null;
    _otpRequestInProgress = false;
    await _startPhoneVerification();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FlutterFlowIconButton(
                      borderRadius: 12,
                      buttonSize: 44,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: FlutterFlowTheme.of(context).primaryText,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    Text(
                      'FARM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 30),
                Lottie.network(
                  'https://dimg.dreamflow.cloud/v1/lottie/secure+shield+verification',
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 20),
                Text(
                  'Phone Verification',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.inter(),
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '✓ Password verified',
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  _statusTitle,
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  _maskedPhone(widget.phone),
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                if (_isVerifying)
                  const CircularProgressIndicator()
                else
                  const Icon(Icons.phone_android_rounded, size: 42),
                const SizedBox(height: 24),
                if (_showManualOtpField) ...[
                  AutofillGroup(
                    child: TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      enableSuggestions: false,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Enter 6-digit code',
                        filled: true,
                        fillColor:
                            FlutterFlowTheme.of(context).secondaryBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_showVerifyButton)
                    Text(
                      _model.isLoading
                          ? 'Verifying...'
                          : 'The code fills in and submits by itself.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodySmall,
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _model.isLoading ? null : _verifyManualCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.black,
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _model.isLoading ? 'Verifying...' : 'Verify Code',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _resendCode,
                    child: const Text('Resend Code'),
                  ),
                ] else if (_verificationRequestFailed) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _resendCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.black,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Waiting for the SMS. The one-time-code suggestion will fill the code when it arrives.',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium,
                  ),
                ],
                const Spacer(),
                Text(
                  'Secure 256-bit encrypted verification',
                  style: FlutterFlowTheme.of(context).bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _maskedPhone(String value) {
    final phone = value.trim();
    if (phone.length <= 5) return phone;
    return '${phone.substring(0, 4)}${'*' * (phone.length - 7)}${phone.substring(phone.length - 3)}';
  }
}
