import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/loginpage/loginpage_widget.dart';
import '/services/auth/auth_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class ResetPasswordPageWidget extends StatefulWidget {
  const ResetPasswordPageWidget({
    super.key,
    this.token = '',
    this.email = '',
  });

  static String routeName = 'reset_password_page';
  static String routePath = '/reset-password';

  final String token;
  final String email;

  @override
  State<ResetPasswordPageWidget> createState() => _ResetPasswordPageWidgetState();
}

class _ResetPasswordPageWidgetState extends State<ResetPasswordPageWidget> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  late String _token;
  late String _email;

  @override
  void initState() {
    super.initState();
    _token = widget.token.isNotEmpty ? widget.token : Uri.base.queryParameters['token'] ?? '';
    _email = widget.email.isNotEmpty ? widget.email : Uri.base.queryParameters['email'] ?? '';
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await AuthService().confirmPasswordReset(
        token: _token,
        email: _email,
        password: _passwordController.text.trim(),
        confirmPassword: _confirmPasswordController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully. Please sign in with your new password.'),
          backgroundColor: Colors.green,
        ),
      );
      context.goNamed(LoginpageWidget.routeName);
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = userErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackChevron(),
        title: const Text('Create New Password'),
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        foregroundColor: FlutterFlowTheme.of(context).primaryText,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a strong new password for ${_email.isNotEmpty ? _email : 'your account'}',
                  style: FlutterFlowTheme.of(context).headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 12) {
                      return 'Use at least 12 characters, including uppercase, lowercase, a number, and a symbol.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset),
                  label: Text(_isSubmitting ? 'Updating...' : 'Update password'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.goNamed(LoginpageWidget.routeName),
                  child: const Text('Back to sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
