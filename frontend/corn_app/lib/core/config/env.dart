import 'package:flutter/foundation.dart';

class Env {
  /// Your PC's LAN IP address (run `ipconfig` on Windows → IPv4 Address).
  /// Update this when your network changes.
  static const _lanIp = '10.101.175.34';

  /// Backend base URL.
  ///
  /// Override at build/run time with --dart-define:
  ///   Emulator : flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  ///   Real device: flutter run --dart-define=API_BASE_URL=http://172.28.31.76:8000
  ///   LAN IP query: ipconfig  (look for IPv4 Address)
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator routes 10.0.2.2 → host machine loopback.
        // For a real device on LAN use:
        //   flutter run --dart-define=API_BASE_URL=http://$_lanIp:8000
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  /// Convenience URL getters for each API group.
  static String get nutritionPredictUrl => '$baseUrl/nutrition/predict';
  static String get yieldPredictUrl => '$baseUrl/yield/predict';
  static String get yieldExplainUrl => '$baseUrl/yield/explain';
  static String get healthUrl => '$baseUrl/health';
}

