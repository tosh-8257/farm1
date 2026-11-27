import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/services/app_error_handler.dart';
import 'package:farm/services/auth/biometric_session.dart';
import 'package:farm/services/auth/refresh_manager.dart';
import 'package:farm/services/auth/session_store_service.dart';
import 'package:farm/services/auth/session_token.dart';
import 'package:farm/services/secure_storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt({required int secondsFromNow}) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final exp = DateTime.now()
          .toUtc()
          .add(Duration(seconds: secondsFromNow))
          .millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url.encode(utf8.encode('{"exp":$exp,"sub":"user-1"}'));
  return '$header.$payload.sig';
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
    AppErrorHandler.resetForTests();
  });

  test('an expired access token is not a live session', () {
    expect(accessTokenIsLive(''), isFalse);
    expect(accessTokenIsLive(_jwt(secondsFromNow: -120)), isFalse);
    expect(accessTokenIsLive(_jwt(secondsFromNow: 3600)), isTrue);
    expect(accessTokenIsLive('opaque-token'), isTrue);
  });

  test('SMS sign-in stays reachable while a biometric session is dead', () {
    expect(smsSignInPath('/loginpage'), isTrue);
    expect(smsSignInPath('/otp'), isTrue);
    expect(smsSignInPath('/dashboard'), isFalse);
  });

  test('biometric users with a dead access token must renew before the app', () {
    final expired = _jwt(secondsFromNow: -120);
    expect(
      mustRenewBiometricSession(
        biometricsAllowed: true,
        needsBiometricReauth: false,
        accessToken: expired,
        refreshToken: 'refresh',
      ),
      isTrue,
    );
    expect(
      mustRenewBiometricSession(
        biometricsAllowed: true,
        needsBiometricReauth: true,
        accessToken: _jwt(secondsFromNow: 3600),
        refreshToken: 'refresh',
      ),
      isTrue,
    );
    expect(
      mustRenewBiometricSession(
        biometricsAllowed: false,
        needsBiometricReauth: true,
        accessToken: expired,
        refreshToken: 'refresh',
      ),
      isFalse,
    );
  });

  test('nested refresh payloads still yield both tokens', () {
    final payload = refreshTokenPayload({
      'success': true,
      'data': {
        'data': {
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
        },
      },
    });
    expect(stringField(payload, const ['access_token', 'accessToken']), 'access-1');
    expect(
      stringField(payload, const ['refresh_token', 'refreshToken']),
      'refresh-1',
    );
    expect(asStringKeyMap('nope'), isNull);
    expect(asStringKeyMap({'a': 1})?['a'], 1);
  });

  test('biometric renewal rotates and persists a live access token', () async {
    final expired = _jwt(secondsFromNow: -300);
    final fresh = _jwt(secondsFromNow: 3600);
    await AuthSessionStore.saveUserSession(
      accessToken: expired,
      refreshToken: 'stored-refresh',
      role: 'user',
      userId: 'user-1',
    );
    FFAppState().accessToken = expired;
    FFAppState().refreshToken = 'stored-refresh';
    FFAppState().role = 'user';
    FFAppState().userId = 'user-1';
    FFAppState().isLoggedIn = true;
    FFAppState().biometricsEnabled = true;
    FFAppState().needsBiometricReauth = true;

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        expect(request.body, contains('stored-refresh'));
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': fresh,
              'refresh_token': 'rotated-refresh',
            },
          }),
          200,
        );
      }
      return http.Response('not found', 404);
    });
    ApiService.client = mock;
    RefreshManager.client = mock;

    expect(await BiometricSession.renewStoredSession(), isTrue);
    expect(FFAppState().accessToken, fresh);
    expect(FFAppState().refreshToken, 'rotated-refresh');
    expect(FFAppState().needsBiometricReauth, isFalse);
    expect(FFAppState().isLoggedIn, isTrue);
    expect(accessTokenIsLive(FFAppState().accessToken), isTrue);
    final stored = await AuthSessionStore.readUserSession();
    expect(stored?.refreshToken, 'rotated-refresh');
    expect(await SecureStorageService.readRefreshToken(), 'rotated-refresh');
  });

  test('a failed biometric renewal keeps the refresh token and blocks the UI',
      () async {
    final expired = _jwt(secondsFromNow: -300);
    FFAppState().accessToken = expired;
    FFAppState().refreshToken = 'stored-refresh';
    FFAppState().role = 'user';
    FFAppState().userId = 'user-1';
    FFAppState().isLoggedIn = true;
    FFAppState().biometricsEnabled = true;

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/session/config')) {
        return http.Response(
          jsonEncode({'data': {'biometric_reauth': false}}),
          200,
        );
      }
      return http.Response(
        jsonEncode({'message': 'Session not found or expired'}),
        401,
      );
    });
    ApiService.client = mock;
    RefreshManager.client = mock;

    expect(await BiometricSession.renewStoredSession(), isFalse);
    expect(FFAppState().refreshToken, 'stored-refresh');
    expect(FFAppState().needsBiometricReauth, isTrue);
    expect(FFAppState().isLoggedIn, isTrue);
    expect(accessTokenIsLive(FFAppState().accessToken), isFalse);
    expect(
      mustRenewBiometricSession(
        biometricsAllowed: true,
        needsBiometricReauth: FFAppState().needsBiometricReauth,
        accessToken: FFAppState().accessToken,
        refreshToken: FFAppState().refreshToken,
      ),
      isTrue,
    );
  });

  test('a refresh race is not treated as a live session', () async {
    FFAppState().accessToken = _jwt(secondsFromNow: -30);
    FFAppState().refreshToken = 'used-refresh';
    FFAppState().role = 'user';
    FFAppState().biometricsEnabled = true;
    FFAppState().isLoggedIn = true;

    RefreshManager.client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'message': 'Refresh already in progress. Retry with the latest token.',
        }),
        401,
      );
    });

    expect(await RefreshManager().refreshIfNeeded(force: true), isFalse);
    expect(FFAppState().refreshToken, 'used-refresh');
    expect(FFAppState().needsBiometricReauth, isTrue);
  });

  test('a forced refresh ignores the failure backoff', () async {
    var calls = 0;
    FFAppState().accessToken = 'old';
    FFAppState().refreshToken = 'refresh';
    FFAppState().role = 'user';
    RefreshManager.client = MockClient((request) async {
      calls++;
      if (calls == 1) {
        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }
      return http.Response(
        jsonEncode({
          'data': {
            'access_token': _jwt(secondsFromNow: 900),
            'refresh_token': 'refresh-2',
          },
        }),
        200,
      );
    });

    expect(await RefreshManager().refreshIfNeeded(force: true), isFalse);
    expect(
      await RefreshManager().refreshIfNeeded(force: true, endSession: false),
      isTrue,
    );
    expect(calls, 2);
    expect(FFAppState().refreshToken, 'refresh-2');
  });

  test('cold start prefers the keystore refresh token over a stale role copy',
      () async {
    await AuthSessionStore.saveUserSession(
      accessToken: _jwt(secondsFromNow: -60),
      refreshToken: 'stale-refresh',
      role: 'user',
      userId: 'user-1',
    );
    final fresh = _jwt(secondsFromNow: 900);
    await SecureStorageService.writeAccessToken(fresh);
    await SecureStorageService.writeRefreshToken('rotated-in-keystore');
    await SecureStorageService.writeUserId('user-1');

    FFAppState.reset();
    await FFAppState().initializePersistedState();

    expect(FFAppState().refreshToken, 'rotated-in-keystore');
    expect(FFAppState().accessToken, fresh);
    expect(FFAppState().isLoggedIn, isTrue);
    expect((await AuthSessionStore.readUserSession())?.refreshToken,
        'rotated-in-keystore');
  });

  test('one 401 is retried after a single refresh', () async {
    var profileCalls = 0;
    var refreshCalls = 0;
    final oldToken = _jwt(secondsFromNow: -10);
    final newToken = _jwt(secondsFromNow: 900);
    FFAppState().accessToken = oldToken;
    FFAppState().refreshToken = 'refresh';
    FFAppState().role = 'user';
    FFAppState().biometricsEnabled = true;

    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        return http.Response(
          jsonEncode({
            'data': {
              'access_token': newToken,
              'refresh_token': 'refresh-next',
            },
          }),
          200,
        );
      }
      profileCalls++;
      final auth = request.headers['Authorization'];
      if (auth == 'Bearer $oldToken') {
        return http.Response(jsonEncode({'message': 'Token has been revoked'}), 401);
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    ApiService.client = mock;
    RefreshManager.client = mock;

    final result = await ApiService.request(method: 'GET', path: '/users/me');
    expect(result['ok'], isTrue);
    expect(refreshCalls, 1);
    expect(profileCalls, 2);
    expect(FFAppState().accessToken, newToken);
    expect(FFAppState().needsBiometricReauth, isFalse);
  });

  test('friendly errors stay on screen instead of closing the app', () {
    expect(friendlyErrorText, contains('try again'));
    expect(friendlyErrorSnack, contains('try again'));
    AppErrorHandler.report(StateError('boom'), StackTrace.empty);
    AppErrorHandler.report(StateError('boom again'), StackTrace.empty);
  });
}
