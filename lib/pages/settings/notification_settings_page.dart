import 'package:flutter/material.dart';
import '/widgets/common/back_chevron.dart';
// Removed unused import

import '/backend/services/api_service.dart';
import '/core/app_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/core/theme_extensions.dart';
import '/utils/user_error_message.dart';

class NotificationSettingsPageWidget extends StatefulWidget {
  const NotificationSettingsPageWidget({super.key});

  static String routeName = 'NotificationSettingsPage';
  static String routePath = '/notifications';

  @override
  State<NotificationSettingsPageWidget> createState() =>
      _NotificationSettingsPageWidgetState();
}

class _NotificationSettingsPageWidgetState
    extends State<NotificationSettingsPageWidget> {
  late bool pushNotifications;
  late bool emailNotifications;
  late bool inAppNotifications;
  late bool smsNotifications;
  late bool soundEnabled;
  late bool vibrationEnabled;

  bool loading = true;
  bool notificationsLoading = true;
  List<Map<String, dynamic>> notifications = [];
  String? notificationsError;
  bool isSaving = false;

  final String baseUrl = AppConfig.api;
  String get token => FFAppState().accessToken;

  void _syncFromAppState() {
    pushNotifications = FFAppState().pushNotifications;
    emailNotifications = FFAppState().emailNotifications;
    inAppNotifications = FFAppState().inAppNotifications;
    smsNotifications = FFAppState().smsNotifications;
    soundEnabled = FFAppState().notificationSoundEnabled;
    vibrationEnabled = FFAppState().notificationVibrationEnabled;
  }

  @override
  void initState() {
    super.initState();
    _syncFromAppState();
    loadSettings();
    loadNotifications();
  }

  Future<void> loadSettings() async {
    // Don't reload settings if we're currently saving
    if (isSaving) return;

    try {
      final resp = await ApiService.request(
          method: 'GET', path: '/notifications/settings');

      if (!mounted || isSaving) return;

      final settings = resp['data'] ?? resp;

      if (settings is Map<String, dynamic>) {
        setState(() {
          pushNotifications = settings['push_notifications'] ?? true;
          emailNotifications = settings['email_notifications'] ?? false;
          inAppNotifications = settings['in_app_notifications'] ?? true;
          smsNotifications = settings['sms_notifications'] ?? false;
          soundEnabled = settings['sound_enabled'] ?? true;
          vibrationEnabled = settings['vibration_enabled'] ?? true;
          loading = false;
        });

        FFAppState().update(() {
          FFAppState().pushNotifications = pushNotifications;
          FFAppState().emailNotifications = emailNotifications;
          FFAppState().inAppNotifications = inAppNotifications;
          FFAppState().smsNotifications = smsNotifications;
          FFAppState().notificationSoundEnabled = soundEnabled;
          FFAppState().notificationVibrationEnabled = vibrationEnabled;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        loading = false;
      });
    } catch (e) {
      debugPrint('LOAD SETTINGS ERROR: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loadNotifications() async {
    if (!mounted) return;
    setState(() {
      notificationsLoading = true;
      notificationsError = null;
    });

    try {
      final response = await ApiService.getNotifications();
      final dynamic rawList = response['data'] ?? response['notifications'];
      final List<Map<String, dynamic>> parsed = [];

      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map) {
            parsed.add(Map<String, dynamic>.from(item));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        notifications = parsed;
        notificationsLoading = false;
      });
    } catch (e) {
      debugPrint('LOAD NOTIFICATIONS ERROR: $e');
      if (!mounted) return;
      setState(() {
        notificationsLoading = false;
        notificationsError = userErrorMessage(e);
      });
    }
  }

  Future<bool> saveSettings() async {
    if (isSaving) return false;

    try {
      isSaving = true;

      final resp = await ApiService.request(
        method: 'PUT',
        path: '/notifications/settings',
        body: {
          'push_notifications': pushNotifications,
          'email_notifications': emailNotifications,
          'in_app_notifications': inAppNotifications,
          'sms_notifications': smsNotifications,
          'sound_enabled': soundEnabled,
          'vibration_enabled': vibrationEnabled,
        },
      );

      if (!mounted) return false;

      final success = resp.isNotEmpty;

      if (success) {
        FFAppState().update(() {
          FFAppState().pushNotifications = pushNotifications;
          FFAppState().emailNotifications = emailNotifications;
          FFAppState().inAppNotifications = inAppNotifications;
          FFAppState().smsNotifications = smsNotifications;
          FFAppState().notificationSoundEnabled = soundEnabled;
          FFAppState().notificationVibrationEnabled = vibrationEnabled;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('common.notification_updated'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('common.notification_update_failed'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      return success;
    } catch (e) {
      debugPrint('SAVE SETTINGS ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('common.notification_update_failed'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      isSaving = false;
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return 'Just now';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();

    final now = DateTime.now();
    final difference = now.difference(parsed);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    }
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        leading: const BackChevron(),
        title: Text('common.notifications_title'.tr()),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: () async {
              await loadSettings();
              await loadNotifications();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await loadSettings();
          await loadNotifications();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'common.notifications_preferences'.tr(),
              style: theme.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    value: pushNotifications,
                    title: Text('common.push_notifications'.tr()),
                    subtitle:
                        Text('common.push_notifications_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => pushNotifications = value);
                            await saveSettings();
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: emailNotifications,
                    title: Text('common.email_notifications'.tr()),
                    subtitle:
                        Text('common.email_notifications_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => emailNotifications = value);
                            await saveSettings();
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: inAppNotifications,
                    title: Text('common.in_app_notifications'.tr()),
                    subtitle:
                        Text('common.in_app_notifications_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => inAppNotifications = value);
                            await saveSettings();
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: smsNotifications,
                    title: Text('common.sms_notifications'.tr()),
                    subtitle: Text('common.sms_notifications_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => smsNotifications = value);
                            await saveSettings();
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: soundEnabled,
                    title: Text('common.sound'.tr()),
                    subtitle: Text('common.sound_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => soundEnabled = value);
                            await saveSettings();
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    value: vibrationEnabled,
                    title: Text('common.vibration'.tr()),
                    subtitle: Text('common.vibration_description'.tr()),
                    onChanged: isSaving
                        ? null
                        : (value) async {
                            setState(() => vibrationEnabled = value);
                            await saveSettings();
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'common.recent_activity'.tr(),
                  style:
                      theme.titleMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    await loadNotifications();
                  },
                  icon: Icon(Icons.sync_rounded, size: 18),
                  label: Text('common.refresh'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (notificationsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (notificationsError != null)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Unable to load notifications right now.\n$notificationsError',
                    style: TextStyle(color: context.errorColorAccent),
                  ),
                ),
              )
            else if (notifications.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('common.notifications_empty_title'.tr(),
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Text('common.notifications_empty_description'.tr()),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: notifications
                    .map(
                      (notification) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: theme.secondaryBackground,
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: theme.primaryText,
                              ),
                            ),
                            title: Text(
                              notification['title']?.toString() ??
                                  notification['subject']?.toString() ??
                                  'Notification',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              notification['message']?.toString() ??
                                  notification['body']?.toString() ??
                                  notification['content']?.toString() ??
                                  'No details available',
                            ),
                            trailing: Text(
                              _formatTime(
                                notification['created_at'] ??
                                    notification['createdAt'] ??
                                    notification['timestamp'],
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
