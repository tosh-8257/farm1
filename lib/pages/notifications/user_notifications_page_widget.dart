import 'package:flutter/material.dart';
import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/services/notification_feedback_service.dart';
import '/services/notification_service.dart';
import '/widgets/common/back_chevron.dart';
import '/utils/user_error_message.dart';

class UserNotificationsPageWidget extends StatefulWidget {
  const UserNotificationsPageWidget({super.key});

  static String routeName = 'UserNotificationsPage';
  static String routePath = '/user-notifications';

  @override
  State<UserNotificationsPageWidget> createState() =>
      _UserNotificationsPageWidgetState();
}

class _UserNotificationsPageWidgetState
    extends State<UserNotificationsPageWidget> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> groupedNotifications = [];
  int unreadCount = 0;
  final Set<String> hiddenNotificationIds = <String>{};
  Set<String> _previousNotificationIds = <String>{};
  bool _hasLoadedNotificationsBefore = false;

  @override
  void initState() {
    super.initState();
    loadNotifications();
    NotificationService.notificationReceived
        .addListener(_onNotificationReceived);
  }

  Future<void> loadNotifications() async {
    final shouldShowInitialLoader =
        notifications.isEmpty && !_hasLoadedNotificationsBefore;
    if (shouldShowInitialLoader) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final items = <Map<String, dynamic>>[];
      var page = 1;
      while (true) {
        final response = await ApiService.getNotifications(
          page: page,
          limit: 100,
        );
        final rawNotifications = response['data'];
        if (rawNotifications is! List) break;
        items.addAll(
          rawNotifications.map((item) => item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map)),
        );

        final meta = response['meta'];
        final lastPage = meta is Map
            ? int.tryParse(meta['last_page']?.toString() ?? '') ?? page
            : page;
        if (page >= lastPage || rawNotifications.isEmpty) break;
        page++;
      }
      final parsed = items.cast<Map<String, dynamic>>();
      final visibleItems = parsed.where((item) {
        final id = item['id']?.toString() ?? '';
        return id.isEmpty || !hiddenNotificationIds.contains(id);
      }).toList();
      final unread = visibleItems.where((item) {
        final read = item['read'] is bool
            ? item['read'] as bool
            : item['is_read'] is bool
                ? item['is_read'] as bool
                : item['isRead'] is bool
                    ? item['isRead'] as bool
                    : false;
        return !read;
      }).length;
      final newNotificationIds = visibleItems
          .map(_notificationId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final hasNewNotifications = _hasLoadedNotificationsBefore &&
          newNotificationIds.difference(_previousNotificationIds).isNotEmpty;
      _previousNotificationIds = newNotificationIds;
      _hasLoadedNotificationsBefore = true;

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final item in visibleItems) {
        final key = _notificationGroupKey(item);
        grouped.putIfAbsent(key, () => []).add(item);
      }
      final groupedList = grouped.entries
          .map((entry) => {
                'key': entry.key,
                'label': _notificationGroupLabel(entry.key),
                'items': entry.value,
              })
          .toList();

      setState(() {
        notifications = visibleItems;
        groupedNotifications = groupedList;
        unreadCount = unread;
        isLoading = false;
      });
      if (hasNewNotifications) {
        NotificationFeedbackService.trigger();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Unable to fetch notifications.';
        isLoading = false;
      });
    }
  }

  String _notificationType(Map<String, dynamic> item) {
    final metadata = item['metadata'];
    if (metadata is Map<String, dynamic>) {
      final event = metadata['event']?.toString().toLowerCase();
      if (event != null && event.isNotEmpty) {
        return event;
      }
    }
    return item['type']?.toString().toLowerCase() ??
        item['source']?.toString().toLowerCase() ??
        '';
  }

  String _notificationGroupKey(Map<String, dynamic> item) {
    final title = item['title']?.toString().toLowerCase() ?? '';
    final body = item['body']?.toString().toLowerCase() ??
        item['message']?.toString().toLowerCase() ??
        '';
    final type = _notificationType(item);

    if (title.contains('login') ||
        body.contains('login') ||
        type.contains('login')) {
      return 'login';
    }
    if (title.contains('transfer') ||
        body.contains('transfer') ||
        body.contains('received') ||
        body.contains('sent') ||
        type.contains('transfer') ||
        type.contains('payment')) {
      return 'transfer';
    }
    if (title.contains('deposit') ||
        body.contains('deposit') ||
        type.contains('deposit')) {
      return 'deposit';
    }
    if (title.contains('withdraw') ||
        body.contains('withdraw') ||
        type.contains('withdraw')) {
      return 'withdrawal';
    }
    if (title.contains('kyc') || body.contains('kyc') || type.contains('kyc')) {
      return 'kyc';
    }
    return 'general';
  }

  String _notificationGroupLabel(String key) {
    switch (key) {
      case 'login':
        return 'Login Alerts';
      case 'transfer':
        return 'Transfers';
      case 'deposit':
        return 'Deposits';
      case 'withdrawal':
        return 'Withdrawals';
      case 'kyc':
        return 'KYC Updates';
      default:
        return 'General Notifications';
    }
  }

  String _groupPreview(List<Map<String, dynamic>> items, String key) {
    final latest = items.first;
    final body =
        latest['body']?.toString() ?? latest['message']?.toString() ?? '';
    if (key == 'transfer') {
      if (body.isNotEmpty) {
        return '$body Balance is just like normal money.';
      }
      return 'You have received money from another user. Balance is just like normal money.';
    }
    if (key == 'login') {
      return 'New login detected. Tap to review recent account access.';
    }
    if (key == 'deposit') {
      return body.isNotEmpty
          ? '$body Balance is just like normal money.'
          : 'Deposit completed. Balance is just like normal money.';
    }
    if (key == 'withdrawal') {
      return body.isNotEmpty
          ? '$body Your remaining balance is normal money.'
          : 'Withdrawal processed. Funds moved from your account.';
    }
    if (key == 'kyc') {
      return 'KYC status updated. Tap to view the latest verification result.';
    }
    return body.isNotEmpty
        ? body
        : latest['title']?.toString() ?? 'Notification';
  }

  String _notificationId(Map<String, dynamic> item) =>
      item['id']?.toString() ?? '';

  void _onNotificationReceived() {
    if (!mounted) return;
    loadNotifications();
  }

  @override
  void dispose() {
    NotificationService.notificationReceived
        .removeListener(_onNotificationReceived);
    super.dispose();
  }

  String _displayDateTime(Map<String, dynamic> item) {
    final createdAt = item['created_at'] ?? item['createdAt'];
    DateTime? parsedDate;
    if (createdAt is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is String) {
      parsedDate = DateTime.tryParse(createdAt);
    }
    if (parsedDate == null) {
      return '';
    }
    final localDate = parsedDate.toLocal();
    final month = _monthName(localDate.month);
    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final minutes = localDate.minute.toString().padLeft(2, '0');
    final suffix = localDate.hour >= 12 ? 'PM' : 'AM';
    return '$month ${localDate.day}, $hour:$minutes $suffix';
  }

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      default:
        return 'Dec';
    }
  }

  Future<void> _confirmDeleteNotifications(
    List<Map<String, dynamic>> itemsToDelete, {
    required String title,
    required String message,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    for (final item in itemsToDelete) {
      final id = _notificationId(item);
      if (id.isNotEmpty) {
        try {
          await ApiService.deleteNotification(notificationId: id);
        } catch (_) {
          hiddenNotificationIds.add(id);
        }
      }
    }

    if (mounted) {
      await loadNotifications();
    }
  }

  Future<void> _showNotificationActions(
    List<Map<String, dynamic>> items, {
    required bool isGroup,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryText,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.done_all_rounded),
                title: const Text('Mark all as read'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await markAllRead();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title:
                    Text(isGroup ? 'Delete this group' : 'Delete notification'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeleteNotifications(
                    items,
                    title:
                        isGroup ? 'Delete this group?' : 'Delete notification?',
                    message: isGroup
                        ? 'All notifications in this group will be permanently deleted.'
                        : 'This notification will be permanently deleted.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Delete all notifications'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _confirmDeleteAllNotifications();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAllNotifications() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all notifications?'),
        content: const Text(
          'Every notification will be permanently deleted from your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await ApiService.deleteAllNotifications();
      hiddenNotificationIds.clear();
      await loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete notifications: ${userErrorMessage(e)}')),
      );
    }
  }

  Future<void> _showGroupDetails(
    List<Map<String, dynamic>> items,
    String groupLabel,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryText,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      groupLabel,
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final unreadItems = items.where((item) {
                        final read = item['read'] is bool
                            ? item['read'] as bool
                            : item['is_read'] is bool
                                ? item['is_read'] as bool
                                : item['isRead'] is bool
                                    ? item['isRead'] as bool
                                    : false;
                        return !read;
                      }).toList();
                      if (unreadItems.isNotEmpty) {
                        await Future.wait(
                          unreadItems.map((item) async {
                            if (item['id'] != null) {
                              await markNotificationRead(item['id'].toString());
                            }
                          }),
                        );
                        if (mounted) {
                          await loadNotifications();
                        }
                      }
                    },
                    child: Text(
                      'Mark Group Read',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: FlutterFlowTheme.of(context).primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final title = item['title']?.toString() ?? 'Notification';
                    final body = item['body']?.toString() ??
                        item['message']?.toString() ??
                        '';
                    final timestamp = _displayDateTime(item);
                    final isRead = item['read'] is bool
                        ? item['read'] as bool
                        : item['is_read'] is bool
                            ? item['is_read'] as bool
                            : item['isRead'] is bool
                                ? item['isRead'] as bool
                                : false;
                    return Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onLongPress: () => _showNotificationActions(
                          [item],
                          isGroup: false,
                        ),
                        onTap: () async {
                          if (!isRead && item['id'] != null) {
                            await markNotificationRead(item['id'].toString());
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Unread',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                body,
                                style: FlutterFlowTheme.of(context).bodyMedium,
                              ),
                              if (timestamp.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  timestamp,
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
    await loadNotifications();
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await ApiService.markNotificationRead(notificationId: id);
      await loadNotifications();
    } catch (_) {
      // ignore errors; this is best effort
    }
  }

  Future<void> markAllRead() async {
    try {
      await ApiService.markAllNotificationsRead();
      await loadNotifications();
    } catch (_) {
      // ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        leading: const BackChevron(),
        title: Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: markAllRead,
              child: Text(
                'Mark All Read',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: isLoading && notifications.isEmpty
            ? Center(child: CircularProgressIndicator())
            : errorMessage != null && notifications.isEmpty
                ? Center(
                    child: Text(
                      errorMessage!,
                      style: FlutterFlowTheme.of(context).bodyMedium,
                    ),
                  )
                : notifications.isEmpty
                    ? Center(
                        child: Text(
                          'No notifications yet.',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadNotifications,
                        child: ListView.separated(
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemCount: groupedNotifications.length,
                          itemBuilder: (context, index) {
                            final group = groupedNotifications[index];
                            final items = (group['items'] as List)
                                .cast<Map<String, dynamic>>();
                            final groupKey = group['key'] as String;
                            final groupLabel = group['label'] as String;
                            final groupCount = items.length;
                            final preview = _groupPreview(items, groupKey);
                            final latestTimestamp =
                                _displayDateTime(items.first);
                            return Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onLongPress: () => _showNotificationActions(
                                  items,
                                  isGroup: true,
                                ),
                                onTap: () =>
                                    _showGroupDetails(items, groupLabel),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$groupLabel ($groupCount)',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .override(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        preview,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium,
                                      ),
                                      if (latestTimestamp.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          latestTimestamp,
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to read more',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            groupLabel,
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
