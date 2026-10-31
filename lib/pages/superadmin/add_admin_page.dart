import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '/admin/services/admin_api_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  static const String routeName = 'add_admin_page';
  static const String routePath = '/superadmin/add-admin';

  @override
  State<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countryCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final response = await AdminApiService.createAdmin(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        username: _usernameCtrl.text.trim().toLowerCase(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        country: _countryCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final message =
          response['message']?.toString() ?? 'Admin account created successfully';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        GoRouter.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${userErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF162033),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1320),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1320),
        foregroundColor: Colors.white,
        leading: const BackChevron(),
        title: Text('Create Admin',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create an account with the Admin role. The account can sign in after receiving its phone verification code.',
                  style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                const Chip(
                  avatar: Icon(Icons.admin_panel_settings_outlined, size: 18),
                  label: Text('Role: Admin'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('First Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _firstNameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('First name'),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                    ? 'First name is required'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Last Name'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lastNameCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Last name'),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                    ? 'Last name is required'
                                    : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Username'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Username'),
                  validator: (value) {
                    if ((value?.trim().isEmpty ?? true))
                      return 'Username is required';
                    if ((value?.trim().length ?? 0) < 3)
                      return 'Username must be at least 3 characters';
                    if (!RegExp(r'^[a-zA-Z0-9_]+$')
                        .hasMatch(value!.trim())) {
                      return 'Use only letters, numbers, and underscores';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('Email'),
                            validator: (value) {
                              if ((value?.trim().isEmpty ?? true))
                                return 'Email is required';
                              if (!value!.contains('@'))
                                return 'Enter a valid email';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Phone'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration('Phone'),
                            validator: (value) {
                              final phone = value?.trim() ?? '';
                              if (phone.isEmpty) return 'Phone is required';
                              if (!RegExp(r'^\+?[1-9]\d{7,14}$')
                                  .hasMatch(phone)) {
                                return 'Enter a valid international phone number';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('Country'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _countryCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Country'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Country is required'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Password'),
                            obscureText: true,
                            validator: (value) {
                              if ((value?.isEmpty ?? true))
                                return 'Password is required';
                              if (!RegExp(
                                      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z]).{12,}$')
                                  .hasMatch(value!)) {
                                return 'Use 12+ characters with uppercase, lowercase, a number, and a symbol';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Confirm Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('Confirm Password'),
                            obscureText: true,
                            validator: (value) {
                              if ((value?.isEmpty ?? true))
                                return 'Confirm password is required';
                              if (value != _passwordCtrl.text)
                                return 'Passwords do not match';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black)),
                          )
                        : Text('Create Admin',
                            style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.onAccent,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
