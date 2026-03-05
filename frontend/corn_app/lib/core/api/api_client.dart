// lib/core/api/api_client.dart
//
// Production-ready API client for the Corn AI backend.
// Works on: Android Emulator, physical Android/iOS device, Flutter Web.
//
// URL routing is handled entirely by ApiConfig (lib/core/api/api_config.dart).
// To change which server is targeted, see ApiConfig.runMode docs.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

/// Central API client.
///
/// Every network call in the app goes through this class so that the base URL
/// is defined in exactly one place: [Env._productionUrl] inside [Env].
/// [ApiClient.baseUrl] is a transparent delegate to [Env.baseUrl] so that
/// `--dart-define=API_BASE_URL=...` overrides are always respected.
///
/// Usage:
/// ```dart
/// final client = ApiClient();
/// final result = await client.uploadImageForPrediction(imageFile);
/// print(result); // {"predicted_class": "NAB", "confidence": 0.76, ...}
/// ```
class ApiClient {
  // ── URL resolution ────────────────────────────────────────────────────────
  /// The resolved backend base URL for the current environment.
  ///
  /// Delegates to [ApiConfig] → [Env] chain:
  ///   • emulator   → http://10.0.2.2:8000
  ///   • device     → http://<_physicalDeviceIp>:8000  (set in api_config.dart)
  ///   • production → https://corn-ai-backend.onrender.com
  ///
  /// Do NOT hard-code a URL here. Edit [ApiConfig] in api_config.dart instead.
  static String get baseUrl => ApiConfig.baseUrl;

  // Timeout for multipart uploads.
  // Render free tier cold-starts can take 50–80 s; 90 s gives a safe margin.
  static const Duration _uploadTimeout = Duration(seconds: 90);
  static const Duration _getTimeout = Duration(seconds: 30);

  // ── Internal helpers ─────────────────────────────────────────────────────

  /// Builds a [Uri] from [path], always using the runtime base URL.
  /// [Env.baseUrl] honours the `--dart-define=API_BASE_URL=...` flag so
  /// developers can still point at a local server without changing source.
  /// A debug-mode log is emitted before every request so the full URL is
  /// visible in `flutter run` / logcat output.
  Uri _uri(String path) {
    final url = '${ApiConfig.baseUrl}$path';
    debugPrint('🌐 [ApiClient] REQUEST → $url');
    return Uri.parse(url);
  }

  /// Decodes a successful response or throws a descriptive [Exception].
  Map<String, dynamic> _decode(http.Response response, String label) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('[$label] HTTP ${response.statusCode}: ${response.body}');
  }

  /// Sends a [MultipartRequest] and returns the parsed response body.
  Future<Map<String, dynamic>> _sendMultipart(
    http.MultipartRequest request,
    String label,
  ) async {
    final streamed = await request.send().timeout(_uploadTimeout);
    final response = await http.Response.fromStream(streamed);
    return _decode(response, label);
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// GET any [path] and return the parsed JSON body.
  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(_uri(path)).timeout(_getTimeout);
    return _decode(response, 'GET $path');
  }

  /// POST [path] with a JSON [body] — returns the raw [http.Response].
  ///
  /// The URL is logged via [debugPrint] before sending (same as all other
  /// calls through [_uri]).  Use this when the caller needs to inspect the
  /// status code or body directly.
  ///
  /// ```dart
  /// final res = await ApiClient().postJsonRaw('/yield/predict', payload);
  /// if (res.statusCode == 200) { ... }
  /// ```
  Future<http.Response> postJsonRaw(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = _uri(path);            // debug print happens here
    return http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_uploadTimeout);
  }

  /// POST /nutrition/predict
  ///
  /// Uploads [imageFile] as a multipart form-data request and returns the
  /// full JSON response, e.g.:
  /// ```json
  /// {
  ///   "predicted_class": "NAB",
  ///   "confidence": 0.76,
  ///   "all_probabilities": { "Healthy": 0.10, "NAB": 0.76, ... },
  ///   "fertilizer_recommendations": { ... }
  /// }
  /// ```
  ///
  /// Throws [Exception] on HTTP error or network failure.
  ///
  /// Note: on Flutter Web [File] (dart:io) is unavailable.  Pass a
  /// [Uint8List] + filename by calling [predictNutritionBytes] instead.
  Future<Map<String, dynamic>> uploadImageForPrediction(File imageFile) async {
    final request = http.MultipartRequest('POST', _uri('/nutrition/predict'));

    final ext = imageFile.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(mime),
      ),
    );

    return _sendMultipart(request, 'POST /nutrition/predict');
  }

  /// POST /pest/predict  — send [imageFile] for pest detection.
  Future<Map<String, dynamic>> uploadImageForPestDetection(
    File imageFile,
  ) async {
    final request = http.MultipartRequest('POST', _uri('/pest/predict'));
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        contentType: MediaType.parse(
          imageFile.path.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg',
        ),
      ),
    );
    return _sendMultipart(request, 'POST /pest/predict');
  }

  /// POST /nutrition/predict — Web-safe variant that accepts raw bytes.
  ///
  /// Use this on Flutter Web where `dart:io` is unavailable:
  /// ```dart
  /// final bytes = await imageFile.readAsBytes(); // XFile from image_picker
  /// final result = await ApiClient().predictNutritionBytes(
  ///   bytes, imageFile.name);
  /// ```
  Future<Map<String, dynamic>> predictNutritionBytes(
    List<int> bytes,
    String filename,
  ) async {
    final request = http.MultipartRequest('POST', _uri('/nutrition/predict'));
    final ext = filename.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mime),
      ),
    );
    return _sendMultipart(request, 'POST /nutrition/predict (bytes)');
  }
}
