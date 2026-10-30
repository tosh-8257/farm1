// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '/backend/services/turnstile_payload.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '/core/app_config.dart';
import '/app_state.dart';
import '/services/auth/refresh_manager.dart';
import '/utils/transaction_history_utils.dart';

class ApiServiceException implements Exception {
  const ApiServiceException({
    required this.statusCode,
    required this.message,
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String message;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}

class ApiService {
  static http.Client _client = http.Client();

  static set client(http.Client value) => _client = value;

  static Future<Map<String, dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    int timeoutSeconds = 20,
  }) =>
      _request(
        method: method,
        path: path,
        body: body,
        requiresAuth: requiresAuth,
        timeoutSeconds: timeoutSeconds,
      );

  static Future<List<String>> uploadImages({
    required List<Uint8List> files,
    required List<String> filenames,
    required List<String> mimeTypes,
  }) =>
      _uploadImages(
        files: files,
        filenames: filenames,
        mimeTypes: mimeTypes,
      );

  /// Business document upload: PDF, JPG, PNG or WebP up to 10 MB.
  /// The server re-validates type (magic bytes) and size.
  static Future<String> uploadDocument({
    required Uint8List bytes,
    required String filename,
    bool isRetry = false,
  }) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ArgumentError('Documents must be no larger than 10 MB.');
    }
    final lower = filename.toLowerCase();
    final MediaType type;
    if (lower.endsWith('.pdf')) {
      type = MediaType('application', 'pdf');
    } else if (lower.endsWith('.png')) {
      type = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      type = MediaType('image', 'webp');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      type = MediaType('image', 'jpeg');
    } else {
      throw ArgumentError('Only PDF, JPG, PNG and WebP files are supported.');
    }
    final token = await FFAppState().getActiveAccessToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.api}/uploads/document'),
    )..headers.addAll({
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: filename, contentType: type));
    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 120)),
    );
    Map<String, dynamic> decoded = {};
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode == 401 &&
        !isRetry &&
        FFAppState().refreshToken.isNotEmpty) {
      final refreshed = await RefreshManager().refreshIfNeeded(force: true);
      if (refreshed) {
        return uploadDocument(bytes: bytes, filename: filename, isRetry: true);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'] is String
          ? decoded['message'] as String
          : 'Document upload failed (${response.statusCode})';
      throw Exception(message);
    }
    final url = decoded['url'];
    if (url is! String || url.isEmpty) {
      throw const FormatException('The server returned an invalid file URL.');
    }
    return url;
  }

  static Future<List<String>> _uploadImages({
    required List<Uint8List> files,
    required List<String> filenames,
    required List<String> mimeTypes,
    bool isRetry = false,
  }) async {
    if (files.isEmpty ||
        files.length > 5 ||
        files.length != filenames.length ||
        files.length != mimeTypes.length) {
      throw ArgumentError('Upload between 1 and 5 valid images.');
    }
    for (var index = 0; index < files.length; index++) {
      if (files[index].isEmpty || files[index].length > 5 * 1024 * 1024) {
        throw ArgumentError('Each image must be no larger than 5 MB.');
      }
    }

    final token = await FFAppState().getActiveAccessToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.api}/uploads/multiple'),
    )..headers.addAll({
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
    for (var index = 0; index < files.length; index++) {
      final mimeParts = mimeTypes[index].split('/');
      if (mimeParts.length != 2 || mimeParts.first != 'image') {
        throw ArgumentError('Only image uploads are supported.');
      }
      request.files.add(http.MultipartFile.fromBytes(
        'images',
        files[index],
        filename: filenames[index],
        contentType: MediaType(mimeParts[0], mimeParts[1]),
      ));
    }

    final response = await http.Response.fromStream(
      await _client.send(request).timeout(const Duration(seconds: 90)),
    );
    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        decoded = {};
      }
    }

    if (response.statusCode == 401 &&
        !isRetry &&
        FFAppState().refreshToken.isNotEmpty) {
      final refreshed = await RefreshManager().refreshIfNeeded(force: true);
      if (refreshed) {
        return _uploadImages(
          files: files,
          filenames: filenames,
          mimeTypes: mimeTypes,
          isRetry: true,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message'] is String
          ? decoded['message'] as String
          : 'Image upload failed (${response.statusCode})';
      if (response.statusCode >= 500) {
        throw ApiServiceException(
          statusCode: response.statusCode,
          message: message,
        );
      }
      throw Exception(message);
    }

    final rawUrls = decoded['urls'];
    if (rawUrls is! List || rawUrls.length != files.length) {
      throw const FormatException('The server returned invalid image URLs.');
    }
    final urls = rawUrls.map((url) => url.toString()).toList(growable: false);
    if (urls.any((url) => Uri.tryParse(url)?.scheme != 'https')) {
      throw const FormatException('The server returned an invalid image URL.');
    }
    return urls;
  }

  // Central method — all requests go through here
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool isRetry = false,
    int timeoutSeconds = 20,
    bool useUnversionedApi = false,
  }) async {
    final apiBase = useUnversionedApi
        ? AppConfig.api.replaceFirst(RegExp(r'/api/v\d+$'), '/api')
        : AppConfig.api;
    final uri = Uri.parse('$apiBase$path');
    // Ensure we resolve a valid access token from persisted/session state.
    String token = await FFAppState().getActiveAccessToken();
    // If this request requires auth and we don't have a token in memory,
    // attempt a refresh (serialized inside RefreshManager) before proceeding.
    if (requiresAuth && token.isEmpty && FFAppState().refreshToken.isNotEmpty) {
      try {
        await RefreshManager().refreshIfNeeded(force: false);
      } catch (_) {}
      token = await FFAppState().getActiveAccessToken();
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (requiresAuth && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response response;
    final start = DateTime.now();
    debugPrint('[ApiService] START $method $path @ $start');

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(
                Duration(seconds: timeoutSeconds),
              );
          break;
        case 'POST':
          response = await _client
              .post(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        case 'PUT':
          response = await _client
              .put(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        case 'DELETE':
          response = await _client
              .delete(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(Duration(seconds: timeoutSeconds));
          break;
        default:
          throw Exception('Unknown HTTP method: $method');
      }
    } catch (e) {
      final duration = DateTime.now().difference(start);
      debugPrint(
          '[ApiService] ERROR $method $path after ${duration.inMilliseconds}ms -> $e');
      rethrow;
    }

    final duration = DateTime.now().difference(start);
    debugPrint(
        '[ApiService] END $method $path status=${response.statusCode} duration=${duration.inMilliseconds}ms');
    if (duration.inMilliseconds > 1000) {
      debugPrint(
          '[ApiService] SLOW_ENDPOINT $method $path took ${duration.inMilliseconds}ms');
    }

    if (response.statusCode == 401 &&
        requiresAuth &&
        !isRetry &&
        FFAppState().refreshToken.isNotEmpty) {
      final refreshed = await RefreshManager().refreshIfNeeded(force: true);
      if (refreshed) {
        debugPrint('[AUTH RETRY] Retrying request after refresh');
        await Future.delayed(const Duration(milliseconds: 250));
        return _request(
          method: method,
          path: path,
          body: body,
          requiresAuth: requiresAuth,
          isRetry: true,
          timeoutSeconds: timeoutSeconds,
          useUnversionedApi: useUnversionedApi,
        );
      }
    }

    Map<String, dynamic> decoded = {};
    String responseBody = response.body;

    if (responseBody.isNotEmpty) {
      try {
        decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        decoded = {};
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // store in simple in-memory cache keyed by path
      try {
        if (method.toUpperCase() == 'GET') {
          _cache[path] = decoded;
        } else {
          _cache.clear();
        }
      } catch (_) {}
      return decoded;
    }

    final message = decoded['message'] is String
        ? decoded['message'] as String
        : responseBody;
    if (response.statusCode == 429) {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      final waitMessage = retryAfter == null
          ? 'You are making requests too quickly. Please wait a moment and try again.'
          : 'You are making requests too quickly. Please wait $retryAfter seconds and try again.';
      throw ApiServiceException(
        statusCode: response.statusCode,
        message: waitMessage,
        retryAfterSeconds: retryAfter,
      );
    }
    if (response.statusCode >= 500) {
      throw ApiServiceException(
        statusCode: response.statusCode,
        message: message.isNotEmpty
            ? message
            : 'Server error (${response.statusCode})',
      );
    }
    throw Exception(message.isNotEmpty
        ? message
        : 'Request failed (${response.statusCode})');
  }

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? turnstileToken,
    String? countryCode,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/login',
        body: attachTurnstileToken(
          {
            'identifier': identifier,
            'password': password,
          },
          turnstileToken: turnstileToken,
        ),
        requiresAuth: false,
        timeoutSeconds: 60,
      );

  static Future<Map<String, dynamic>> completeFirebaseLogin({
    required String identifier,
    required String firebaseToken,
    String? countryCode,
    String? turnstileToken,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/firebase-login',
        body: attachTurnstileToken(
          {
            'identifier': identifier,
            'firebaseIdToken': firebaseToken,
          },
          turnstileToken: turnstileToken,
        ),
        requiresAuth: false,
        timeoutSeconds: 60,
      );

  static Future<Map<String, dynamic>> verifyPhone({
    required String firebaseIdToken,
    required String pendingLoginId,
    String? turnstileToken,
  }) {
    final body = attachTurnstileToken(
      {
        'firebaseIdToken': firebaseIdToken,
        'pendingLoginId': pendingLoginId,
      },
      turnstileToken: turnstileToken,
    );

    return _request(
      method: 'POST',
      path: '/auth/verify-phone',
      body: body,
      requiresAuth: false,
      timeoutSeconds: 60,
    );
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String password,
    String? email,
    String? country,
    String? referralCode,
    String? turnstileToken,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/register',
        body: attachTurnstileToken(
          {
            'first_name': firstName,
            'last_name': lastName,
            'username': username,
            'phone': phone,
            'password': password,
            if (email != null && email.isNotEmpty) 'email': email,
            if (country != null && country.isNotEmpty) 'country': country,
            if (referralCode != null && referralCode.isNotEmpty)
              'referral_code': referralCode,
          },
          turnstileToken: turnstileToken,
        ),
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> checkRegistrationAvailability({
    String? username,
    String? email,
    String? phone,
  }) {
    final query = Uri(
      queryParameters: {
        if (username != null && username.isNotEmpty) 'username': username,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    ).query;
    if (query.isEmpty) {
      throw ArgumentError('Provide a username, email, or phone number.');
    }
    return _request(
      method: 'GET',
      path: '/auth/registration-availability?$query',
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otpCode,
    String purpose = 'phone_verification',
  }) =>
      _request(
        method: 'POST',
        path: '/auth/verify-otp',
        body: {'phone': phone, 'otp_code': otpCode, 'purpose': purpose},
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
    String? turnstileToken,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/forgot-password',
        body: attachTurnstileToken({'email': email},
            turnstileToken: turnstileToken),
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String email,
    required String password,
    required String confirmPassword,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/reset-password',
        body: {
          'token': token,
          'email': email,
          'password': password,
          'confirm_password': confirmPassword,
        },
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> setPin({
    required String pin,
    required String confirmPin,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/set-pin',
        body: {'pin': pin, 'confirm_pin': confirmPin},
      );

  static Future<Map<String, dynamic>> changePin({
    required String currentPin,
    required String newPin,
    required String confirmPin,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/change-pin',
        body: {
          'current_pin': currentPin,
          'new_pin': newPin,
          'confirm_pin': confirmPin,
        },
      );

  static Future<Map<String, dynamic>> resetForgottenPin({
    required String phone,
    required String password,
    required String newPin,
    required String confirmPin,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/forgot-pin',
        body: {
          'phone': phone,
          'password': password,
          'new_pin': newPin,
          'confirm_pin': confirmPin,
        },
      );

  static Future<void> logout() =>
      _request(method: 'POST', path: '/auth/logout');

  static Future<Map<String, dynamic>> getSessions() =>
      _request(method: 'GET', path: '/auth/sessions');

  static Future<Map<String, dynamic>> revokeSession({
    required String sessionId,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/sessions/$sessionId/revoke',
      );

  static Future<Map<String, dynamic>> revokeOtherSessions() =>
      _request(method: 'POST', path: '/auth/sessions/revoke-others');

  static Future<Map<String, dynamic>> revokeAllSessions() =>
      _request(method: 'POST', path: '/auth/sessions/revoke-all');

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/change-password',
        body: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );

  static Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/refresh',
        body: {'refresh_token': refreshToken},
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> registerDeviceToken({
    required String token,
    String? platform,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/device-token',
        body: {
          'token': token,
          if (platform != null) 'platform': platform,
        },
      );

  static Future<Map<String, dynamic>> resendOtp() =>
      _request(method: 'POST', path: '/auth/resend-otp');

  static Future<Map<String, dynamic>> verifyEmail({
    required String token,
  }) =>
      _request(
        method: 'GET',
        path: '/auth/verify-email/$token',
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> resendEmailVerification({
    required String email,
  }) =>
      _request(
        method: 'POST',
        path: '/auth/resend-email-verification',
        body: {'email': email},
        requiresAuth: false,
      );

  static Future<Map<String, dynamic>> deleteAccount({
    Map<String, dynamic>? body,
  }) =>
      _request(method: 'DELETE', path: '/auth/delete-account', body: body);

  // ── Wallet ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getWallet({int timeoutSeconds = 20}) =>
      _request(method: 'GET', path: '/wallet', timeoutSeconds: timeoutSeconds);

  /// Return last cached response for a given path, if any.
  static Map<String, dynamic>? getCached(String path) => _cache[path];

  static void invalidateCache([String? path]) {
    if (path == null) {
      _cache.clear();
    } else {
      _cache.remove(path);
    }
  }

  static Future<Map<String, dynamic>> sendFunds({
    required String recipientIdentifier,
    required double amount,
    required String pin,
    String? description,
  }) =>
      _request(
        method: 'POST',
        path: '/wallet/send',
        body: {
          'recipient_identifier': recipientIdentifier,
          'amount': amount,
          'pin': pin,
          if (description != null) 'description': description,
        },
      );

  static Future<Map<String, dynamic>> getTransactions({
    String? type,
    String? status,
    int page = 1,
    int limit = 20,
    int timeoutSeconds = 20,
  }) async {
    final response = await _request(
      method: 'GET',
      path: '/transactions?page=$page&limit=$limit'
          '${type != null ? "&type=$type" : ""}'
          '${status != null ? "&status=$status" : ""}',
      timeoutSeconds: timeoutSeconds,
    );
    final items = response['data'];
    if (items is List) {
      response['data'] = items.where(isVisibleTransactionHistoryItem).toList();
    }
    return response;
  }

  static Future<Map<String, dynamic>> getReceipts({
    int page = 1,
    int limit = 50,
  }) =>
      _request(
        method: 'GET',
        path: '/receipts?page=$page&limit=$limit',
      );

  static Future<Map<String, dynamic>> getReceipt(String receiptId) =>
      _request(
        method: 'GET',
        path: '/receipts/${Uri.encodeComponent(receiptId)}',
      );

  static Future<Map<String, dynamic>> getReceiptDownloadUrl(
    String receiptId,
  ) =>
      _request(
        method: 'GET',
        path: '/receipts/${Uri.encodeComponent(receiptId)}/download',
      );

  static Future<Map<String, dynamic>> getTransactionDetails(String id) =>
      _request(
        method: 'GET',
        path: '/transactions/${Uri.encodeComponent(id)}',
      );

  static Future<Map<String, dynamic>> getGrowthHistory({
    required int days,
    int timeoutSeconds = 20,
  }) =>
      _request(
        method: 'GET',
        path: '/analytics/growth-history?days=$days',
        timeoutSeconds: timeoutSeconds,
      );

  // ── Merchant ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMerchantQr({
    int timeoutSeconds = 20,
  }) =>
      _request(
        method: 'GET',
        path: '/merchant/qr',
        timeoutSeconds: timeoutSeconds,
      );

  static Future<Map<String, dynamic>> regenerateMerchantQr() =>
      _request(method: 'POST', path: '/merchant/qr/regenerate');

  // ── Deposit ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> initiateDeposit({
    required double amountFiat,
    required String currency,
  }) =>
      _request(
        method: 'POST',
        path: '/payments/deposit',
        body: {'amount_fiat': amountFiat, 'currency': currency},
      );

  static Future<Map<String, dynamic>> getDepositHistory() async {
    final response = await _request(method: 'GET', path: '/payments/deposits');
    final items = response['data'];
    if (items is List) {
      response['data'] = items.where(isVisibleTransactionHistoryItem).toList();
    }
    return response;
  }

  static Future<Map<String, dynamic>> getDepositStatus(String reference) =>
      _request(method: 'GET', path: '/payments/deposit/$reference');

  // ── Withdraw ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amountFarm,
    required String currencyFiat,
    required String method,
    required String destination,
    required String pin,
  }) =>
      _request(
        method: 'POST',
        path: '/payments/withdraw',
        body: {
          'amount_farm': amountFarm,
          'currency_fiat': currencyFiat,
          'method': method,
          'destination': destination,
          'pin': pin,
        },
      );

  static Future<Map<String, dynamic>> getWithdrawalHistory() =>
      _request(method: 'GET', path: '/payments/withdrawals');

  static Future<Map<String, dynamic>> getWithdrawalStatus(String reference) =>
      _request(method: 'GET', path: '/payments/withdraw/$reference');

  // ── Escrow ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getEscrows({String? status}) => _request(
        method: 'GET',
        path: '/escrow${status != null ? "?status=$status" : ""}',
      );

  static Future<Map<String, dynamic>> createEscrow({
    required String sellerIdentifier,
    required double amount,
    required String title,
    required String pin,
    String? description,
    int autoReleaseDays = 7,
  }) =>
      _request(
        method: 'POST',
        path: '/escrow',
        body: {
          'seller_identifier': sellerIdentifier,
          'amount': amount,
          'title': title,
          'pin': pin,
          if (description != null) 'description': description,
          'auto_release_days': autoReleaseDays,
        },
      );

  static Future<Map<String, dynamic>> releaseEscrow(String escrowId) =>
      _request(method: 'POST', path: '/escrow/$escrowId/release');

  static Future<Map<String, dynamic>> disputeEscrow(
    String escrowId,
    String reason, {
    String? attachmentBase64,
    String? attachmentMimeType,
    String? attachmentUrl,
  }) =>
      _request(
        method: 'POST',
        path: '/escrow/$escrowId/dispute',
        body: {
          'reason': reason,
          if (attachmentBase64 != null) 'attachmentBase64': attachmentBase64,
          if (attachmentMimeType != null)
            'attachmentMimeType': attachmentMimeType,
          if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        },
      );

  static Future<Map<String, dynamic>> cancelEscrow(String escrowId) =>
      _request(method: 'POST', path: '/escrow/$escrowId/cancel');

  // ── Investments ───────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProjects({String? category}) =>
      _request(
        method: 'GET',
        path: '/investments${category != null ? "?category=$category" : ""}',
      );

  static Future<Map<String, dynamic>> getProject(String id) =>
      _request(method: 'GET', path: '/investments/$id');

  static Future<Map<String, dynamic>> invest({
    required String projectId,
    required double amount,
    required String pin,
  }) =>
      _request(
        method: 'POST',
        path: '/investments/$projectId/invest',
        body: {'amount': amount, 'pin': pin},
      );

  static Future<Map<String, dynamic>> getMyInvestments() =>
      _request(method: 'GET', path: '/investments/my');

  // ── Merchants ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMerchantDashboard() =>
      _request(method: 'GET', path: '/merchant/dashboard');

  static Future<Map<String, dynamic>> validateQr(String qrPayload) => _request(
        method: 'POST',
        path: '/qr/validate',
        body: {'qr_payload': qrPayload},
      );

  static Future<Map<String, dynamic>> merchantPay({
    required String qrPayload,
    required double amount,
    String? pin,
    bool? biometricAuth,
    String? deviceFingerprint,
  }) =>
      _request(
        method: 'POST',
        path: '/qr/merchant-pay',
        body: {
          'qr_payload': qrPayload,
          'amount': amount,
          if (pin != null) 'pin': pin,
          if (biometricAuth == true) 'biometric_auth': true,
          if (deviceFingerprint != null)
            'device_fingerprint': deviceFingerprint,
        },
      );

  // ── KYC ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> createDiditSession() => _request(
        method: 'POST',
        path: '/verify/create-session',
        body: const {},
        timeoutSeconds: 20,
        useUnversionedApi: true,
      );

  // Manual KYC submission (/kyc/submit) was removed: KYC is Didit-only.

  static Future<Map<String, dynamic>> getMyKyc() =>
      _request(method: 'GET', path: '/kyc/my');

  // ── Profile ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getProfile({int timeoutSeconds = 20}) =>
      _request(
          method: 'GET', path: '/users/me', timeoutSeconds: timeoutSeconds);

  static Future<Map<String, dynamic>> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? country,
    String? city,
    String? username,
  }) =>
      _request(
        method: 'PUT',
        path: '/users/me',
        body: {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (bio != null) 'bio': bio,
          if (country != null) 'country': country,
          if (city != null) 'city': city,
          if (username != null && username.isNotEmpty) 'username': username,
        },
      );

  static Future<Map<String, dynamic>> updateEmailOrPhone({
    String? email,
    String? phone,
    required String currentPassword,
  }) =>
      _request(
        method: 'PUT',
        path: '/users/me',
        body: {
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'current_password': currentPassword,
        },
      );

  static Future<Map<String, dynamic>> searchUsers(String query) => _request(
      method: 'GET',
      path: '/users/search?q=${Uri.encodeQueryComponent(query)}');

  static Future<Map<String, dynamic>> getContacts() =>
      _request(method: 'GET', path: '/users/contacts');

  static Future<Map<String, dynamic>> addContact({
    required String identifier,
    String? nickname,
  }) =>
      _request(
        method: 'POST',
        path: '/users/contacts',
        body: {
          'identifier': identifier,
          if (nickname != null) 'nickname': nickname
        },
      );

  static Future<Map<String, dynamic>> getNotifications({
    int timeoutSeconds = 20,
    int page = 1,
    int limit = 100,
  }) =>
      _request(
        method: 'GET',
        path: '/notifications?page=$page&limit=$limit',
        timeoutSeconds: timeoutSeconds,
      );

  static Future<Map<String, dynamic>> markNotificationRead({
    required String notificationId,
  }) =>
      _request(
        method: 'PATCH',
        path: '/notifications/$notificationId/read',
      );

  static Future<Map<String, dynamic>> markAllNotificationsRead() => _request(
        method: 'PATCH',
        path: '/notifications/read-all',
      );

  static Future<Map<String, dynamic>> deleteNotification({
    required String notificationId,
  }) =>
      _request(
        method: 'DELETE',
        path: '/notifications/$notificationId',
      );

  static Future<Map<String, dynamic>> deleteAllNotifications() => _request(
        method: 'DELETE',
        path: '/notifications',
      );

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> isBackendAlive() async {
    try {
      final res = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/health'),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
