import 'package:flutter/foundation.dart';

class Env {
  // ─────────────────────────────────────────────────────────────────────────
  // Production backend deployed on Render.
  // ─────────────────────────────────────────────────────────────────────────
  static const _productionUrl = 'https://corn-ai-backend.onrender.com';

  /// Backend base URL.
  ///
  /// Defaults to the Render production URL on every platform.
  /// Override at build/run time with --dart-define for local development:
  ///
  ///   Emulator   : flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  ///   Real device: flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:8000
  ///   Production : (no flag needed – uses Render URL)
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    // All platforms (Android APK, Web, iOS, Desktop) use the production URL
    // by default.  This eliminates the 10.0.2.2 / localhost confusion on real
    // devices and production builds.
    return _productionUrl;
  }

  /// Convenience URL getters for each API group.
  static String get nutritionPredictUrl => '$baseUrl/nutrition/predict';
  static String get yieldPredictUrl => '$baseUrl/yield/predict';
  static String get yieldExplainUrl => '$baseUrl/yield/explain';
  static String get healthUrl => '$baseUrl/health';
  static String get pestPredictUrl => '$baseUrl/pest/predict';
}
