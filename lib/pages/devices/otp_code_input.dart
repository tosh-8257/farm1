import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/services/auth/otp_autofill.dart';

/// 6-digit code field that submits itself once complete.
///
/// Android: SMS Retriever ([useRetriever], our own SMS with app hash) or SMS
/// User Consent. iOS: AutofillHints.oneTimeCode. The Verify button is only a
/// fallback: shown after [fallbackAfter] or once the user types by hand.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    super.key,
    required this.onCompleted,
    this.busy = false,
    this.useRetriever = false,
    this.fallbackAfter = const Duration(seconds: 20),
  });

  final Future<void> Function(String code) onCompleted;
  final bool busy;
  final bool useRetriever;
  final Duration fallbackAfter;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _controller = TextEditingController();
  Timer? _fallbackTimer;
  bool _showVerify = false;
  bool _programmatic = false;
  String _lastSubmitted = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _fallbackTimer = Timer(widget.fallbackAfter, () {
      if (mounted) setState(() => _showVerify = true);
    });
    _listenSms();
  }

  Future<void> _listenSms() async {
    try {
      final code = widget.useRetriever
          ? await OtpAutofill.retriever()
          : await OtpAutofill.userConsent();
      if (code == null || !mounted) return;
      _programmatic = true;
      _controller.text = code;
      _programmatic = false;
    } catch (_) {
      // Autofill unavailable: the field and fallback button still work.
    }
  }

  void _onChanged() {
    final text = _controller.text.trim();
    if (!_programmatic && text.isNotEmpty && !_showVerify) {
      setState(() => _showVerify = true);
    }
    if (text.length == 6 && text != _lastSubmitted && !widget.busy) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 6) return;
    _lastSubmitted = code;
    await widget.onCompleted(code);
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    OtpAutofill.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AutofillGroup(
          child: TextField(
            controller: _controller,
            autofocus: true,
            enabled: !widget.busy,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 10,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              filled: true,
              fillColor: const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (widget.busy)
          const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          )
        else if (_showVerify)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Verify'),
            ),
          )
        else
          const Text(
            'Waiting for the SMS. The code fills in and submits by itself.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B6B6B)),
          ),
      ],
    );
  }
}
