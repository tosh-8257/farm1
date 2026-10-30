import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
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
    FFAppState.reset();
    await FFAppState().initializePersistedState();
  });

  test('429 responses provide a readable message and retry delay', () async {
    var requestCount = 0;
    ApiService.client = MockClient((_) async {
      requestCount++;
      return http.Response(
        jsonEncode({'message': 'ThrottlerException: Too Many Requests'}),
        429,
        headers: {'retry-after': '30'},
      );
    });

    try {
      await ApiService.request(method: 'GET', path: '/transactions');
      fail('Expected a rate-limit exception.');
    } on ApiServiceException catch (error) {
      expect(error.statusCode, 429);
      expect(error.retryAfterSeconds, 30);
      expect(error.toString(), contains('wait 30 seconds'));
      expect(error.toString(), isNot(contains('ThrottlerException')));
    }

    expect(requestCount, 1);
  });
}
