/// CORNXPERT FRONTEND - RAINFALL PRELOAD SERVICE
///
/// This service handles the local persistence and background pre-fetching of 
/// seasonal rainfall data. It optimizes the user experience by ensuring that 
/// rainfall values are available immediately when the user opens the yield 
/// prediction form, reducing reliance on real-time API calls.
///
/// Key Features:
/// 1. Caching: Stores computed seasonal values using SharedPreferences.
/// 2. TTL (Time-To-Live): Automatically invalidates data after 6 hours to ensure accuracy.
/// 3. Background Pre-fetching: Updates the cache silently whenever possible.
import 'package:shared_preferences/shared_preferences.dart';

import 'rainfall_service.dart';

class RainfallPreloadService {
  static double? _cachedRainfall;

  static const _keyValue = "cached_rainfall";
  static const _keyTime = "rainfall_timestamp";

  /// Pre-fetches seasonal rainfall data and caches it locally.
  /// This method first attempts to load from SharedPreferences. If the cached 
  /// data is older than 6 hours, it triggers a background API call via RainfallService.
  static Future<void> preload(String location) async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getDouble(_keyValue);
    final timestamp = prefs.getInt(_keyTime);

    // Validate cache age (6 hours TTL)
    if (cached != null && timestamp != null) {
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      if (age < 6 * 60 * 60 * 1000) {
        _cachedRainfall = cached; // Data is fresh, populate the static variable
      }
    }

    try {
      // Update the cache with latest data from the weather service
      final rainfall = await RainfallService.getSeasonalRainfall(location);
      _cachedRainfall = rainfall;

      await prefs.setDouble(_keyValue, rainfall);
      await prefs.setInt(_keyTime, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Silent catch to prevent background errors from affecting the UI flow
    }
  }

  /// Returns the currently cached rainfall value.
  /// May return null if preload() hasn't completed or cache is expired.
  static double? getCached() {
    return _cachedRainfall;
  }
}
