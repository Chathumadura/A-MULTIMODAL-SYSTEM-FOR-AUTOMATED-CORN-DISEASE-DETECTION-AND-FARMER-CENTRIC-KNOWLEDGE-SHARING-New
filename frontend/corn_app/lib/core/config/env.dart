import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  // Override at build time: --dart-define=API_BASE_URL=http://<lan-ip>:8000
  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.102:8000',
  );

  static const String _emulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _localWebBaseUrl = 'http://127.0.0.1:8000';

  static String get baseUrl {
    if (kIsWeb)
      return _localWebBaseUrl; // chrome/web runs against local machine
    if (Platform.isAndroid)
      return _definedBaseUrl; // physical device uses LAN IP
    return _emulatorBaseUrl; // fallback (emulators/iOS sim can use host loopback)
  }
}
