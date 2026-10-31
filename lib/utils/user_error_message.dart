import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/backend/services/api_service.dart';

/// Central, user-safe error text.
///
/// Every place that shows an error to a user (snackbars, error states,
/// dialogs) should pass the caught error through [userErrorMessage]. It never
/// returns URLs, hostnames, stack traces or exception class names; the raw
/// details are only logged with [debugPrint] in debug builds.
const kNoInternetMessage =
    'No internet connection. Check your network and try again.';
const kSlowConnectionMessage = 'The connection is slow. Please try again.';
const kServerErrorMessage =
    'Something went wrong on our side. Please try again shortly.';
const kSessionExpiredMessage =
    'Your session has expired. Please sign in again.';
const kGenericErrorMessage = 'Something went wrong. Please try again.';

String userErrorMessage(Object? error, {String? fallback}) {
  final generic = fallback ?? kGenericErrorMessage;
  if (kDebugMode && error != null) {
    debugPrint('[error] ${error.runtimeType}: $error');
  }
  if (error == null) return generic;

  if (error is TimeoutException) return kSlowConnectionMessage;
  // dart:io types are matched by name so this file also compiles for web.
  final type = error.runtimeType.toString();
  if (error is http.ClientException ||
      type == 'SocketException' ||
      type == 'HandshakeException' ||
      type == 'HttpException') {
    return kNoInternetMessage;
  }
  if (error is ApiServiceException) {
    if (error.statusCode == 401) return kSessionExpiredMessage;
    if (error.statusCode >= 500) return kServerErrorMessage;
    return _passThrough(error.message, generic);
  }

  return _passThrough(error.toString(), generic);
}

/// Maps a raw message string. Backend user-facing messages pass through;
/// anything technical is replaced.
String _passThrough(String raw, String generic) {
  var s = raw.trim();
  for (final p in const ['Exception: ', 'Error: ', 'FormatException: ']) {
    if (s.startsWith(p)) s = s.substring(p.length).trim();
  }
  final lower = s.toLowerCase();
  if (s.isEmpty) return generic;

  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('clientexception') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('handshakeexception') ||
      lower.contains('xmlhttprequest error')) {
    return kNoInternetMessage;
  }
  if (lower.contains('timeoutexception') || lower.contains('timed out')) {
    return kSlowConnectionMessage;
  }
  if (RegExp(r'\b401\b').hasMatch(lower) ||
      lower.contains('unauthorized') ||
      lower.contains('unauthenticated') ||
      lower.contains('jwt expired') ||
      lower.contains('token expired')) {
    return kSessionExpiredMessage;
  }
  if (RegExp(r'\b5\d\d\b').hasMatch(lower) &&
      (lower.contains('server') || lower.contains('status'))) {
    return kServerErrorMessage;
  }

  final looksTechnical = s.length > 220 ||
      s.contains('://') ||
      s.contains('uri=') ||
      RegExp(r'#\d+\s').hasMatch(s) ||
      RegExp(r'\.dart[:\s)]').hasMatch(s) ||
      RegExp(r'[A-Za-z]+(Exception|Error)\b').hasMatch(s) ||
      RegExp(r'\b[a-z0-9-]+\.(com|net|io|africa|app|dev|org)\b',
              caseSensitive: false)
          .hasMatch(s) ||
      s.startsWith('{') ||
      s.startsWith('[') ||
      s.startsWith('<') ||
      lower.contains('null check operator') ||
      lower.contains("instance of '") ||
      lower.contains('is not a subtype');
  return looksTechnical ? generic : s;
}
