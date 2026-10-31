import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../pages/loginpage/loginpage_widget.dart';
import '../core/admin_navigation.dart';
import '../services/admin_api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

String _firebaseErrorMessage(FirebaseAuthException error) {
  switch (error.code) {
    case 'unauthorized-continue-uri':
    case 'domain-not-allowlisted':
      return 'Firebase blocked the reset link domain. Add farmapp-e2145.firebaseapp.com to Firebase Authentication authorized domains.';
    case 'operation-not-allowed':
      return 'Email/password sign-in is not enabled for this Firebase project.';
    case 'user-not-found':
    case 'invalid-email':
      return 'Firebase could not find an account for this email. Check the address and try again.';
    case 'expired-action-code':
    case 'invalid-action-code':
      return 'This reset link is invalid or has expired. Request a new one.';
    case 'user-disabled':
      return 'This account is disabled. Contact your system administrator.';
    case 'weak-password':
      return 'Choose a stronger password.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    default:
      return error.message ?? 'Password reset failed. Please try again.';
  }
}

class AdminForgotPasswordPage extends StatefulWidget {
  const AdminForgotPasswordPage({super.key});

  @override
  State<AdminForgotPasswordPage> createState() =>
      _AdminForgotPasswordPageState();
}

class _AdminForgotPasswordPageState extends State<AdminForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AdminApiService.requestPasswordReset(
        _emailController.text.trim(),
      );
      if (mounted) setState(() => _emailSent = true);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(_firebaseErrorMessage(error));
      }
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Reset admin password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _emailSent
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mark_email_read_outlined, size: 44),
                          const SizedBox(height: 16),
                          Text(
                            'Check your email',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'If an account exists, we have sent a reset link.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Enter your admin account email and we will '
                              'send you a reset link.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty || !email.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _sendResetEmail,
                              child: Text(_isLoading
                                  ? 'Sending...'
                                  : 'Send reset link'),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({required this.oobCode, super.key});

  final String oobCode;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _email;
  String? _verificationError;
  bool _isVerifying = true;
  bool _isSaving = false;
  bool _firebasePasswordWasReset = false;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    try {
      final email =
          await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      if (mounted) setState(() => _email = email);
    } on FirebaseAuthException catch (error) {
      if (mounted)
        setState(() => _verificationError = _firebaseErrorMessage(error));
    } catch (error) {
      if (mounted) setState(() => _verificationError = userErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String? _passwordError(String? value) {
    final password = value ?? '';
    if (password.length < 12 ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^\da-zA-Z]').hasMatch(password)) {
      return 'Use 12+ characters with uppercase, lowercase, number, and symbol';
    }
    return null;
  }

  Future<void> _savePassword() async {
    if (_email == null || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (!_firebasePasswordWasReset) {
        await FirebaseAuth.instance.confirmPasswordReset(
          code: widget.oobCode,
          newPassword: _passwordController.text,
        );
        if (mounted) setState(() => _firebasePasswordWasReset = true);
      }

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email!,
        password: _passwordController.text,
      );
      final firebaseIdToken = await credential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        throw Exception('Could not verify the updated Firebase account');
      }
      await AdminApiService.completePasswordReset(
        firebaseIdToken: firebaseIdToken,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      AuthNavigation.replaceAllWithBuilder(
        context,
        (_) => const LoginpageWidget(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Password reset successfully. Sign in with your new password.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(_firebaseErrorMessage(error));
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _verificationError;
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Set a new password'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _isVerifying
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Return to admin login'),
                              ),
                            ],
                          )
                        : Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _firebasePasswordWasReset
                                      ? 'Your Firebase password is updated. '
                                          'Retry to finish syncing your admin account.'
                                      : 'Choose a new password for ${_email ?? 'your account'}.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  autofillHints: const [
                                    AutofillHints.newPassword
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'New password',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: _passwordError,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm new password',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _savePassword,
                                  child: Text(_isSaving
                                      ? 'Saving...'
                                      : _firebasePasswordWasReset
                                          ? 'Retry password sync'
                                          : 'Save new password'),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
