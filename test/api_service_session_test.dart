import 'dart:convert';
import 'dart:typed_data';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/services/auth/refresh_manager.dart';
import 'package:farm/services/auth/route_guard_service.dart';
import 'package:farm/services/auth/session_store_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _makeJwt(DateTime expiry) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode('{"exp":${expiry.millisecondsSinceEpoch ~/ 1000}}'),
  );
  return '$header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(isOptional: true);
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    RefreshManager().reset();
  });

  test('preserves existing auth state when refresh is rejected', () async {
    const existingToken = 'still-valid-token';

    await AuthSessionStore.saveUserSession(
      accessToken: existingToken,
      refreshToken: 'expired-token',
      role: 'user',
      userId: 'persisted-user',
    );
    FFAppState().accessToken = existingToken;
    FFAppState().refreshToken = 'expired-token';
    FFAppState().role = 'user';
    FFAppState().userId = 'persisted-user';
    FFAppState().isLoggedIn = true;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({'message': 'Unauthorized'}),
          401,
        );
      }

      return http.Response('not found', 404);
    });

    ApiService.client = mockClient;
    RefreshManager.client = mockClient;

    final refreshed = await RefreshManager().refreshIfNeeded(force: true);

    expect(refreshed, isFalse);
    expect(FFAppState().accessToken, existingToken);
    expect(FFAppState().refreshToken, 'expired-token');
    expect(FFAppState().isLoggedIn, isTrue);
    final persistedSession = await AuthSessionStore.readUserSession();
    expect(persistedSession?.accessToken, existingToken);
    expect(persistedSession?.refreshToken, 'expired-token');
    expect(await AuthSessionStore.readActiveRole(), 'user');
  });

  test('retries a protected request after a successful refresh', () async {
    const oldToken = 'old-token';
    const refreshedToken = 'new-token';

    FFAppState().accessToken = oldToken;
    FFAppState().refreshToken = 'refresh-token';

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        expect(request.body, contains('refresh-token'));
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': refreshedToken,
              'refresh_token': 'rotated-refresh-token',
            },
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/me')) {
        final authHeader = request.headers['Authorization'];
        if (authHeader == 'Bearer $oldToken') {
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
        }
        if (authHeader == 'Bearer $refreshedToken') {
          return http.Response(jsonEncode({'ok': true}), 200);
        }
      }

      return http.Response('not found', 404);
    });

    ApiService.client = mockClient;
    RefreshManager.client = mockClient;

    final result = await ApiService.request(method: 'GET', path: '/me');

    expect(result['ok'], isTrue);
    expect(FFAppState().accessToken, refreshedToken);
    expect(FFAppState().refreshToken, 'rotated-refresh-token');
  });

  test('keeps the authenticated route when the backend rejects refresh',
      () async {
    final expiredToken = _makeJwt(
      DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
    );
    await AuthSessionStore.saveUserSession(
      accessToken: expiredToken,
      refreshToken: 'rejected-refresh-token',
      role: 'user',
      userId: 'persistent-user',
    );
    FFAppState().accessToken = expiredToken;
    FFAppState().refreshToken = 'rejected-refresh-token';
    FFAppState().role = 'user';
    FFAppState().userId = 'persistent-user';
    FFAppState().isLoggedIn = true;

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({'message': 'Unauthorized'}),
          401,
        );
      }
      return http.Response('not found', 404);
    });
    ApiService.client = mockClient;
    RefreshManager.client = mockClient;

    expect(await RouteGuardService().isUserAuthenticated(), isTrue);
    expect(FFAppState().isLoggedIn, isTrue);
    expect(FFAppState().role, 'user');
    expect((await AuthSessionStore.readUserSession())?.refreshToken,
        'rejected-refresh-token');
  });

  test('a 403 does not sign the user out', () async {
    FFAppState().accessToken = 'access';
    FFAppState().refreshToken = 'refresh';
    FFAppState().isLoggedIn = true;
    FFAppState().role = 'user';
    RefreshManager.client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'Session not found or expired'}),
        403,
      );
    });

    final refreshed = await RefreshManager().refreshIfNeeded(force: true);

    expect(refreshed, isFalse);
    expect(RefreshManager().lastFailureWasTerminal, isFalse);
    expect(FFAppState().isLoggedIn, isTrue);
    expect(FFAppState().accessToken, 'access');
    expect(FFAppState().refreshToken, 'refresh');
  });

  test('biometrics keep the session after a revoked refresh', () async {
    FFAppState().accessToken = 'access';
    FFAppState().refreshToken = 'refresh';
    FFAppState().isLoggedIn = true;
    FFAppState().role = 'user';
    FFAppState().biometricsEnabled = true;
    RefreshManager.client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'Session not found or expired'}),
        401,
      );
    });

    final refreshed = await RefreshManager().refreshIfNeeded(force: true);

    expect(refreshed, isFalse);
    expect(FFAppState().isLoggedIn, isTrue);
    expect(FFAppState().accessToken, 'access');
    expect(FFAppState().refreshToken, 'refresh');
    expect(FFAppState().needsBiometricReauth, isTrue);
    expect(FFAppState().biometricsEnabled, isTrue);
  });

  test('a failed image upload does not sign the user out', () async {
    FFAppState().accessToken = 'access';
    FFAppState().refreshToken = 'refresh';
    FFAppState().isLoggedIn = true;
    FFAppState().role = 'user';
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          jsonEncode({'message': 'Session not found or expired'}),
          401,
        );
      }
      return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
    });
    ApiService.client = mock;
    RefreshManager.client = mock;

    await expectLater(
      ApiService.uploadImages(
        files: [Uint8List.fromList(const [1, 2, 3])],
        filenames: const ['cover.jpg'],
        mimeTypes: const ['image/jpeg'],
      ),
      throwsA(isA<Exception>()),
    );

    expect(FFAppState().isLoggedIn, isTrue);
    expect(FFAppState().accessToken, 'access');
    expect(FFAppState().refreshToken, 'refresh');
  });
}
