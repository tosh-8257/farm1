import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/app_config.dart';

class QrPublicPaymentApi {
  static final Uri _baseUri = Uri.parse(
    '${AppConfig.baseUrl}${AppConfig.apiVersion}/',
  );

  static Uri _resolve(String path) {
    final relativePath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(relativePath);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(_resolve(path), headers: const {
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));
    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
            _resolve(path),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return _decodeResponse(response);
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> data = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else {
        throw const FormatException('Unexpected payment API response.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data['message'];
      final errorMessage = switch (message) {
        String value when value.trim().isNotEmpty => value,
        List values => values.map((value) => value.toString()).join(', '),
        _ => 'Payment request failed (HTTP ${response.statusCode}).',
      };
      throw Exception(
        errorMessage,
      );
    }
    return data;
  }
}
