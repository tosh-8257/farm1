import 'package:flutter/material.dart';
import '/backend/services/api_service.dart';
import '/pages/business/ops/ops_ui.dart';
import 'account_security_logic.dart';

/// Change password: requires the current password; on success the server
/// signs out every other device. Black/white/grey only.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = changePasswordFormError(
      current: _current.text,
      next: _next.text,
      confirm: _confirm.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      setState(() => _done = true);
    } on ApiServiceException catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e.statusCode, e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not change your password. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return BizScaffold(
      title: 'Change password',
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (_done) ...[
            Icon(Icons.check_circle_outline, size: 56, color: fgColor(c)),
            const SizedBox(height: 12),
            Text('Password changed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fgColor(c))),
            const SizedBox(height: 8),
            Text('Other devices have been signed out. This device stays signed in.',
                textAlign: TextAlign.center, style: TextStyle(color: mutedColor(c))),
            const SizedBox(height: 24),
            ElevatedButton(
              style: primaryButtonStyle(c),
              onPressed: () => Navigator.of(c).maybePop(),
              child: const Text('Done'),
            ),
          ] else ...[
            Text('Use at least 12 characters with upper and lower case letters, a number and a symbol.',
                style: TextStyle(color: mutedColor(c))),
            const SizedBox(height: 16),
            TextField(
              key: const Key('cp-current'),
              controller: _current,
              obscureText: _obscure,
              enabled: !_loading,
              autofillHints: const [AutofillHints.password],
              decoration: bizInput(c, 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('cp-new'),
              controller: _next,
              obscureText: _obscure,
              enabled: !_loading,
              autofillHints: const [AutofillHints.newPassword],
              decoration: bizInput(c, 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('cp-confirm'),
              controller: _confirm,
              obscureText: _obscure,
              enabled: !_loading,
              decoration: bizInput(c, 'Confirm new password'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: mutedColor(c)),
                label: Text(_obscure ? 'Show passwords' : 'Hide passwords', style: TextStyle(color: mutedColor(c))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline, size: 18, color: fgColor(c)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        key: const Key('cp-error'),
                        style: TextStyle(color: fgColor(c), fontWeight: FontWeight.w600))),
              ]),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('cp-submit'),
              style: primaryButtonStyle(c),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Change password'),
            ),
          ],
        ]),
      ),
    );
  }
}
