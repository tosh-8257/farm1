import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '/pages/devices/trusted_devices_page.dart';

import '/backend/services/api_service.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/auth/session_end.dart';
import '/services/push_session_policy.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The system may already have displayed a notification payload. If this
  // install is signed out, or the payload names another account, clear it.
  try {
    final prefs = await SharedPreferences.getInstance();
    final drop = shouldClearBackgroundPush(
      sessionActive: prefs.containsKey(pushSessionActiveKey)
          ? prefs.getBool(pushSessionActiveKey)
          : null,
      boundUserId: prefs.getString(pushBoundUserKey) ?? '',
      data: Map<String, dynamic>.from(message.data),
    );
    if (!drop) return;
    await FlutterLocalNotificationsPlugin().cancelAll();
  } catch (_) {}
}

class NotificationService {
  NotificationService._();

  static final ValueNotifier<int> notificationReceived = ValueNotifier<int>(0);

  static FirebaseMessaging? _messaging;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _registrationSuspended = false;
  static Map<String, dynamic>? _pendingTapPayload;

  /// Test seams. Production leaves these null and uses Firebase.
  @visibleForTesting
  static Future<String?> Function()? debugReadToken;

  @visibleForTesting
  static Future<void> Function()? debugDeleteToken;

  @visibleForTesting
  static Future<void> Function()? debugCancelNotifications;

  static bool get registrationSuspended => _registrationSuspended;

  static FirebaseMessaging get _firebase {
    return _messaging ??= FirebaseMessaging.instance;
  }

  /// Wires local notification cleanup into session revocation.
  static void bindSessionEnd() {
    SessionEnd.onBeforeClear = invalidateLocalPush;
  }

  static void suspendPushRegistration() {
    _registrationSuspended = true;
  }

  static void resumePushRegistration() {
    _registrationSuspended = false;
  }

  @visibleForTesting
  static void resetForTest() {
    debugReadToken = null;
    debugDeleteToken = null;
    debugCancelNotifications = null;
    _registrationSuspended = false;
    _pendingTapPayload = null;
    _initialized = false;
  }

  static Future<void> initialize() async {
    bindSessionEnd();
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _initializeLocalNotifications();
      await _firebase.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _firebase.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _firebase.onTokenRefresh.listen((token) async {
      await handleTokenRefresh(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initialMessage = await _firebase.getInitialMessage();
    if (initialMessage != null) {
      final payload = _payloadFromMessage(initialMessage);
      if (_canPresent(payload)) {
        _pendingTapPayload = payload;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatePendingTap();
        });
      }
    }

    await registerForCurrentUser();
  }

  /// FCM rotation. No-op while signed out so a deleted token cannot be
  /// registered back onto the previous account.
  static Future<void> handleTokenRefresh(String token) async {
    if (!_canRegisterPush) return;
    if (token.isEmpty) return;
    await _storeToken(token);
    await registerForCurrentUser(token: token);
  }

  static bool get _canRegisterPush =>
      !_registrationSuspended &&
      FFAppState().isLoggedIn &&
      FFAppState().accessToken.isNotEmpty;

  static Future<void> registerForCurrentUser({String? token}) async {
    if (!_canRegisterPush) return;
    final platform = pushPlatformName(
      isWeb: kIsWeb,
      platformName: defaultTargetPlatform.name,
    );
    if (platform == null) return;
    try {
      final resolvedToken = token ?? await _readRemoteToken();
      if (resolvedToken == null || resolvedToken.isEmpty) return;
      await _storeToken(resolvedToken);
      await ApiService.registerDeviceToken(
        token: resolvedToken,
        platform: platform,
      );
      await _markPushSession(FFAppState().userId);
    } catch (e) {
      debugPrint(
          '[NotificationService] Token registration failed (${e.runtimeType})');
    }
  }

  static Future<String?> currentPushToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(pushTokenPrefsKey);
      if (stored != null && stored.isNotEmpty) return stored;
    } catch (_) {}
    return _readRemoteToken();
  }

  /// Drops the device token and the tray. Safe to call more than once.
  static Future<void> invalidateLocalPush() async {
    suspendPushRegistration();
    _pendingTapPayload = null;
    await _deleteRemoteToken();
    await cancelDisplayedNotifications();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(pushTokenPrefsKey);
      await prefs.setBool(pushSessionActiveKey, false);
      await prefs.remove(pushBoundUserKey);
    } catch (_) {}
  }

  static Future<void> cancelDisplayedNotifications() async {
    final override = debugCancelNotifications;
    if (override != null) {
      await override();
      return;
    }
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }

  static Future<String?> _readRemoteToken() async {
    final override = debugReadToken;
    if (override != null) return override();
    try {
      return await _firebase.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteRemoteToken() async {
    final override = debugDeleteToken;
    if (override != null) {
      await override();
      return;
    }
    try {
      await _firebase.deleteToken();
    } catch (_) {}
  }

  static Future<void> _storeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pushTokenPrefsKey, token);
  }

  static Future<void> _markPushSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pushSessionActiveKey, true);
    if (userId.isNotEmpty) {
      await prefs.setString(pushBoundUserKey, userId);
    }
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
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _handlePayload(decoded);
          } else if (decoded is Map) {
            _handlePayload(Map<String, dynamic>.from(decoded));
          }
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

  static bool _canPresent(Map<String, dynamic> payload) {
    return shouldPresentPush(
      loggedIn: FFAppState().isLoggedIn && FFAppState().accessToken.isNotEmpty,
      currentUserId: FFAppState().userId,
      payload: payload,
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final payload = _payloadFromMessage(message);
    if (!_canPresent(payload)) return;
    if (message.data['type'] == 'device_approval') {
      _promptDeviceApproval(message.notification?.body);
    }
    FFAppState().unreadNotificationCount =
        FFAppState().unreadNotificationCount + 1;

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
    if (!_canPresent(payload)) return;
    _pendingTapPayload = payload;
    _navigatePendingTap();
    try {
      notificationReceived.value = notificationReceived.value + 1;
    } catch (_) {}
  }

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
    if (!_canPresent(payload)) {
      _pendingTapPayload = null;
      return;
    }

    final metadata = payload['metadata'];
    final type = metadata is Map
        ? metadata['event']?.toString().toLowerCase() ??
            payload['type']?.toString().toLowerCase() ??
            'general'
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
    } else if (type.contains('escrow')) {
      route = '/user-notifications';
    } else {
      route = '/user-notifications';
    }

    context.go(route);
    _pendingTapPayload = null;
  }
}
