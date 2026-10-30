import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:farm/services/auth/refresh_manager.dart';
import 'package:farm/app_state.dart';
import 'package:farm/services/auth/session_store_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RefreshManager concurrency', () {
    setUp(() async {
      // Initialize dotenv for Env.api resolution used by RefreshManager.
      dotenv.loadFromString(isOptional: true);
      dotenv.env['API_URL'] = 'http://127.0.0.1:3000';
      // Ensure clean app state and empty SharedPreferences
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      FFAppState.reset();
      // ensure role and persisted session key exist
      await AuthSessionStore.saveRoleSession(
        role: 'user',
        accessToken: '',
        refreshToken: 'initial-refresh-token',
        userId: 'test-user',
      );
      // make role known to in-memory state
      FFAppState().role = 'user';
      FFAppState().accessToken = '';
      FFAppState().refreshToken = 'initial-refresh-token';
    });

    test('only one refresh request is performed for concurrent calls', () async {
      var refreshCallCount = 0;

      // Mock client will respond to POST /auth/refresh with a new token
      final mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCallCount += 1;
          // simulate slight delay to allow concurrency window
          await Future.delayed(const Duration(milliseconds: 200));

          final responsePayload = {
            'data': {
              'access_token': 'new-access-token-${refreshCallCount}',
              'refresh_token': 'new-refresh-token-${refreshCallCount}',
            }
          };
          return http.Response(jsonEncode(responsePayload), 200, headers: {
            'content-type': 'application/json'
          });
        }
        return http.Response('not found', 404);
      });

      // Replace the RefreshManager client with our mock
      RefreshManager.client = mockClient;

      // Fire multiple concurrent refresh requests
      final futures = List.generate(6, (_) => RefreshManager().refreshIfNeeded(force: true));

      final results = await Future.wait(futures);

      // All should have completed and returned true
      expect(results.every((r) => r == true), isTrue);
      // Only one underlying HTTP refresh call should have been made
      expect(refreshCallCount, equals(1));

      // And FFAppState should have the refreshed tokens
      expect(FFAppState().accessToken.startsWith('new-access-token-'), isTrue);
      expect(FFAppState().refreshToken.startsWith('new-refresh-token-'), isTrue);
    });
  });
}
