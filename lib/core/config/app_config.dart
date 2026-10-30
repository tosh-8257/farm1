import 'env.dart';

/// Application configuration that uses environment variables.
/// This file maintains backward compatibility while delegating to [Env].
class AppConfig {
  // Override for local/sandbox testing: --dart-define=API_BASE_URL=http://localhost:3999
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://farm-backend-r64g.onrender.com',
  );

  static const String apiVersion = '/api/v1';

  static String get api => Env.api;

  static String get supabaseUrl => Env.supabaseUrl;

  static String get supabaseAnonKey => Env.supabaseAnonKey;
}
