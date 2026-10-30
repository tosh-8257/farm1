import 'package:flutter/material.dart';
import '/app_state.dart';
import '/backend/services/api_service.dart';
import '/pages/business/ops/ops_ui.dart';
import '/pages/security/account_security_logic.dart';

enum _VerifyState { idle, verifying, verified, failed }

/// Email verification. Opens from the emailed link (?token=...) and verifies
/// automatically, or lets the user request a new single-use link.
/// Black/white/grey only.
class VerifyEmailPageWidget extends StatefulWidget {
  const VerifyEmailPageWidget({super.key, this.initialToken});

  /// For tests and deep links; defaults to the `token` query parameter.
  final String? initialToken;

  static String routeName = 'verify_email_page';
  static String routePath = '/verify-email';

  @override
  State<VerifyEmailPageWidget> createState() => _VerifyEmailPageWidgetState();
}

class _VerifyEmailPageWidgetState extends State<VerifyEmailPageWidget> {
  _VerifyState _state = _VerifyState.idle;
  bool _sending = false;
  String? _message;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: FFAppState().email);
    final token = extractVerificationToken(
        widget.initialToken ?? Uri.base.queryParameters['token'] ?? '');
    if (token != null) _verify(token);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _verify(String token) async {
    setState(() {
      _state = _VerifyState.verifying;
      _message = null;
    });
    try {
      await ApiService.verifyEmail(token: token);
      FFAppState().emailVerified = true;
      if (mounted) setState(() => _state = _VerifyState.verified);
    } on ApiServiceException catch (e) {
      if (mounted) {
        setState(() {
          _state = _VerifyState.failed;
          _message = e.statusCode == 400
              ? 'This link is invalid, expired or already used. Request a new one below.'
              : friendlyAuthError(e.statusCode, e.message);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _state = _VerifyState.failed;
          _message = 'Could not reach the server. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _resend() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await ApiService.resendEmailVerification(email: email);
      if (mounted) {
        setState(() => _message =
            'If this address belongs to an unverified account, a new link is on its way. It expires in 24 hours.');
      }
    } on ApiServiceException catch (e) {
      if (mounted) setState(() => _message = friendlyAuthError(e.statusCode, e.message));
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final fg = fgColor(c), muted = mutedColor(c);
    Widget body;
    switch (_state) {
      case _VerifyState.verifying:
        body = Column(key: const Key('ve-loading'), children: [
          const SizedBox(height: 48),
          CircularProgressIndicator(color: fg),
          const SizedBox(height: 16),
          Text('Verifying your email…', style: TextStyle(color: muted)),
        ]);
        break;
      case _VerifyState.verified:
        body = Column(key: const Key('ve-success'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 32),
          Icon(Icons.mark_email_read_outlined, size: 64, color: fg),
          const SizedBox(height: 12),
          Text('Email verified', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: primaryButtonStyle(c),
            onPressed: () => Navigator.of(c).maybePop(),
            child: const Text('Continue'),
          ),
        ]);
        break;
      case _VerifyState.idle:
      case _VerifyState.failed:
        body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(Icons.mail_outline, size: 48, color: fg),
          const SizedBox(height: 12),
          Text(
            _state == _VerifyState.failed ? 'Verification failed' : 'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
          ),
          const SizedBox(height: 8),
          Text('We will email you a single-use link that expires in 24 hours.',
              textAlign: TextAlign.center, style: TextStyle(color: muted)),
          const SizedBox(height: 20),
          TextField(
            key: const Key('ve-email'),
            controller: _email,
            enabled: !_sending,
            keyboardType: TextInputType.emailAddress,
            decoration: bizInput(c, 'Email address'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_state == _VerifyState.failed ? Icons.error_outline : Icons.info_outline, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(child: Text(_message!, key: const Key('ve-message'), style: TextStyle(color: fg))),
            ]),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('ve-resend'),
            style: primaryButtonStyle(c),
            onPressed: _sending ? null : _resend,
            child: _sending
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send verification link'),
          ),
        ]);
    }
    return BizScaffold(
      title: 'Verify email',
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: [body])),
    );
  }
}
