import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized access to all environment variables.
///
/// Values are resolved in this order:
///   1. Compile-time defines (`--dart-define=KEY=value` or
///      `--dart-define-from-file=.env`), so release builds never need a
///      bundled `.env` asset.
///   2. `dotenv`, when it has been initialised (tests or local tooling).
///   3. The safe default below.
///
/// Reading never throws, so a clean checkout without `.env` builds, runs and
/// tests. See `.env.example` for the supported keys.
class Env {
  static String _read(String key, String compiled, String fallback) {
    if (compiled.isNotEmpty) return compiled;
    if (dotenv.isInitialized) {
      final value = dotenv.maybeGet(key);
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
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

  static final apiBaseUrl = _read(
    'API_URL',
    const String.fromEnvironment('API_URL'),
    'http://127.0.0.1:3000',
  );

  static final frontendUrl = _read(
    'FRONTEND_URL',
    const String.fromEnvironment('FRONTEND_URL'),
    'http://localhost:4200',
  );

  static final appScheme = _read(
    'APP_SCHEME',
    const String.fromEnvironment('APP_SCHEME'),
    'farm',
  );

  static final appHost = _read(
    'APP_HOST',
    const String.fromEnvironment('APP_HOST'),
    'farm.com',
  );

  /// Socket.IO backend; falls back to the REST API host.
  static String get socketBaseUrl {
    final backend = _read(
      'BACKEND_URL',
      const String.fromEnvironment('BACKEND_URL'),
      '',
    );
    if (backend.isNotEmpty) return backend;
    final apiBase = _read(
      'API_BASE_URL',
      const String.fromEnvironment('API_BASE_URL'),
      '',
    );
    if (apiBase.isNotEmpty) return apiBase;
    return _read(
      'API_URL',
      const String.fromEnvironment('API_URL'),
      'http://localhost:3000',
    );
  }

  static final apiVersion = '/api/v1';

  static String get api => '$apiBaseUrl$apiVersion';
}
