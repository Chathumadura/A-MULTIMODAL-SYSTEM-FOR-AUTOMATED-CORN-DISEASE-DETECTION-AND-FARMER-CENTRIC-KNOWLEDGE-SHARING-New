// lib/core/config/env.dart
//
// Thin facade over ApiConfig.  All URL logic now lives in ApiConfig so that
// the emulator / device / production routing is in one place.
//
// Existing call-sites that use Env.baseUrl or Env.nutritionPredictUrl
// continue to work without any changes.

import '../api/api_config.dart';

class Env {
  /// The resolved backend base URL for the current environment.
  ///
  /// Delegates to [ApiConfig.baseUrl], which automatically selects:
  ///   • `http://10.0.2.2:8000`             – Android Emulator (debug)
  ///   • `http://<physicalDeviceIp>:8000`   – real device on LAN (debug)
  ///   • `https://a-multimodal-system-for-automated-corn.onrender.com` – production / release
  ///
  /// To override, pass `--dart-define=RUN_MODE=emulator|device|production`
  /// to `flutter run`, or set `_physicalDeviceIp` in api_config.dart.
  static String get baseUrl => ApiConfig.baseUrl;

  // ── Named endpoint helpers (kept for backwards compatibility) ────────────
  static String get nutritionPredictUrl => ApiConfig.nutritionPredictUrl;
  static String get yieldPredictUrl => ApiConfig.yieldPredictUrl;
  static String get yieldExplainUrl => '${ApiConfig.baseUrl}/yield/explain';
  static String get healthUrl => ApiConfig.healthUrl;
  static String get pestPredictUrl => ApiConfig.pestPredictUrl;
}
