import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/pages/security/session_security.dart';
import 'package:farm/pages/security/sessions_page.dart';
import 'package:farm/services/auth/auth_service.dart';
import 'package:farm/services/auth/refresh_manager.dart';
import 'package:farm/services/auth/route_guard_service.dart';
import 'package:farm/services/notification_service.dart';
import 'package:farm/services/offline_cache.dart';
import 'package:farm/services/push_session_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(isOptional: true);
    OfflineCache.resetForTest();
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    RefreshManager().reset();
    NotificationService.resetForTest();
    NotificationService.bindSessionEnd();
  });

  test('logout sends the push token and clears this device only', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pushTokenPrefsKey, 'fcm-account-a');
    FFAppState().accessToken = 'access-a';
    FFAppState().refreshToken = 'refresh-a';
    FFAppState().userId = 'user-a';
    FFAppState().role = 'user';
    FFAppState().isLoggedIn = true;
    FFAppState().firstName = 'Mkulima';
    FFAppState().email = 'mkulima@farm.app';
    FFAppState().walletBalance = 100;
    FFAppState().unreadNotificationCount = 3;
    await OfflineCache.load('user-a');
    OfflineCache.write('api:/wallet', {'balance': 100});

    var deletedToken = false;
    var cancelledNotifications = false;
    var deviceTokenPosts = 0;
    String? logoutBody;
    String? logoutAuth;
    final paths = <String>[];
    NotificationService.debugDeleteToken = () async {
      deletedToken = true;
    };
    NotificationService.debugCancelNotifications = () async {
      cancelledNotifications = true;
    };

    ApiService.client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/auth/logout')) {
        logoutBody = request.body;
        logoutAuth = request.headers['authorization'];
        return http.Response(jsonEncode({'message': 'Logged out successfully'}), 200);
      }
      if (request.url.path.endsWith('/auth/device-token')) {
        deviceTokenPosts++;
      }
      return http.Response(jsonEncode({'message': 'unexpected'}), 404);
    });

    await AuthService().logout();
    await NotificationService.handleTokenRefresh('rotated-after-logout');

    expect(paths.where((path) => path.endsWith('/auth/logout')), hasLength(1));
    expect(paths.any((path) => path.contains('revoke-all')), isFalse);
    expect(logoutAuth, 'Bearer access-a');
    expect(jsonDecode(logoutBody!)['token'], 'fcm-account-a');
    expect(FFAppState().accessToken, isEmpty);
    expect(FFAppState().refreshToken, isEmpty);
    expect(FFAppState().userId, isEmpty);
    expect(FFAppState().firstName, isEmpty);
    expect(FFAppState().email, isEmpty);
    expect(FFAppState().isLoggedIn, isFalse);
    expect(FFAppState().walletBalance, 0);
    expect(FFAppState().unreadNotificationCount, 0);
    expect(OfflineCache.read('api:/wallet'), isNull);
    expect(prefs.getString(pushTokenPrefsKey), isNull);
    expect(prefs.getBool(pushSessionActiveKey), isFalse);
    expect(deletedToken, isTrue);
    expect(cancelledNotifications, isTrue);
    expect(NotificationService.registrationSuspended, isTrue);
    expect(deviceTokenPosts, 0);
  });

  test('account switch clears A and registers the push token for B', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pushTokenPrefsKey, 'fcm-account-a');
    FFAppState().accessToken = 'access-a';
    FFAppState().refreshToken = 'refresh-a';
    FFAppState().userId = 'user-a';
    FFAppState().role = 'user';
    FFAppState().isLoggedIn = true;
    FFAppState().firstName = 'Mkulima';
    FFAppState().email = 'mkulima@farm.app';
    FFAppState().walletBalance = 80;
    await OfflineCache.load('user-a');
    OfflineCache.write('api:/wallet', {'balance': 80});

    NotificationService.debugReadToken = () async => 'fcm-account-b';
    final calls = <Map<String, String>>[];

    ApiService.client = MockClient((request) async {
      calls.add({
        'path': request.url.path,
        'auth': request.headers['authorization'] ?? '',
        'body': request.body,
      });
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': 'access-b',
              'refresh_token': 'refresh-b',
              'user': {
                'id': 'user-b',
                'role': 'user',
                'first_name': 'Gracie',
                'username': 'gracie',
              },
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/logout') ||
          request.url.path.endsWith('/auth/device-token')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      return http.Response(jsonEncode({'message': 'missing'}), 404);
    });

    final result = await AuthService().login(
      identifier: 'gracie',
      password: 'Correct-Horse-1!',
    );

    final logout = calls.firstWhere((call) => call['path']!.endsWith('/auth/logout'));
    final registration =
        calls.firstWhere((call) => call['path']!.endsWith('/auth/device-token'));
    expect(result['farmJwt'], 'access-b');
    expect(logout['auth'], 'Bearer access-a');
    expect(jsonDecode(logout['body']!)['token'], 'fcm-account-a');
    expect(registration['auth'], 'Bearer access-b');
    final registered = jsonDecode(registration['body']!);
    expect(registered['token'], 'fcm-account-b');
    expect(registered['platform'], anyOf('android', 'ios'));
    expect(FFAppState().userId, 'user-b');
    expect(FFAppState().firstName, 'Gracie');
    expect(FFAppState().email, isEmpty);
    expect(FFAppState().walletBalance, 0);
    expect(OfflineCache.read('api:/wallet'), isNull);
    expect(prefs.getString(pushBoundUserKey), 'user-b');
    expect(prefs.getBool(pushSessionActiveKey), isTrue);

    FFAppState().isLoggedIn = false;
    FFAppState().accessToken = '';
    NotificationService.suspendPushRegistration();
    final postsBefore = calls.where((call) => call['path']!.endsWith('/auth/device-token')).length;
    await NotificationService.handleTokenRefresh('should-not-register');
    final postsAfter = calls.where((call) => call['path']!.endsWith('/auth/device-token')).length;
    expect(postsAfter, postsBefore);
  });

  test('revoked or expired refresh clears the local session', () async {
    FFAppState().accessToken = 'access-a';
    FFAppState().refreshToken = 'refresh-a';
    FFAppState().userId = 'user-a';
    FFAppState().role = 'user';
    FFAppState().isLoggedIn = true;
    FFAppState().firstName = 'Mkulima';
    FFAppState().walletBalance = 40;
    await OfflineCache.load('user-a');
    OfflineCache.write('recentTransactions', [
      {'id': 'tx-a'},
    ]);
    var cancelled = false;
    NotificationService.debugCancelNotifications = () async {
      cancelled = true;
    };
    NotificationService.debugDeleteToken = () async {};

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({'message': 'Session not found or expired'}),
          401,
        );
      }
      if (request.url.path.endsWith('/wallet')) {
        return http.Response(
          jsonEncode({'message': 'Token has been revoked'}),
          401,
        );
      }
      return http.Response('not found', 404);
    });
    ApiService.client = mock;
    RefreshManager.client = mock;

    await expectLater(ApiService.getWallet(), throwsA(isA<Exception>()));

    expect(RefreshManager().lastFailureWasTerminal, isTrue);
    expect(FFAppState().accessToken, isEmpty);
    expect(FFAppState().refreshToken, isEmpty);
    expect(FFAppState().isLoggedIn, isFalse);
    expect(FFAppState().userId, isEmpty);
    expect(FFAppState().firstName, isEmpty);
    expect(FFAppState().walletBalance, 0);
    expect(OfflineCache.read('recentTransactions'), isNull);
    expect(cancelled, isTrue);
    expect(await RouteGuardService().isUserAuthenticated(), isFalse);
  });

  test('revoke session and revoke others hit the session endpoints', () async {
    FFAppState().accessToken = 'access-a';
    FFAppState().refreshToken = 'refresh-a';
    FFAppState().isLoggedIn = true;
    final paths = <String>[];
    ApiService.client = MockClient((request) async {
      paths.add('${request.method} ${request.url.path}');
      return http.Response(jsonEncode({'message': 'ok'}), 200);
    });

    await AuthService().revokeSession(sessionId: 'session-2');
    await AuthService().revokeOtherSessions();
    await ApiService.getPushDevices();

    expect(
      paths.any((path) => path.endsWith('/auth/sessions/session-2/revoke')),
      isTrue,
    );
    expect(paths.any((path) => path.endsWith('/auth/sessions/revoke-others')), isTrue);
    expect(paths.any((path) => path.endsWith('/auth/devices')), isTrue);
  });

  test('notification payloads stay on the signed-in account', () {
    const types = [
      'payment_request',
      'deposit',
      'withdrawal',
      'transfer',
      'transfer_received',
      'escrow',
      'merchant_payment',
      'security_alert',
      'kyc_update',
      'otp',
      'device_approval',
    ];
    for (final type in types) {
      expect(
        shouldPresentPush(
          loggedIn: false,
          currentUserId: '',
          payload: {'type': type, 'user_id': 'user-a'},
        ),
        isFalse,
        reason: type,
      );
      expect(
        shouldPresentPush(
          loggedIn: true,
          currentUserId: 'user-b',
          payload: {'type': type, 'user_id': 'user-a'},
        ),
        isFalse,
        reason: type,
      );
      expect(
        shouldPresentPush(
          loggedIn: true,
          currentUserId: 'user-b',
          payload: {
            'type': type,
            'metadata': jsonEncode({'accountId': 'user-a'}),
          },
        ),
        isFalse,
        reason: type,
      );
      expect(
        shouldPresentPush(
          loggedIn: true,
          currentUserId: 'user-b',
          payload: {'type': type, 'recipient_id': 'user-b'},
        ),
        isTrue,
        reason: type,
      );
      expect(
        shouldPresentPush(
          loggedIn: true,
          currentUserId: 'user-b',
          payload: {'type': type},
        ),
        isTrue,
        reason: type,
      );
    }

    expect(
      shouldClearBackgroundPush(
        sessionActive: false,
        boundUserId: 'user-a',
        data: {'type': 'payment_request'},
      ),
      isTrue,
    );
    expect(
      shouldClearBackgroundPush(
        sessionActive: true,
        boundUserId: 'user-b',
        data: {'type': 'transfer', 'userId': 'user-a'},
      ),
      isTrue,
    );
    expect(
      shouldClearBackgroundPush(
        sessionActive: true,
        boundUserId: 'user-b',
        data: {'type': 'deposit'},
      ),
      isFalse,
    );
    expect(isTerminalSessionFailure('Unauthorized'), isFalse);
    expect(isTerminalSessionFailure('Session not found or expired'), isTrue);
    expect(isTerminalSessionFailure('Token has been revoked'), isTrue);
    expect(
      isTerminalSessionFailure('Refresh already in progress. Retry with the latest token.'),
      isFalse,
    );
    expect(pushPlatformName(isWeb: false, platformName: 'iOS'), 'ios');
    expect(pushPlatformName(isWeb: true, platformName: 'android'), isNull);
  });

  test('session labels flag new and unrecognized devices', () {
    final now = DateTime.utc(2026, 6, 1, 12);
    final current = {
      'id': 'here',
      'is_current': true,
      'ip_address': '198.51.100.10',
      'device_name': 'Pixel',
      'created_at': now.subtract(const Duration(days: 3)).toIso8601String(),
    };
    expect(
      sessionAttention(
        {
          'device_name': 'Unknown device',
          'is_current': false,
          'created_at': now.toIso8601String(),
        },
        current: current,
        now: now,
      ),
      'Unrecognized',
    );
    expect(
      sessionAttention(
        {
          'device_name': 'Someone else',
          'device_os': 'iOS',
          'ip_address': '203.0.113.8',
          'is_current': false,
          'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        current: current,
        now: now,
      ),
      'Suspicious',
    );
    expect(
      sessionAttention(
        {
          'device_name': 'Tablet',
          'ip_address': '198.51.100.10',
          'is_current': false,
          'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        },
        current: current,
        now: now,
      ),
      'New',
    );
    expect(sessionIsActive({'is_revoked': true}), isFalse);
    expect(sessionDeviceLabel({'device_name': 'Pixel', 'device_os': 'Android'}), 'Pixel · Android');
  });

  testWidgets('devices screen lists sessions and revokes one', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FFAppState().accessToken = 'access-a';
    FFAppState().isLoggedIn = true;
    var sessionReads = 0;
    String? revokedId;
    var revokedOthers = false;
    ApiService.client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/sessions') && request.method == 'GET') {
        sessionReads++;
        final sessions = [
          {
            'id': 'here',
            'device_name': 'Pixel',
            'device_os': 'Android 14',
            'ip_address': '198.51.100.10',
            'is_current': true,
            'is_revoked': false,
            'is_expired': false,
            'push_registered': true,
            'last_active_at': '2026-06-01T12:00:00Z',
            'created_at': '2026-05-01T12:00:00Z',
          },
          if (revokedId != 'other' && !revokedOthers)
            {
              'id': 'other',
              'device_name': 'Unknown device',
              'device_os': 'iOS',
              'ip_address': '203.0.113.8',
              'is_current': false,
              'is_revoked': false,
              'is_expired': false,
              'push_registered': true,
              'last_active_at': '2026-06-01T11:00:00Z',
              'created_at': '2026-06-01T11:00:00Z',
            },
          if (!revokedOthers)
            {
              'id': 'tablet',
              'device_name': 'iPad',
              'device_os': 'iPadOS',
              'ip_address': '198.51.100.20',
              'is_current': false,
              'is_revoked': false,
              'is_expired': false,
              'push_registered': false,
              'last_active_at': '2026-05-20T11:00:00Z',
              'created_at': '2026-05-20T11:00:00Z',
            },
        ];
        return http.Response(jsonEncode({'sessions': sessions}), 200);
      }
      if (request.url.path.endsWith('/auth/devices')) {
        return http.Response(
          jsonEncode({
            'devices': [
              {
                'id': 'push-1',
                'platform': 'ios',
                'is_active': true,
                'last_seen': '2026-06-01T11:00:00Z',
                'session': {
                  'device_name': 'Unknown device',
                  'device_os': 'iOS',
                  'is_current': false,
                },
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/device/list')) {
        return http.Response(
          jsonEncode({
            'data': [
              {'name': 'Home phone', 'status': 'trusted'},
            ],
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/auth/sessions/other/revoke')) {
        revokedId = 'other';
        return http.Response(jsonEncode({'message': 'Session revoked successfully'}), 200);
      }
      if (request.url.path.endsWith('/auth/sessions/revoke-others')) {
        revokedOthers = true;
        return http.Response(jsonEncode({'message': 'Other sessions revoked successfully'}), 200);
      }
      return http.Response(jsonEncode({'message': 'missing'}), 404);
    });

    await tester.pumpWidget(const MaterialApp(home: SessionsPage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Pixel · Android 14'), findsWidgets);
    expect(find.text('Unrecognized'), findsWidgets);
    expect(find.text('Push on'), findsWidgets);
    expect(find.text('Home phone'), findsOneWidget);
    expect(find.text('Sign out all other devices'), findsOneWidget);
    expect(find.text('Sign out everywhere'), findsOneWidget);

    await tester.tap(find.byKey(const Key('revoke-session-other')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this session?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(revokedId, 'other');
    expect(sessionReads, greaterThan(1));
    expect(find.text('Unrecognized'), findsNothing);

    await tester.tap(find.byKey(const Key('sign-out-other-devices')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sign out')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(revokedOthers, isTrue);
  });
}
