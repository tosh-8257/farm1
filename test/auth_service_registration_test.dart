import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/services/auth/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers through the backend without requiring Supabase', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    dotenv.loadFromString(isOptional: true);
    late http.Request capturedRequest;
    final mockClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'message': 'Registration successful. OTP sent.'}),
        201,
      );
    });
    ApiService.client = mockClient;

    final response = await AuthService().signUp(
      email: 'han@example.com',
      password: '41324177Stan.',
      firstName: 'Jan',
      lastName: 'Ntaly',
      username: 'jant',
      phone: '+254710103803',
      country: 'Kenya',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/register'));
    expect(jsonDecode(capturedRequest.body), {
      'first_name': 'Jan',
      'last_name': 'Ntaly',
      'username': 'jant',
      'phone': '+254710103803',
      'password': '41324177Stan.',
      'email': 'han@example.com',
      'country': 'Kenya',
    });
    expect(response['message'], contains('Registration successful'));
  });

  test('checks username, email, and phone availability through the backend',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    if (!dotenv.isInitialized) {
      dotenv.loadFromString(isOptional: true);
    }

    late Uri capturedUri;
    ApiService.client = MockClient((request) async {
      capturedUri = request.url;
      return http.Response(
        jsonEncode({
          'data': {
            'usernameAvailable': true,
            'emailAvailable': false,
            'phoneAvailable': true,
          },
        }),
        200,
      );
    });

    final response = await ApiService.checkRegistrationAvailability(
      username: 'farm_user',
      email: 'person@example.com',
      phone: '+254700123456',
    );

    expect(capturedUri.path, endsWith('/auth/registration-availability'));
    expect(capturedUri.queryParameters, {
      'username': 'farm_user',
      'email': 'person@example.com',
      'phone': '+254700123456',
    });
    expect(response['data']['emailAvailable'], false);
  });
}