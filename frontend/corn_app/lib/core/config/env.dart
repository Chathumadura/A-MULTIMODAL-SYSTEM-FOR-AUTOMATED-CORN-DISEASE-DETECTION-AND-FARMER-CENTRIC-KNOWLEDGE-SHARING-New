import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Env {
  // For Android physical device: Use special alias to reach Windows host
  // Physical devices on same network use 10.0.2.2 to reach host localhost
  // Or use your Windows PC's actual IP (find with: ipconfig)
  static const String _androidPhysicalDeviceUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.100:8000', // Windows PC IP address
  );

  static const String _emulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _physicalDeviceUrl = 'http://192.168.0.101:8000'; // Your PC's WiFi IP
  static const String _localWebBaseUrl = 'http://localhost:8000';

  static String get baseUrl {
    if (kIsWeb) {
      return _localWebBaseUrl; // chrome/web runs against local machine
    }
    
    // For Android physical devices, use PC's actual IP address
    // For emulators, would need to use 10.0.2.2
    if (Platform.isAndroid) {
      return _physicalDeviceUrl; // Use PC IP for physical Android devices
    }
    
    return _emulatorBaseUrl; // fallback for iOS sim and others
  }
}
