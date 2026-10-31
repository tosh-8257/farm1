
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '/pages/devices/trusted_devices_page.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_util.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Android and iOS display notification payloads automatically while the app
  // is backgrounded. Keep this handler registered for data-only messages.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  // Notifier to signal when a new notification arrives or a pending tap is available.
  // Widgets can add/remove listeners via `NotificationService.notificationReceived.addListener(...)`.
  static final ValueNotifier<int> notificationReceived = ValueNotifier<int>(0);

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Map<String, dynamic>? _pendingTapPayload;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _initializeLocalNotifications();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _messaging.onTokenRefresh.listen((token) async {
      await _storeToken(token);
      await registerForCurrentUser(token: token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _pendingTapPayload = _payloadFromMessage(initialMessage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatePendingTap();
      });
    }

    await registerForCurrentUser();
  }

  static Future<void> registerForCurrentUser({String? token}) async {
    if (kIsWeb || FFAppState().accessToken.isEmpty) return;
    try {
      final resolvedToken = token ?? await _messaging.getToken();
      if (resolvedToken == null || resolvedToken.isEmpty) return;
      await _storeToken(resolvedToken);
      await ApiService.registerDeviceToken(
        token: resolvedToken,
        platform: defaultTargetPlatform.name,
      );
    } catch (e) {
      debugPrint('[NotificationService] Token registration failed: $e');
    }
  }

  static Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_device_token', token);
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          _handlePayload(jsonDecode(payload) as Map<String, dynamic>);
        } catch (_) {
          _handlePayload({'type': 'general'});
        }
      },
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'farm_notifications',
        'FARM notifications',
        description: 'FARM account and transaction notifications',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = _payloadFromMessage(message);
    if (message.data['type'] == 'device_approval') {
      _promptDeviceApproval(message.notification?.body);
    }
    FFAppState().unreadNotificationCount =
        FFAppState().unreadNotificationCount + 1;

    // Notify listeners that a new notification has been received.
    try {
      notificationReceived.value = notificationReceived.value + 1;
    } catch (_) {}

    if (kIsWeb) return;
    final notification = message.notification;
    final title = notification?.title ?? payload['title']?.toString() ?? 'FARM';
    final body = notification?.body ?? payload['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final displayTitle = title.isNotEmpty ? title : 'FARM';
    final displayBody = body.isNotEmpty ? body : 'You have a new notification';
    final summary = payload['type']?.toString().contains('transfer') == true
        ? 'Transfer update'
        : 'New update';

    await _localNotifications.show(
      id: message.hashCode,
      title: displayTitle,
      body: displayBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'farm_notifications',
          'FARM notifications',
          channelDescription: 'FARM account and transaction notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            displayBody,
            contentTitle: displayTitle,
            summaryText: summary,
          ),
          category: AndroidNotificationCategory.message,
          ticker: displayTitle,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload),
    );
  }

  static Map<String, dynamic> _payloadFromMessage(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      if (message.notification?.title != null)
        'title': message.notification!.title,
      if (message.notification?.body != null)
        'body': message.notification!.body,
    };
  }

  static void _handleMessageTap(RemoteMessage message) {
    _handlePayload(_payloadFromMessage(message));
  }

  static void _handlePayload(Map<String, dynamic> payload) {
    _pendingTapPayload = payload;
    _navigatePendingTap();
    // Notify listeners that a pending payload/tap is available.
    try {
      notificationReceived.value = notificationReceived.value + 1;
    } catch (_) {}
  }

  /// "Approve new device" prompt on the trusted phone while FARM is open.
  static void _promptDeviceApproval(String? body) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Approve new device?'),
        content: Text(body ?? 'A new device is trying to sign in to FARM.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrustedDevicesPage()),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  static void _navigatePendingTap() {
    final payload = _pendingTapPayload;
    final context = appNavigatorKey.currentContext;
    if (payload == null || context == null) return;

    final metadata = payload['metadata'];
    final type = metadata is Map<String, dynamic>
        ? metadata['event']?.toString().toLowerCase() ?? payload['type']?.toString().toLowerCase() ?? 'general'
        : payload['type']?.toString().toLowerCase() ?? 'general';
    if (type == 'device_approval') {
      _pendingTapPayload = null;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TrustedDevicesPage()));
      return;
    }
    String route;
    if (type.contains('transfer')) {
      route = '/allTransactions';
    } else if (type.contains('request')) {
      route = '/incoming-requests';
    } else if (type.contains('deposit')) {
      route = '/depositpage';
    } else if (type.contains('withdraw')) {
      route = '/withdrawpage';
    } else if (type.contains('merchant')) {
      route = '/merchantSales';
    } else {
      route = '/user-notifications';
    }

    context.go(route);
    _pendingTapPayload = null;
  }
}