/// CORNXPERT FRONTEND - RAINFALL SERVICE
///
/// This service provides historical weather data and estimates seasonal rainfall.
/// It interacts with the WeatherAPI to fetch historical precipitation data and 
/// uses agricultural domain logic to project total rainfall for a cropping season.
///
/// Key Calculations:
/// 1. Historical Sum: Fetches daily precipitation for the last 30 or 60 days.
/// 2. Season Determination: Identifies if the current month falls in 'Yala' or 'Maha'.
/// 3. Projection: Applies a growth factor to recent rainfall to estimate the season total.
import 'dart:convert';

import 'package:http/http.dart' as http;

class RainfallService {
  static const String _apiKey = "64ce095e13d0428a811113548260505";

  static Future<double> getLast60DaysRainfall(String location) async {
    return _getRainfallForDays(location, 60);
  }

  static Future<double> getLast30DaysRainfall(String location) async {
    return _getRainfallForDays(location, 30);
  }

  /// Loops through the last 30/60 days to calculate the cumulative rainfall (mm).
  /// Note: This performs multiple serial HTTP requests and should be used with 
  /// caution on slow networks. Ideally, the result should be cached.
  static Future<double> _getRainfallForDays(
    String location,
    int days,
  ) async {
    final today = DateTime.now();
    final startDate = today.subtract(Duration(days: days));

    double totalRainfall = 0.0;

    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final url =
          "https://api.weatherapi.com/v1/history.json?key=$_apiKey&q=$location&dt=$formattedDate";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rain =
            data['forecast']['forecastday'][0]['day']['totalprecip_mm'] as num;
        totalRainfall += rain.toDouble();
      }
    }

    return totalRainfall;
  }

  /// Identifies the current agro-ecological season in Sri Lanka.
  /// Yala: April to September.
  /// Maha: October to March (the 'wet' season).
  static String getCurrentSeason() {
    final month = DateTime.now().month;

    if (month >= 4 && month <= 9) {
      return "Yala";
    }
    return "Maha";
  }

  static double getSeasonBase(String season) {
    if (season == "Yala") return 500;
    return 1100;
  }

  /// Estimates total seasonal rainfall based on the last 30 days of data.
  /// Uses a base seasonal constant plus a multiplier (factor) to project 
  /// the remaining rainfall based on recent observations.
  /// The result is clamped between 300mm and 1700mm to stay within realistic bounds.
  static double estimateSeasonalRainfall(double recentRain, String season) {
    final base = getSeasonBase(season);
    final factor = (season == "Yala") ? 2.5 : 3.5;
    double estimated = base + (recentRain * factor);

    if (estimated < 300) estimated = 300;
    if (estimated > 1700) estimated = 1700;

    return estimated;
  }

  static Future<double> getSeasonalRainfall(String location) async {
    final season = getCurrentSeason();
    final recentRain = await getLast30DaysRainfall(location);
    final seasonalRain = estimateSeasonalRainfall(recentRain, season);

    print("Season: $season");
    print("Recent Rain: $recentRain");
    print("Seasonal Rain: $seasonalRain");

    return seasonalRain;
  }
}
