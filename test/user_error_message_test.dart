import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:farm/backend/services/api_service.dart';
import 'package:farm/utils/user_error_message.dart';

void main() {
  test('network errors', () {
    expect(userErrorMessage(const SocketException('Failed host lookup')), kNoInternetMessage);
    expect(
        userErrorMessage(http.ClientException(
            'SocketException: Failed host lookup: farm-backend-r64g.onrender.com',
            Uri.parse('https://farm-backend-r64g.onrender.com/api/v1/business/me'))),
        kNoInternetMessage);
    expect(userErrorMessage(Exception('ClientException with SocketException: Failed host lookup: x.onrender.com')), kNoInternetMessage);
  });
  test('timeout', () => expect(userErrorMessage(TimeoutException('t')), kSlowConnectionMessage));
  test('status codes', () {
    expect(userErrorMessage(const ApiServiceException(statusCode: 503, message: 'boom')), kServerErrorMessage);
    expect(userErrorMessage(const ApiServiceException(statusCode: 401, message: 'x')), kSessionExpiredMessage);
  });
  test('backend message passes through', () {
    expect(userErrorMessage(Exception('Insufficient balance')), 'Insufficient balance');
  });
  test('technical text hidden', () {
    expect(userErrorMessage(Exception('Failed at https://x.com/a')), kGenericErrorMessage);
    expect(userErrorMessage(StateError('Bad state: x')).contains('StateError'), isFalse);
  });
}
