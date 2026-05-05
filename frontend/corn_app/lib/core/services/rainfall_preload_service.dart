import 'package:shared_preferences/shared_preferences.dart';

import 'rainfall_service.dart';

class RainfallPreloadService {
  static double? _cachedRainfall;

  static const _keyValue = "cached_rainfall";
  static const _keyTime = "rainfall_timestamp";

  static Future<void> preload(String location) async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getDouble(_keyValue);
    final timestamp = prefs.getInt(_keyTime);

    if (cached != null && timestamp != null) {
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age < 6 * 60 * 60 * 1000) {
        _cachedRainfall = cached;
      }
    }

    try {
      final rainfall = await RainfallService.getSeasonalRainfall(location);
      _cachedRainfall = rainfall;

      await prefs.setDouble(_keyValue, rainfall);
      await prefs.setInt(_keyTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static double? getCached() {
    return _cachedRainfall;
  }
}
