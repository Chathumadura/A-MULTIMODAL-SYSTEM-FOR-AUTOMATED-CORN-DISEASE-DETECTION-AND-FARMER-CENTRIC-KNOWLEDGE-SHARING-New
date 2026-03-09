// lib/core/api/api_config.dart
//
// Central URL routing for all three deployment targets:
//
//   RunMode.emulator    → http://10.0.2.2:8000          (Android AVD  → host)
//   RunMode.device      → http://<_physicalDeviceIp>:8000 (real phone on LAN)
//   RunMode.production  → https://a-multimodal-system-for-automated-corn.onrender.com
//
// ── Developer quick-start ─────────────────────────────────────────────────
//
//  1. Android Emulator (no extra config needed):
//       flutter run
//       # debug + Android → auto-selects RunMode.emulator
//
//  2. Real device on the same WiFi:
//       a. Find your PC's LAN IP (ipconfig → IPv4, e.g. 192.168.1.42)
//       b. Set _physicalDeviceIp below to that IP.
//       c. flutter run --dart-define=RUN_MODE=device
//
//  3. Force production (Render) on any device:
//       flutter run --dart-define=RUN_MODE=production
//
//  4. Release build → always production regardless of RUN_MODE.
//
// ─────────────────────────────────────────────────────────────────────────

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;

// ── ✏️  SET THIS to your PC's LAN IP when running on a real device ─────────
const String _physicalDeviceIp = '192.168.1.100'; // e.g. 192.168.1.42
// ─────────────────────────────────────────────────────────────────────────

const int _localPort = 8000;
const String _productionUrl =
    'https://a-multimodal-system-for-automated-corn.onrender.com';

/// The three environments the app can target.
enum RunMode {
  /// Android emulator — routes `localhost` host calls to `10.0.2.2`.
  emulator,

  /// Physical Android/iOS device on the same LAN as the development machine.
  device,

  /// Render cloud deployment (always used for release builds).
  production,
}

/// Resolves the backend base URL from [RunMode].
///
/// Call [ApiConfig.baseUrl] anywhere in the app; it always returns the
/// correct URL for the current environment.
///
/// ```dart
/// // In any widget / service:
/// final url = ApiConfig.baseUrl; // → 'http://10.0.2.2:8000' on emulator
/// ```
class ApiConfig {
  ApiConfig._(); // non-instantiable

  // ── Run-mode resolution ──────────────────────────────────────────────────

  /// Resolves the active [RunMode].
  ///
  /// Priority (highest → lowest):
  ///  1. `--dart-define=RUN_MODE=<emulator|device|production>`
  ///  2. Release build → [RunMode.production]
  ///  3. Debug on Android → [RunMode.emulator]  (safe AVD default)
  ///  4. Everything else → [RunMode.device] (local dev server fallback)
  static RunMode get runMode {
    // 1. Explicit override via --dart-define
    const defined = String.fromEnvironment('RUN_MODE');
    if (defined == 'emulator') return RunMode.emulator;
    if (defined == 'device') return RunMode.device;
    if (defined == 'production') return RunMode.production;

    // 2. Release builds always hit production
    if (!kDebugMode) return RunMode.production;

    // 3. Debug + Android emulator (most common dev setup)
    if (!kIsWeb && Platform.isAndroid) return RunMode.emulator;

    // 4. Fallback (debug web, desktop, iOS simulator) → try local dev server on 127.0.0.1
    return RunMode.device;
  }

  // ── URL resolution ───────────────────────────────────────────────────────

  /// The fully-resolved backend base URL for the current [runMode].
  ///
  /// Examples:
  /// ```
  /// ApiConfig.baseUrl  →  "http://10.0.2.2:8000"        (emulator)
  /// ApiConfig.baseUrl  →  "http://192.168.1.42:8000"    (device)
  /// ApiConfig.baseUrl  →  "https://corn-ai-backend.onrender.com" (prod)
  /// ```
  static String get baseUrl => _resolveUrl(runMode);

  static String _resolveUrl(RunMode mode) {
    switch (mode) {
      case RunMode.emulator:
        // 10.0.2.2 is Android Emulator's special alias for the host machine.
        return 'http://10.0.2.2:$_localPort';
      case RunMode.device:
        // Physical device or web/desktop — prefer localhost for dev
        if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
          return 'http://127.0.0.1:$_localPort'; // web/desktop → localhost
        }
        return 'http://$_physicalDeviceIp:$_localPort'; // real phone/tablet on LAN
      case RunMode.production:
        return _productionUrl;
    }
  }

  // ── Named endpoint helpers ───────────────────────────────────────────────

  /// `POST /nutrition/predict` — multipart image upload.
  static String get nutritionPredictUrl => '$baseUrl/nutrition/predict';

  /// `POST /pest/predict` — multipart image upload.
  static String get pestPredictUrl => '$baseUrl/pest/predict';

  /// `POST /yield/predict` — JSON body.
  static String get yieldPredictUrl => '$baseUrl/yield/predict';

  /// `GET /health`
  static String get healthUrl => '$baseUrl/health';

  // ── Diagnostics ──────────────────────────────────────────────────────────

  /// Prints the resolved URL and active mode to the debug console.
  static void printConfig() {
    debugPrint('──────────────────────────────────────────');
    debugPrint('  ApiConfig');
    debugPrint('  RunMode  : ${runMode.name}');
    debugPrint('  Base URL : ${_resolveUrl(runMode)}');
    debugPrint('  Debug?   : $kDebugMode');
    if (!kIsWeb) debugPrint('  Android? : ${Platform.isAndroid}');
    debugPrint('──────────────────────────────────────────');
  }
}
