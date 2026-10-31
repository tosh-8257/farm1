import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to all environment variables.
///
/// Precedence: `--dart-define=KEY=value` > `.env` asset > production default.
/// A missing or empty `.env` never breaks startup.
class Env {
  static const productionApiUrl = 'https://farm-backend-r64g.onrender.com';
  static const productionFrontendUrl = 'https://www.farmapp.africa';

  static String _read(String key, String define, String fallback) {
    if (define.isNotEmpty) return define;
    final v = dotenv.isInitialized ? dotenv.env[key]?.trim() : null;
    return (v == null || v.isEmpty) ? fallback : v;
  }

  static final supabaseUrl = _read(
    'SUPABASE_URL',
    const String.fromEnvironment('SUPABASE_URL'),
    '',
  );

  static final supabaseAnonKey = _read(
    'SUPABASE_ANON_KEY',
    const String.fromEnvironment('SUPABASE_ANON_KEY'),
    '',
  );

  static final apiBaseUrl = _trimSlash(
    _read('API_URL', const String.fromEnvironment('API_URL'), productionApiUrl),
  );

  /// Socket.IO base (falls back to the API URL).
  static final backendUrl = _trimSlash(
    _read(
      'BACKEND_URL',
      const String.fromEnvironment('BACKEND_URL'),
      _read('API_BASE_URL', '', apiBaseUrl),
    ),
  );

  static final frontendUrl = _trimSlash(
    _read(
      'FRONTEND_URL',
      const String.fromEnvironment('FRONTEND_URL'),
      productionFrontendUrl,
    ),
  );

  static final appScheme = _read(
    'APP_SCHEME',
    const String.fromEnvironment('APP_SCHEME'),
    'farm',
  );

  static final appHost = _read(
    'APP_HOST',
    const String.fromEnvironment('APP_HOST'),
    Uri.parse(frontendUrl).host,
  );

  static const apiVersion = '/api/v1';

  static String get api => '$apiBaseUrl$apiVersion';

  static String _trimSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;
}
