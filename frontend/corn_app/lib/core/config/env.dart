import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  // For Android physical device: Use special alias to reach Windows host
  // Physical devices on same network use 10.0.2.2 to reach host localhost
  // Or use your Windows PC's actual IP (find with: ipconfig)
  static const String _androidPhysicalDeviceUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.149.35.34:8000', // Windows PC IP address (detected)
  );

  static const String _emulatorBaseUrl = 'http://10.0.2.2:8000';
    static const String _physicalDeviceUrl =
      'http://10.149.35.34:8000'; // Your PC's Wi-Fi IP (detected)
  static const String _localWebBaseUrl = 'http://localhost:8000';

  static String get baseUrl {
    if (kIsWeb) {
      return _localWebBaseUrl; // chrome/web runs against local machine
    }

    // For Android physical devices, use PC's actual IP address
    // For emulators, would need to use 10.0.2.2
    if (Platform.isAndroid) {
      // Use the value from dart-define `API_BASE_URL` when running on Android.
      // Example: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
      return _androidPhysicalDeviceUrl;
    }

    return _emulatorBaseUrl; // fallback for iOS sim and others
  }
}
