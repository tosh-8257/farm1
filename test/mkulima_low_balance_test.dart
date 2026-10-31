import 'dart:convert';

import 'package:farm/app_state.dart';
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/pages/assistant/assistant_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lowBalance =
    'Your FARM balance is too low to use Mkulima right now. Top up your wallet to continue.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    dotenv.loadFromString(isOptional: true);
    FFAppState.reset();
    await FFAppState().initializePersistedState();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (_) async => 1);
  });

  test('402 responses keep the server message and status', () async {
    ApiService.client = MockClient((_) async => http.Response(
        jsonEncode({'statusCode': 402, 'code': 'MKULIMA_LOW_BALANCE', 'message': _lowBalance}), 402));
    try {
      await ApiService.request(method: 'POST', path: '/ai/chat', body: {'message': 'hi'});
      fail('Expected a 402 exception.');
    } on ApiServiceException catch (e) {
      expect(e.statusCode, 402);
      expect(e.toString(), _lowBalance);
    }
  });

  testWidgets('Mkulima chat shows the low-balance message with Top up, not Retry', (tester) async {
    ApiService.client = MockClient((req) async {
      if (req.url.path.endsWith('/ai/status')) {
        return http.Response(jsonEncode({'enabled': true, 'actions': []}), 200);
      }
      return http.Response(
          jsonEncode({'statusCode': 402, 'code': 'MKULIMA_LOW_BALANCE', 'message': _lowBalance}), 402);
    });
    await tester.pumpWidget(const MaterialApp(home: AssistantChatPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bei ya mahindi?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text(_lowBalance), findsOneWidget);
    expect(find.byKey(const ValueKey('mkulima-top-up')), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
