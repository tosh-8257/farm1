import 'dart:async';

import '/services/auth/auth_service.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/pages/loginpage/loginpage_widget.dart' show kDefaultLoginCountry;
import 'registerpage_model.dart';
export 'registerpage_model.dart';

enum _RegistrationAvailability { idle, checking, available, taken, failed }

class RegisterpageWidget extends StatefulWidget {
  const RegisterpageWidget({super.key});

  static String routeName = 'registerpage';
  static String routePath = '/registerpage';

  @override
  State<RegisterpageWidget> createState() => _RegisterpageWidgetState();
}

class _RegisterpageWidgetState extends State<RegisterpageWidget> {
  late RegisterpageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  final _usernameFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();

  final TextEditingController firstNameController = TextEditingController();

  final TextEditingController lastNameController = TextEditingController();

  final TextEditingController usernameController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  final TextEditingController countryController = TextEditingController();

  final TextEditingController referralController = TextEditingController();

  String _selectedCountry = kDefaultLoginCountry['name']!;
  String _selectedCountryIsoCode = kDefaultLoginCountry['iso']!;
  String _selectedCountryCode = kDefaultLoginCountry['code']!;
  _RegistrationAvailability _usernameAvailability =
      _RegistrationAvailability.idle;
  _RegistrationAvailability _phoneAvailability = _RegistrationAvailability.idle;
  _RegistrationAvailability _emailAvailability = _RegistrationAvailability.idle;
  Timer? _availabilityDebounce;
  int _availabilityRequestId = 0;

  String _flagForCountry(String countryCode) {
    return String.fromCharCodes(
      countryCode.codeUnits.map((unit) => unit + 0x1F1A5),
    );
  }

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      searchAutofocus: true,
      onSelect: (country) {
        setState(() {
          _selectedCountry = country.name;
          _selectedCountryIsoCode = country.countryCode;
          _selectedCountryCode = '+${country.phoneCode}';
          _phoneAvailability = _RegistrationAvailability.idle;
        });
        _phoneFieldKey.currentState?.validate();
        _scheduleAvailabilityCheck();
      },
    );
  }

  void _scheduleAvailabilityCheck() {
    _availabilityDebounce?.cancel();
    _availabilityRequestId++;
    setState(() {
      _usernameAvailability = _RegistrationAvailability.idle;
      _phoneAvailability = _RegistrationAvailability.idle;
      _emailAvailability = _RegistrationAvailability.idle;
    });
    _availabilityDebounce = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_checkRegistrationAvailability()),
    );
  }

  Future<bool> _checkRegistrationAvailability() async {
    _availabilityDebounce?.cancel();
    final username = usernameController.text.trim().toLowerCase();
    final email = emailController.text.trim().toLowerCase();
    final phoneDigits = phoneController.text.trim();
    final phone = '$_selectedCountryCode$phoneDigits';
    final usernameToCheck =
        RegExp(r'^[a-z0-9_]+$').hasMatch(username) ? username : null;
    final emailToCheck =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? email : null;
    final phoneToCheck =
        RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone) ? phone : null;

    if (usernameToCheck == null &&
        emailToCheck == null &&
        phoneToCheck == null) {
      return false;
    }

    final requestId = ++_availabilityRequestId;
    if (mounted) {
      setState(() {
        _usernameAvailability = usernameToCheck == null
            ? _RegistrationAvailability.idle
            : _RegistrationAvailability.checking;
        _emailAvailability = emailToCheck == null
            ? _RegistrationAvailability.idle
            : _RegistrationAvailability.checking;
        _phoneAvailability = phoneToCheck == null
            ? _RegistrationAvailability.idle
            : _RegistrationAvailability.checking;
      });
    }

    try {
      final response = await ApiService.checkRegistrationAvailability(
        username: usernameToCheck,
        email: emailToCheck,
        phone: phoneToCheck,
      );
      final data = response['data'];
      if (data is! Map ||
          (usernameToCheck != null && data['usernameAvailable'] is! bool) ||
          (emailToCheck != null && data['emailAvailable'] is! bool) ||
          (phoneToCheck != null && data['phoneAvailable'] is! bool)) {
        throw const FormatException(
          'The registration availability response was invalid.',
        );
      }
      if (!mounted || requestId != _availabilityRequestId) return false;

      setState(() {
        _usernameAvailability = usernameToCheck == null
            ? _RegistrationAvailability.idle
            : data['usernameAvailable'] == true
                ? _RegistrationAvailability.available
                : _RegistrationAvailability.taken;
        _emailAvailability = emailToCheck == null
            ? _RegistrationAvailability.idle
            : data['emailAvailable'] == true
                ? _RegistrationAvailability.available
                : _RegistrationAvailability.taken;
        _phoneAvailability = phoneToCheck == null
            ? _RegistrationAvailability.idle
            : data['phoneAvailable'] == true
                ? _RegistrationAvailability.available
                : _RegistrationAvailability.taken;
      });
      _usernameFieldKey.currentState?.validate();
      _phoneFieldKey.currentState?.validate();
      _emailFieldKey.currentState?.validate();

      return usernameToCheck != null &&
          emailToCheck != null &&
          phoneToCheck != null &&
          _usernameAvailability == _RegistrationAvailability.available &&
          _emailAvailability == _RegistrationAvailability.available &&
          _phoneAvailability == _RegistrationAvailability.available;
    } catch (error) {
      debugPrint('Registration availability check failed: $error');
      if (mounted && requestId == _availabilityRequestId) {
        setState(() {
          if (usernameToCheck != null) {
            _usernameAvailability = _RegistrationAvailability.failed;
          }
          if (emailToCheck != null) {
            _emailAvailability = _RegistrationAvailability.failed;
          }
          if (phoneToCheck != null) {
            _phoneAvailability = _RegistrationAvailability.failed;
          }
        });
      }
      return false;
    }
  }

  String? _availabilityMessage(
    _RegistrationAvailability availability,
    String field,
  ) {
    return switch (availability) {
      _RegistrationAvailability.idle => null,
      _RegistrationAvailability.checking => 'Checking $field availability...',
      _RegistrationAvailability.available =>
        '$field does not exist. You can register.',
      _RegistrationAvailability.taken =>
        '$field already exists. Please choose another one.',
      _RegistrationAvailability.failed =>
        'Could not check $field. Check your connection and try again.',
    };
  }

  Color _availabilityMessageColor(
    BuildContext context,
    _RegistrationAvailability availability,
  ) {
    return switch (availability) {
      _RegistrationAvailability.available => Colors.green,
      _RegistrationAvailability.taken ||
      _RegistrationAvailability.failed =>
        Colors.red,
      _RegistrationAvailability.checking =>
        FlutterFlowTheme.of(context).secondaryText,
      _RegistrationAvailability.idle =>
        FlutterFlowTheme.of(context).secondaryText,
    };
  }

  String? _duplicateFieldFromError(Object error) {
    final message = error.toString().toLowerCase();
    if (!RegExp(r'already|exists|taken|duplicate|unique').hasMatch(message)) {
      return null;
    }
    if (message.contains('username')) return 'username';
    if (message.contains('phone')) return 'phone';
    if (message.contains('email')) return 'email';
    return 'unknown';
  }

  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  Widget passwordRequirement(
    BuildContext context, {
    required String label,
    required bool met,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16.0,
          color: met ? Colors.green : theme.secondaryText,
        ),
        const SizedBox(width: 6.0),
        Text(
          label,
          style: TextStyle(
            color: met ? Colors.green : theme.secondaryText,
            fontSize: 12.0,
          ),
        ),
      ],
    );
  }

  Widget passwordRequirements(BuildContext context) {
    final password = passwordController.text;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 6.0,
        children: [
          passwordRequirement(
            context,
            label: '12 characters',
            met: password.length >= 12,
          ),
          passwordRequirement(
            context,
            label: 'Capital letter',
            met: RegExp(r'[A-Z]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Small letter',
            met: RegExp(r'[a-z]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Number',
            met: RegExp(r'[0-9]').hasMatch(password),
          ),
          passwordRequirement(
            context,
            label: 'Punctuation mark',
            met: RegExp(r'''[^A-Za-z0-9\s]''').hasMatch(password),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
      context,
      () => RegisterpageModel(),
    );
    FFAppState().themeMode = ThemeMode.light;
  }

  @override
  void dispose() {
    _availabilityDebounce?.cancel();
    _availabilityRequestId++;
    firstNameController.dispose();
    lastNameController.dispose();
    usernameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    countryController.dispose();
    referralController.dispose();

    _model.dispose();

    super.dispose();
  }

  InputDecoration inputDecoration(
    BuildContext context,
    String hint,
  ) {
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

  Widget buildLabel(
    BuildContext context,
    String text,
  ) {
    return Text(
      text,
      style: FlutterFlowTheme.of(context).labelLarge.override(
            font: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
            ),
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 64.0,
                        height: 64.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryText,
                          borderRadius: BorderRadius.circular(16.0),
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
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                ),
                              ),
                              Align(
                                alignment:
                                    const AlignmentDirectional(-1.0, -0.6),
                                child: Container(
                                  width: 24.0,
                                  height: 6.0,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    borderRadius: BorderRadius.circular(2.0),
                                  ),
                                ),
                              ),
                              Align(
                                alignment:
                                    const AlignmentDirectional(-1.0, 0.0),
                                child: Container(
                                  width: 18.0,
                                  height: 6.0,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
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
                        style: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .override(
                              font: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'a loop of growth',
                        style: FlutterFlowTheme.of(context).labelSmall.override(
                              font: GoogleFonts.plusJakartaSans(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),
                  Text(
                    'Create your account',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          font: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                          ),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Secure your financial future today',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(),
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 24.0),
                  buildLabel(context, 'First Name'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: firstNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'First name is required';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter first name',
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Last Name'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: lastNameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Last name is required';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter last name',
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Username'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    key: _usernameFieldKey,
                    controller: usernameController,
                    onChanged: (_) => _scheduleAvailabilityCheck(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username required';
                      }

                      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                        return 'Lowercase letters, numbers and underscores only';
                      }

                      return null;
                    },
                    decoration:
                        inputDecoration(context, 'Enter username').copyWith(
                      helperText: _availabilityMessage(
                        _usernameAvailability,
                        'Username',
                      ),
                      helperStyle: TextStyle(
                        color: _availabilityMessageColor(
                          context,
                          _usernameAvailability,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Phone Number'),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: _showCountryPicker,
                          borderRadius: BorderRadius.circular(14.0),
                          child: InputDecorator(
                            decoration:
                                inputDecoration(context, 'Code').copyWith(
                              suffixIcon: const Icon(Icons.arrow_drop_down),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _flagForCountry(_selectedCountryIsoCode),
                                ),
                                const SizedBox(width: 6.0),
                                Expanded(
                                  child: Text(
                                    '$_selectedCountryIsoCode '
                                    '$_selectedCountryCode',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          key: _phoneFieldKey,
                          controller: phoneController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => _scheduleAvailabilityCheck(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number required';
                            }
                            final fullPhone = '$_selectedCountryCode$value';
                            if (!RegExp(r'^\+[1-9]\d{7,14}$')
                                .hasMatch(fullPhone)) {
                              return 'Enter valid phone number';
                            }
                            return null;
                          },
                          decoration:
                              inputDecoration(context, '700123456').copyWith(
                            helperText: _availabilityMessage(
                              _phoneAvailability,
                              'Phone number',
                            ),
                            helperStyle: TextStyle(
                              color: _availabilityMessageColor(
                                context,
                                _phoneAvailability,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Email'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    key: _emailFieldKey,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => _scheduleAvailabilityCheck(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email required';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                    decoration:
                        inputDecoration(context, 'Enter email').copyWith(
                      helperText: _availabilityMessage(
                        _emailAvailability,
                        'Email',
                      ),
                      helperStyle: TextStyle(
                        color: _availabilityMessageColor(
                          context,
                          _emailAvailability,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Password'),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password required';
                      }

                      if (value.length < 12) {
                        return 'Minimum 12 characters';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Include a capital letter';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(value)) {
                        return 'Include a small letter';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Include a number';
                      }
                      if (!RegExp(r'''[^A-Za-z0-9\s]''').hasMatch(value)) {
                        return 'Include a punctuation mark';
                      }

                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Enter password',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  Text(
                    '(Use at least 12 characters, including a capital letter, '
                    'small letter, number, and punctuation mark)',
                    style: TextStyle(
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 12.0,
                    ),
                  ),
                  passwordRequirements(context),
                  const SizedBox(height: 16.0),
                  buildLabel(
                    context,
                    'Confirm Password',
                  ),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !confirmPasswordVisible,
                    validator: (value) {
                      if (value != passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    decoration: inputDecoration(
                      context,
                      'Confirm password',
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          confirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            confirmPasswordVisible = !confirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(context, 'Country'),
                  const SizedBox(height: 8.0),
                  InkWell(
                    onTap: _showCountryPicker,
                    borderRadius: BorderRadius.circular(14.0),
                    child: InputDecorator(
                      decoration:
                          inputDecoration(context, 'Select country').copyWith(
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Row(
                        children: [
                          Text(_flagForCountry(_selectedCountryIsoCode)),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              '$_selectedCountry ($_selectedCountryIsoCode) '
                              '$_selectedCountryCode',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  buildLabel(
                    context,
                    'Referral Code',
                  ),
                  const SizedBox(height: 8.0),
                  TextFormField(
                    controller: referralController,
                    decoration: inputDecoration(
                      context,
                      'Optional referral',
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  FFButtonWidget(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();

                      if (!_formKey.currentState!.validate()) {
                        return;
                      }

                      final fullPhone =
                          '$_selectedCountryCode${phoneController.text.trim()}';
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (!email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('auth.valid_email'.tr()),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      final registrationAvailable =
                          await _checkRegistrationAvailability();
                      if (!mounted) return;
                      if (!registrationAvailable) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Use a unique username, phone number, and email. '
                              'All three must be confirmed available before registration.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      try {
                        await AuthService().signUp(
                          email: email,
                          password: password,
                          firstName: firstNameController.text.trim(),
                          lastName: lastNameController.text.trim(),
                          username: usernameController.text.trim(),
                          phone: fullPhone,
                          country: _selectedCountry,
                          referralCode: referralController.text.trim(),
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'auth.registration_success'.tr(),
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );

                        Future.delayed(
                          const Duration(seconds: 1),
                          () {
                            context.pushNamed('loginpage');
                          },
                        );
                      } catch (e) {
                        print('ERROR: $e');

                        final duplicateField = _duplicateFieldFromError(e);
                        if (duplicateField != null) {
                          final fieldLabel = switch (duplicateField) {
                            'username' => 'Username',
                            'phone' => 'Phone number',
                            'email' => 'Email',
                            _ => '',
                          };

                          if (duplicateField != 'unknown') {
                            setState(() {
                              if (duplicateField == 'username') {
                                _usernameAvailability =
                                    _RegistrationAvailability.taken;
                              } else if (duplicateField == 'phone') {
                                _phoneAvailability =
                                    _RegistrationAvailability.taken;
                              } else {
                                _emailAvailability =
                                    _RegistrationAvailability.taken;
                              }
                            });
                            _formKey.currentState?.validate();
                          }

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                duplicateField == 'unknown'
                                    ? 'An account already uses one of these details. Please check your username, phone number, and email.'
                                    : '$fieldLabel already exists. Please enter another one.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final message = e
                                .toString()
                                .contains('Could not connect to backend server')
                            ? 'common.network_error'.tr()
                            : 'auth.registration_failed'.tr();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    text: 'auth.create_account'.tr(),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 54.0,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16.0,
                        0.0,
                        16.0,
                        0.0,
                      ),
                      iconPadding: const EdgeInsetsDirectional.fromSTEB(
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                      ),
                      color: AppTheme.accent,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: AppTheme.onAccent,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                              ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(width: 4.0),
                      InkWell(
                        onTap: () {
                          context.pushNamed('loginpage');
                        },
                        child: Text(
                          'Login',
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: FlutterFlowTheme.of(context).primary,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32.0),
                  Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).alternate,
                        borderRadius: BorderRadius.circular(9999.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
