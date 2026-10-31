
import '/components/pin_digit_box_widget.dart';
import '/components/security_note_widget.dart';


import '/backend/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/core/theme_extensions.dart';
import '/core/responsive.dart';
import '/flutter_flow/flutter_flow_widgets.dart';


import 'pin_setup_page_model.dart';
export 'pin_setup_page_model.dart';

class PinSetupPageWidget extends StatefulWidget {
  const PinSetupPageWidget({super.key});

  static String routeName = 'pin_setup_page';
  static String routePath = '/pinSetupPage';

  @override
  State<PinSetupPageWidget> createState() =>
      _PinSetupPageWidgetState();
}

class _PinSetupPageWidgetState
    extends State<PinSetupPageWidget> {
  late PinSetupPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _pin = '';
  String _confirmPin = '';

  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();

    _model = createModel(
      context,
      () => PinSetupPageModel(),
    );
    // fetch current security settings (to know if PIN exists)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchSecuritySettings();
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  bool hasPin = false;
  bool securityLoading = true;

  Future<void> fetchSecuritySettings() async {
    try {
      final resp = await ApiService.request(method: 'GET', path: '/security/settings');
      final data = Map<String, dynamic>.from(resp['data'] ?? resp);
      final remoteHasPin = data['has_pin'] ?? false;
      FFAppState().hasPin = remoteHasPin;
      setState(() {
        hasPin = remoteHasPin;
        securityLoading = false;
      });
    } catch (e) {
      print('SECURITY FETCH ERROR: $e');
      setState(() {
        securityLoading = false;
      });
    }
  }

  void onKeyPressed(String value) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += value;
        }

        if (_pin.length == 4) {
          _isConfirming = true;
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += value;
        }
      }
    });
  }

  void onDelete() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(
          0,
          _confirmPin.length - 1,
        );
      } else if (!_isConfirming &&
          _pin.isNotEmpty) {
        _pin = _pin.substring(
          0,
          _pin.length - 1,
        );
      }
    });
  }

  Future<void> validatePins() async {
    if (_pin.length < 4 ||
        _confirmPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter complete PIN',
          ),
        ),
      );
      return;
    }

    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PINs do not match',
          ),
        ),
      );

      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });

      return;
    }

    await savePin();
  }

  Future<void> savePin() async {
    try {
      print(
        "TOKEN: ${FFAppState().accessToken}",
      );

      await ApiService.setPin(pin: _pin.trim(), confirmPin: _confirmPin.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN set successfully'),
        ),
      );

      FFAppState().hasPin = true;
      setState(() {
        hasPin = true;
      });

      context.pop(true);
    } catch (e) {
      print(e);

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
          ),
        ),
      );
    }
  }

  Widget keypadButton(String number) {
    return GestureDetector(
      onTap: () => onKeyPressed(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: context.background,
          borderRadius:
              BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          number,
          style: TextStyle(
            color: context.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget deleteButton() {
    return GestureDetector(
      onTap: onDelete,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: context.isDarkMode ? context.background : Colors.black,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Icon(
          Icons.backspace_outlined,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildKeypad() {
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(
            9,
            (index) => keypadButton(
              '${index + 1}',
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            SizedBox(width: context.responsiveValue(82)),

            keypadButton('0'),

            SizedBox(width: context.responsiveValue(12)),

            deleteButton(),
          ],
        ),
      ],
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
        backgroundColor:
            FlutterFlowTheme.of(context)
                .primaryBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: context.responsiveValue(20)),

                Container(
                  width: context.responsiveValue(80),
                  height: context.responsiveValue(80),
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: context.onSurface,
                    size: context.responsiveValue(40),
                  ),
                ),

                SizedBox(height: context.responsiveValue(24)),

                Text(
                  'Create Transaction PIN',
                  textAlign: TextAlign.center,
                  style:
                      FlutterFlowTheme.of(
                              context)
                          .headlineMedium
                          .override(
                            font:
                                GoogleFonts
                                    .plusJakartaSans(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                            letterSpacing:
                                0,
                          ),
                ),

                SizedBox(height: context.responsiveValue(8)),

                Text(
                  'Set a secure PIN to authorize transactions',
                  textAlign: TextAlign.center,
                  style:
                      FlutterFlowTheme.of(
                              context)
                          .bodyMedium,
                ),

                const SizedBox(height: 12),

                // show PIN configured status
                if (!securityLoading)
                  Text(
                    hasPin ? 'PIN already set' : '',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodySmall.copyWith(
                          color: hasPin ? context.successColor : context.onSurface,
                        ),
                  ),

                const SizedBox(height: 28),

                Text(
                  !_isConfirming
                      ? 'Enter PIN'
                      : 'Confirm PIN',
                  textAlign: TextAlign.center,
                  style:
                      FlutterFlowTheme.of(
                              context)
                          .titleMedium,
                ),

                SizedBox(height: context.responsiveValue(20)),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,
                  children: List.generate(
                    4,
                    (index) {
                      final filled =
                          !_isConfirming
                              ? _pin.length >
                                  index
                              : _confirmPin
                                      .length >
                                  index;

                      return PinDigitBoxWidget(
                        filled: filled,
                      );
                    },
                  ),
                ),

                SizedBox(height: context.responsiveValue(40)),

                wrapWithModel(
                  model:
                      _model.securityNoteModel,
                  updateCallback: () =>
                      safeSetState(() {}),
                  child:
                      const SecurityNoteWidget(
                    title:
                        'Enhanced Security',
                    body:
                        'Your PIN protects transfers and sensitive actions.',
                  ),
                ),

                SizedBox(height: context.responsiveValue(40)),

                buildKeypad(),

                SizedBox(height: context.responsiveValue(30)),

                FFButtonWidget(
                  onPressed: () async {
                    await validatePins();
                  },
                  text: 'Verify PIN',
                  options: FFButtonOptions(
                    height: context.responsiveValue(55),
                    color: AppTheme.accent,
                    textStyle:
                        TextStyle(
                      color: AppTheme.onAccent,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                ),

                SizedBox(height: context.responsiveValue(40)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

