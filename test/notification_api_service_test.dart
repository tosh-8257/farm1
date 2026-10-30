import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/services/auth/refresh_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    RefreshManager().reset();
  });

  test('uses the notifications endpoint for read-all and delete-all operations', () async {
    FFAppState().accessToken = 'token';

    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/notifications/read-all')) {
        expect(request.method, 'PATCH');
        return http.Response(jsonEncode({'message': 'All notifications marked as read'}), 200);
      }

      if (request.url.path.endsWith('/notifications')) {
        expect(request.method, 'DELETE');
        return http.Response(jsonEncode({'message': 'All notifications deleted'}), 200);
      }

      return http.Response('not found', 404);
    });

    ApiService.client = mockClient;

    final readAllResult = await ApiService.markAllNotificationsRead();
    final deleteAllResult = await ApiService.deleteAllNotifications();

    expect(readAllResult['message'], 'All notifications marked as read');
    expect(deleteAllResult['message'], 'All notifications deleted');
  });
}
