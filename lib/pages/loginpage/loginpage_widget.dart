import 'package:shared_preferences/shared_preferences.dart';
import '/core/app_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'loginpage_model.dart';
export 'loginpage_model.dart';
import '/admin/pages/admin_shell.dart';
import '/pages/superadmin/superadmin_dashboard_page.dart';
import '/services/auth/auth_service.dart';
import '/services/auth/biometric_login_service.dart';
import '/services/auth/session_store_service.dart';
import '/pages/forgot_password_page/forgot_password_page_widget.dart';
import '/pages/otppage/otppage_widget.dart';

/// Create a premium black and white fintech login page for FARM App.
///
/// Include:  * FARM logo at the top * Phone number input field * Password
/// input field * Login button * Forgot password text button * "Create
/// Account" button below login  Style:  * Modern banking app design * Black
/// and white theme * Rounded cards and buttons * Minimal and clean layout *
/// Premium fintech appearance * Mobile-first responsive design * Smooth
/// spacing and typography  Important:  * Design should feel like a secure
/// banking app * Professional and trustworthy UI * Keep layout simple and
/// elegant TAKE TIME AND DO IT IN DETAIL
const Map<String, String> kDefaultLoginCountry = {
  'name': 'Kenya',
  'iso': 'KE',
  'code': '+254',
  'flag': '🇰🇪',
};

class LoginpageWidget extends StatefulWidget {
  const LoginpageWidget({super.key});

  static String routeName = 'loginpage';
  static String routePath = '/loginpage';

  @override
  State<LoginpageWidget> createState() => _LoginpageWidgetState();
}

class _LoginpageWidgetState extends State<LoginpageWidget> {
  late LoginpageModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool passwordVisible = false;
  bool isLoading = false;
  bool _biometricAvailable = false;
  String _biometricButtonLabel = 'Login with Biometric';
  // Kenya is the primary market; users can still pick any country.
  Map<String, String> _selectedCountry = Map.of(kDefaultLoginCountry);

  final List<Map<String, String>> _africanCountries = [
    {'name': 'Algeria', 'iso': 'DZ', 'code': '+213', 'flag': '🇩🇿'},
    {'name': 'Angola', 'iso': 'AO', 'code': '+244', 'flag': '🇦🇴'},
    {'name': 'Benin', 'iso': 'BJ', 'code': '+229', 'flag': '🇧🇯'},
    {'name': 'Botswana', 'iso': 'BW', 'code': '+267', 'flag': '🇧🇼'},
    {'name': 'Burkina Faso', 'iso': 'BF', 'code': '+226', 'flag': '🇧🇫'},
    {'name': 'Burundi', 'iso': 'BI', 'code': '+257', 'flag': '🇧🇮'},
    {'name': 'Cabo Verde', 'iso': 'CV', 'code': '+238', 'flag': '🇨🇻'},
    {'name': 'Cameroon', 'iso': 'CM', 'code': '+237', 'flag': '🇨🇲'},
    {
      'name': 'Central African Republic',
      'iso': 'CF',
      'code': '+236',
      'flag': '🇨🇫'
    },
    {'name': 'Chad', 'iso': 'TD', 'code': '+235', 'flag': '🇹🇩'},
    {'name': 'Comoros', 'iso': 'KM', 'code': '+269', 'flag': '🇰🇲'},
    {'name': 'Congo', 'iso': 'CG', 'code': '+242', 'flag': '🇨🇬'},
    {'name': 'DR Congo', 'iso': 'CD', 'code': '+243', 'flag': '🇨🇩'},
    {'name': 'Cote d\'Ivoire', 'iso': 'CI', 'code': '+225', 'flag': '🇨🇮'},
    {'name': 'Djibouti', 'iso': 'DJ', 'code': '+253', 'flag': '🇩🇯'},
    {'name': 'Egypt', 'iso': 'EG', 'code': '+20', 'flag': '🇪🇬'},
    {'name': 'Equatorial Guinea', 'iso': 'GQ', 'code': '+240', 'flag': '🇬🇶'},
    {'name': 'Eritrea', 'iso': 'ER', 'code': '+291', 'flag': '🇪🇷'},
    {'name': 'Eswatini', 'iso': 'SZ', 'code': '+268', 'flag': '🇸🇿'},
    {'name': 'Ethiopia', 'iso': 'ET', 'code': '+251', 'flag': '🇪🇹'},
    {'name': 'Gabon', 'iso': 'GA', 'code': '+241', 'flag': '🇬🇦'},
    {'name': 'Gambia', 'iso': 'GM', 'code': '+220', 'flag': '🇬🇲'},
    {'name': 'Ghana', 'iso': 'GH', 'code': '+233', 'flag': '🇬🇭'},
    {'name': 'Guinea', 'iso': 'GN', 'code': '+224', 'flag': '🇬🇳'},
    {'name': 'Guinea-Bissau', 'iso': 'GW', 'code': '+245', 'flag': '🇬🇼'},
    {'name': 'Kenya', 'iso': 'KE', 'code': '+254', 'flag': '🇰🇪'},
    {'name': 'Lesotho', 'iso': 'LS', 'code': '+266', 'flag': '🇱🇸'},
    {'name': 'Liberia', 'iso': 'LR', 'code': '+231', 'flag': '🇱🇷'},
    {'name': 'Libya', 'iso': 'LY', 'code': '+218', 'flag': '🇱🇾'},
    {'name': 'Madagascar', 'iso': 'MG', 'code': '+261', 'flag': '🇲🇬'},
    {'name': 'Malawi', 'iso': 'MW', 'code': '+265', 'flag': '🇲🇼'},
    {'name': 'Mali', 'iso': 'ML', 'code': '+223', 'flag': '🇲🇱'},
    {'name': 'Mauritania', 'iso': 'MR', 'code': '+222', 'flag': '🇲🇷'},
    {'name': 'Mauritius', 'iso': 'MU', 'code': '+230', 'flag': '🇲🇺'},
    {'name': 'Morocco', 'iso': 'MA', 'code': '+212', 'flag': '🇲🇦'},
    {'name': 'Mozambique', 'iso': 'MZ', 'code': '+258', 'flag': '🇲🇿'},
    {'name': 'Namibia', 'iso': 'NA', 'code': '+264', 'flag': '🇳🇦'},
    {'name': 'Niger', 'iso': 'NE', 'code': '+227', 'flag': '🇳🇪'},
    {'name': 'Nigeria', 'iso': 'NG', 'code': '+234', 'flag': '🇳🇬'},
    {'name': 'Rwanda', 'iso': 'RW', 'code': '+250', 'flag': '🇷🇼'},
    {
      'name': 'Sao Tome and Principe',
      'iso': 'ST',
      'code': '+239',
      'flag': '🇸🇹'
    },
    {'name': 'Senegal', 'iso': 'SN', 'code': '+221', 'flag': '🇸🇳'},
    {'name': 'Seychelles', 'iso': 'SC', 'code': '+248', 'flag': '🇸🇨'},
    {'name': 'Sierra Leone', 'iso': 'SL', 'code': '+232', 'flag': '🇸🇱'},
    {'name': 'Somalia', 'iso': 'SO', 'code': '+252', 'flag': '🇸🇴'},
    {'name': 'South Africa', 'iso': 'ZA', 'code': '+27', 'flag': '🇿🇦'},
    {'name': 'South Sudan', 'iso': 'SS', 'code': '+211', 'flag': '🇸🇸'},
    {'name': 'Sudan', 'iso': 'SD', 'code': '+249', 'flag': '🇸🇩'},
    {'name': 'Tanzania', 'iso': 'TZ', 'code': '+255', 'flag': '🇹🇿'},
    {'name': 'Togo', 'iso': 'TG', 'code': '+228', 'flag': '🇹🇬'},
    {'name': 'Tunisia', 'iso': 'TN', 'code': '+216', 'flag': '🇹🇳'},
    {'name': 'Uganda', 'iso': 'UG', 'code': '+256', 'flag': '🇺🇬'},
    {'name': 'Zambia', 'iso': 'ZM', 'code': '+260', 'flag': '🇿🇲'},
    {'name': 'Zimbabwe', 'iso': 'ZW', 'code': '+263', 'flag': '🇿🇼'},
  ];

  final String baseUrl = '${AppConfig.api}/auth';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginpageModel());
    _initializeBiometric();
  }

  Future<void> _initializeBiometric() async {
    try {
      final biometricService = BiometricLoginService();
      final canUse = await biometricService.canUseBiometrics();
      final hasSession = await biometricService.hasBiometricSession();

      if (mounted && canUse && hasSession) {
        final label = await biometricService.getBiometricButtonLabel();
        setState(() {
          _biometricAvailable = true;
          _biometricButtonLabel = label;
        });
      }
    } catch (e) {
      debugPrint('Error initializing biometric: $e');
    }
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _finalizeSuccessfulLogin(Map<String, dynamic> response) async {
    final payload = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response['data'] is Map
            ? Map<String, dynamic>.from(response['data'] as Map)
            : response;

    final accessToken = (payload['access_token'] as String? ??
            payload['farmJwt'] as String? ??
            '')
        .trim();
    final refreshToken = (payload['refresh_token'] as String? ??
            payload['refreshToken'] as String? ??
            '')
        .trim();
    final data = payload['user'] is Map<String, dynamic>
        ? payload['user'] as Map<String, dynamic>
        : payload['user'] is Map
            ? Map<String, dynamic>.from(payload['user'] as Map)
            : null;

    if (accessToken.isNotEmpty && data != null) {
      final role = (data['role'] ?? '').toString().toLowerCase();
      final normalizedRole = role.isEmpty ? 'user' : role;
      FFAppState().role = normalizedRole;

      final prefs = await SharedPreferences.getInstance();

      if (normalizedRole == 'user') {
        FFAppState().accessToken = accessToken;
        FFAppState().refreshToken = refreshToken;
        FFAppState().userId = data['id'] ?? '';
        FFAppState().firstName = data['first_name'] ?? '';
        FFAppState().userName = data['username'] ?? '';
        FFAppState().phone = data['phone'] ?? '';
        FFAppState().kycStatus = data['kyc_status'] ?? '';
        FFAppState().emailVerified = data['email_verified'] == true;
        FFAppState().isLoggedIn = true;

        await AuthSessionStore.saveUserSession(
          accessToken: accessToken,
          refreshToken: refreshToken,
          role: normalizedRole,
          userId: data['id'] ?? '',
        );

        await prefs.remove('adminToken');
        await prefs.remove('adminRefreshToken');
        await prefs.remove('adminRole');
        await prefs.remove('adminName');
      } else {
        FFAppState().accessToken = accessToken;
        FFAppState().refreshToken = refreshToken;
        FFAppState().userId = data['id'] ?? '';
        FFAppState().firstName = data['first_name'] ?? '';
        FFAppState().userName = data['username'] ?? '';
        FFAppState().phone = data['phone'] ?? '';
        FFAppState().isLoggedIn = true;

        await prefs.setString('adminName', data['first_name'] ?? 'Admin');
        if (normalizedRole == 'admin' || normalizedRole == 'super_admin') {
          await AuthSessionStore.saveRoleSession(
            role: normalizedRole,
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: data['id']?.toString() ?? '',
          );
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('common.login_success'.tr()),
        backgroundColor: Colors.green,
      ),
    );

    Future.delayed(
      const Duration(seconds: 1),
      () {
        final role = FFAppState().role;
        if (role == 'super_admin') {
          print('Navigating to ${SuperadminDashboardPage.routePath}');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const SuperadminDashboardPage(),
            ),
          );
        } else if (role == 'admin') {
          print('Navigating to /admin-shell');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminShell()),
          );
        } else {
          print('Navigating to Dashboard');
          final paymentRoute = FFAppState().pendingMerchantPaymentRoute;
          if (paymentRoute.startsWith('/merchantPayment')) {
            FFAppState().pendingMerchantPaymentRoute = '';
            context.go(paymentRoute);
            return;
          }
          context.goNamed('Dashboard');
        }
      },
    );
  }

  /// Login with email or phone/password
  Future<void> handleLogin() async {
    final raw = phoneController.text.trim();
    // normalize: keep digits only and remove leading zeros
    final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedDigits = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
    final countryCode = _selectedCountry['code']?.replaceAll('+', '') ?? '';
    final identifier = countryCode.isNotEmpty
        ? '+$countryCode$normalizedDigits'
        : '+$normalizedDigits';
    final password = passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.all_fields_required'.tr()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await AuthService().login(
        identifier: identifier,
        password: password,
        countryCode: _selectedCountry['code'],
      );

      final loginData = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'] as Map)
          : response;
      if (loginData['requiresPhoneVerification'] == true) {
        final pendingLoginId = loginData['pendingLoginId']?.toString() ?? '';
        final verifiedPhone = loginData['phone']?.toString() ?? identifier;
        if (pendingLoginId.isEmpty) {
          throw Exception(
              'Unable to start phone verification. Please try again.');
        }
        if (!mounted) return;
        context.go(
          '${OtppageWidget.routePath}?pendingLoginId=${Uri.encodeComponent(pendingLoginId)}&phone=${Uri.encodeComponent(verifiedPhone)}&countryCode=${Uri.encodeComponent(_selectedCountry['code'] ?? '')}',
        );
        return;
      }

      await _finalizeSuccessfulLogin(response);
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        final isNetworkIssue = errorMsg.contains('Connection closed') ||
            errorMsg.contains('ERR_CONNECTION_CLOSED') ||
            errorMsg.contains('SocketException') ||
            errorMsg.contains('Failed host lookup') ||
            errorMsg.contains('Network');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNetworkIssue
                ? 'common.network_error'.tr()
                : 'common.login_failed'.tr()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  /// Login with biometric (fingerprint/face ID)
  Future<void> handleBiometricLogin() async {
    setState(() => isLoading = true);

    try {
      debugPrint('[BiometricLogin] Starting biometric authentication...');

      final biometricService = BiometricLoginService();
      final response = await biometricService.authenticateWithBiometric();

      if (!response['success']) {
        throw Exception(
            response['message'] ?? 'Biometric authentication failed');
      }

      final user = response['user'] as Map<String, dynamic>? ?? {};
      final role = (user['role'] ?? 'user').toString();

      debugPrint(
          '[BiometricLogin] Biometric login successful, routing to dashboard...');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common.biometric_success'.tr()),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(
        const Duration(seconds: 1),
        () {
          if (!mounted) return;

          if (role == 'super_admin') {
            print('Navigating to ${SuperadminDashboardPage.routePath}');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const SuperadminDashboardPage(),
              ),
            );
          } else if (role == 'admin') {
            print('Navigating to /admin-shell');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminShell()),
            );
          } else {
            print('Navigating to Dashboard');
            context.goNamed('Dashboard');
          }
        },
      );
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.biometric_failed'.tr()}: $errorMsg'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  InputDecoration inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: FlutterFlowTheme.of(context).secondaryText,
      ),
      filled: true,
      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 18.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: BorderSide(
          color: FlutterFlowTheme.of(context).primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SingleChildScrollView(
          primary: false,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// LOGO SECTION
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72.0,
                      height: 72.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryText,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      alignment: const AlignmentDirectional(0.0, 0.0),
                      child: SizedBox(
                        width: 40.0,
                        height: 50.0,
                        child: Stack(
                          alignment: const AlignmentDirectional(-1.0, -1.0),
                          children: [
                            Align(
                              alignment: const AlignmentDirectional(0.0, 0.0),
                              child: Container(
                                width: 6.0,
                                height: 50.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).onPrimary,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                            Align(
                              alignment: const AlignmentDirectional(-1.0, -0.6),
                              child: Container(
                                width: 24.0,
                                height: 6.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).onPrimary,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                            Align(
                              alignment: const AlignmentDirectional(-1.0, 0.0),
                              child: Container(
                                width: 18.0,
                                height: 6.0,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).onPrimary,
                                  borderRadius: BorderRadius.circular(2.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      'FARM',
                      style:
                          FlutterFlowTheme.of(context).headlineLarge.override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'auth.sign_in_title'.tr(),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(),
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 40.0),

                /// FORM SECTION
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /// Phone Field
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'common.phone'.tr(),
                          style: FlutterFlowTheme.of(context)
                              .labelLarge
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                final searchController =
                                    TextEditingController();
                                final selected = await showModalBottomSheet<
                                    Map<String, String>>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (sheetContext) => StatefulBuilder(
                                    builder: (context, setSheetState) {
                                      final query = searchController.text
                                          .trim()
                                          .toLowerCase();
                                      final matches = _africanCountries
                                          .where((country) =>
                                              (country['name'] ?? '')
                                                  .toLowerCase()
                                                  .contains(query) ||
                                              (country['code'] ?? '')
                                                  .toLowerCase()
                                                  .contains(query))
                                          .toList();

                                      return SafeArea(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            bottom: MediaQuery.viewInsetsOf(
                                                    sheetContext)
                                                .bottom,
                                          ),
                                          child: SizedBox(
                                            height:
                                                MediaQuery.sizeOf(sheetContext)
                                                        .height *
                                                    0.7,
                                            child: Column(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          16, 16, 16, 8),
                                                  child: Text(
                                                    'common.select_country'
                                                        .tr(),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .titleMedium,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          16, 8, 16, 12),
                                                  child: TextField(
                                                    controller:
                                                        searchController,
                                                    onChanged: (_) =>
                                                        setSheetState(() {}),
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search country or code',
                                                      prefixIcon: const Icon(
                                                          Icons.search),
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      isDense: true,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: matches.isEmpty
                                                      ? const Center(
                                                          child: Text(
                                                            'No countries found',
                                                          ),
                                                        )
                                                      : ListView.builder(
                                                          itemCount:
                                                              matches.length,
                                                          itemBuilder:
                                                              (ctx, i) {
                                                            final country =
                                                                matches[i];
                                                            return ListTile(
                                                              leading: Text(
                                                                  country['flag'] ??
                                                                      ''),
                                                              title: Text(
                                                                country['name'] ??
                                                                    '',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium,
                                                              ),
                                                              trailing: Text(
                                                                  country['code'] ??
                                                                      ''),
                                                              onTap: () =>
                                                                  Navigator.of(
                                                                          ctx)
                                                                      .pop(
                                                                          country),
                                                            );
                                                          },
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                                searchController.dispose();

                                if (selected != null) {
                                  setState(() {
                                    _selectedCountry = selected;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate),
                                ),
                                child: Row(
                                  children: [
                                    Text(_selectedCountry['flag'] ?? ''),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${_selectedCountry['iso'] ?? ''} ${_selectedCountry['code'] ?? ''}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: phoneController,
                                decoration: inputDecoration(
                                    context, 'auth.enter_phone'.tr()),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24.0),

                    /// Password Field
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'common.password'.tr(),
                          style: FlutterFlowTheme.of(context)
                              .labelLarge
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        TextFormField(
                          controller: passwordController,
                          decoration: inputDecoration(
                                  context, 'auth.enter_password'.tr())
                              .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                passwordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                    () => passwordVisible = !passwordVisible);
                              },
                            ),
                          ),
                          obscureText: !passwordVisible,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32.0),

                    /// Login Button
                    FFButtonWidget(
                      onPressed: isLoading ? null : handleLogin,
                      text: isLoading
                          ? 'auth.signing_in'.tr()
                          : 'common.sign_in'.tr(),
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 56.0,
                        padding: const EdgeInsets.symmetric(vertical: 0.0),
                        color: AppTheme.accent,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  color: AppTheme.onAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    /// Biometric Login Button (if available)
                    if (_biometricAvailable)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'common.or'.tr(),
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          FFButtonWidget(
                            onPressed: isLoading ? null : handleBiometricLogin,
                            text: _biometricButtonLabel,
                            options: FFButtonOptions(
                              width: double.infinity,
                              height: 56.0,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 0.0),
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                        ],
                      ),

                    TextButton(
                      onPressed: () =>
                          context.pushNamed(ForgotPasswordPageWidget.routeName),
                      child: Text(
                        'common.forgot_password'.tr(),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              color: FlutterFlowTheme.of(context).primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),

                    /// Create Account Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${'common.no_account'.tr()} ',
                          style: FlutterFlowTheme.of(context).bodySmall,
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed('registerpage'),
                          child: Text(
                            'common.sign_up'.tr(),
                            style: FlutterFlowTheme.of(context)
                                .bodySmall
                                .override(
                                  color: FlutterFlowTheme.of(context).primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
