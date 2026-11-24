import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  static const String _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// Uses `API_BASE_URL` when supplied via `--dart-define`.
  /// When running locally on Flutter Web without `--dart-define`, maps `10.0.2.2`
  /// (Android emulator host alias) to `127.0.0.1` so Chrome works out-of-the-box.
  static String get apiBaseUrl {
    if (kIsWeb && _envApiBaseUrl == 'http://10.0.2.2:8000/api/v1') {
      return 'http://127.0.0.1:8000/api/v1';
    }
    return _envApiBaseUrl;
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;
}