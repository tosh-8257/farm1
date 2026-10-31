import 'package:flutter/material.dart';
import '/admin/widgets/admin_ui.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '/core/theme_extensions.dart';
import '../services/admin_api_service.dart';

class NotificationsManagementPage extends StatefulWidget {
  final VoidCallback? onGoBack;

  const NotificationsManagementPage({super.key, this.onGoBack});

  @override
  State<NotificationsManagementPage> createState() =>
      _NotificationsManagementPageState();
}

class _NotificationsManagementPageState
    extends State<NotificationsManagementPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _recipientsCtrl = TextEditingController();
  String _type = 'system';
  String _audience = 'all';
  String _recipientMode = 'all';
  bool _sending = false;

  Future<void> _send() async {
    if (_titleCtrl.text.isEmpty || _bodyCtrl.text.isEmpty) {
      _snack('Please fill in title and message', context.warningColor);
      return;
    }

    final recipients = _parseRecipients(_recipientsCtrl.text);
    if (_recipientMode == 'selected' && recipients.isEmpty) {
      _snack('Enter at least one recipient', context.warningColor);
      return;
    }

    setState(() => _sending = true);
    try {
      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'type': _type,
        'audience': _recipientMode == 'selected' ? 'custom' : _audience,
        'push': true,
      };

      if (_recipientMode == 'selected') {
        final recipientIds = <String>[];
        final recipientEmails = <String>[];
        final recipientPhones = <String>[];
        for (final recipient in recipients) {
          if (recipient.contains('@')) {
            recipientEmails.add(recipient);
          } else if (recipient.startsWith('+') || RegExp(r'^\d').hasMatch(recipient)) {
            recipientPhones.add(recipient);
          } else {
            recipientIds.add(recipient);
          }
        }
        if (recipientIds.isNotEmpty) payload['recipientIds'] = recipientIds;
        if (recipientEmails.isNotEmpty) payload['recipientEmails'] = recipientEmails;
        if (recipientPhones.isNotEmpty) payload['recipientPhones'] = recipientPhones;
      }

      await AdminApiService.sendNotification(payload);
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _recipientsCtrl.clear();
      _snack('Notification sent ✓', context.successColor);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), context.errorColor);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating));

  List<String> _parseRecipients(String raw) => raw
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _recipientsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Colors.white;
    final cardColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Broadcast Notification',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: context.onSurface)),
            const SizedBox(height: 6),
            Text('Send a notification to your users',
                style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Notification Title'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDec('e.g. System Maintenance Notice'),
                    ),
                    const SizedBox(height: 20),
                    _label('Message Content'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration:
                          _inputDec('Write your notification message here...'),
                    ),
                    const SizedBox(height: 20),
                    _label('Notification Type'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in [
                        'system',
                        'security',
                        'transaction',
                        'merchant',
                        'investment'
                      ])
                        ChoiceChip(
                          label: Text(t.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: _type == t
                                      ? AppTheme.onAccent
                                      : context.onSurface)),
                          selected: _type == t,
                          selectedColor: AppTheme.accent,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _type == t
                                  ? AppTheme.accent
                                  : AdminColors.border),
                          onSelected: (_) => setState(() => _type = t),
                        ),
                    ]),
                    const SizedBox(height: 20),
                    _label('Send To'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final mode in ['all', 'selected'])
                        ChoiceChip(
                          label: Text(
                              mode == 'all' ? 'ALL USERS' : 'SELECTED RECIPIENTS',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: _recipientMode == mode
                                      ? AppTheme.onAccent
                                      : context.onSurface)),
                          selected: _recipientMode == mode,
                          selectedColor: AppTheme.accent,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _recipientMode == mode
                                  ? AppTheme.accent
                                  : AdminColors.border),
                          onSelected: (_) => setState(() => _recipientMode = mode),
                        ),
                    ]),
                    if (_recipientMode == 'selected') ...[
                      const SizedBox(height: 16),
                      _label('Recipients'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _recipientsCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDec(
                            'User IDs, emails, or phone numbers (comma separated)'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Example: user_123, user@example.com, +254700000000',
                        style: GoogleFonts.plusJakartaSans(
                            color: AdminColors.textSecondary,
                            fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _label('Target Audience'),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final a in [
                        'all',
                        'verified',
                        'merchants',
                        'investors'
                      ])
                        ChoiceChip(
                          label: Text(a.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: _audience == a
                                      ? AppTheme.onAccent
                                      : context.onSurface)),
                          selected: _audience == a,
                          selectedColor: AppTheme.accent,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                              color: _audience == a
                                  ? AppTheme.accent
                                  : AdminColors.border),
                          onSelected: (_) => setState(() => _audience = a),
                        ),
                    ]),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
  foregroundColor: AppTheme.onAccent,
                          backgroundColor: AppTheme.accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: AppTheme.onAccent, strokeWidth: 2))
                            : Icon(Icons.send_rounded,
                                color: AppTheme.onAccent),
                        label: Text(
                            _sending ? 'Sending...' : 'Send Notification',
                            style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onAccent)),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 28),
            Text('Quick Templates',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: context.onSurface)),
            const SizedBox(height: 12),
            ...[
              {
                'title': 'System Maintenance',
                'body':
                    'FARM platform will undergo scheduled maintenance on [DATE] from [TIME] to [TIME]. Services may be temporarily unavailable.',
                'type': 'system'
              },
              {
                'title': 'Security Alert',
                'body':
                    'We detected unusual activity on the platform. Please ensure your account is secure and contact support if needed.',
                'type': 'security'
              },
              {
                'title': 'New Feature Available',
                'body':
                    'Exciting news! A new feature is now available on the FARM platform. Check it out in the app.',
                'type': 'system'
              },
            ].map((t) => GestureDetector(
                  onTap: () => setState(() {
                    _titleCtrl.text = t['title']!;
                    _bodyCtrl.text = t['body']!;
                    _type = t['type']!;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AdminColors.border),
                    ),
                    child: Row(children: [
                      Icon(Icons.article_rounded,
                          size: 18, color: AdminColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(t['title']!,
                                style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: context.onSurface)),
                            Text(t['body']!,
                                style: GoogleFonts.plusJakartaSans(
                                    color: AdminColors.textSecondary,
                                    fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ])),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 14, color: AdminColors.textSecondary),
                    ]),
                  ),
                )),
          ]),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AdminColors.textSecondary));

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
            color: AdminColors.textSecondary, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF0F1724),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AdminColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AdminColors.border)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
