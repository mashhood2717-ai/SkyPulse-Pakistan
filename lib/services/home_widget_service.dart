import 'package:home_widget/home_widget.dart';
import '../models/weather_model.dart';

/// Service to update the home screen widget with weather data
class HomeWidgetService {
  static const String appGroupId = 'com.mashhood.skypulse';
  static const String iOSWidgetName = 'WeatherWidget';
  static const String androidWidgetName = 'WeatherWidgetProvider';

  /// Initialize the home widget
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
    print('✅ [HomeWidget] Initialized');
  }

  /// Update widget with weather data
  static Future<void> updateWidget({
    required String city,
    required CurrentWeather current,
  }) async {
    try {
      // Save data to SharedPreferences (accessible by native widget)
      await HomeWidget.saveWidgetData<String>('city', city);
      await HomeWidget.saveWidgetData<String>(
        'temperature',
        current.temperature.round().toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'condition',
        _getWeatherCondition(current.weatherCode),
      );
      await HomeWidget.saveWidgetData<String>(
        'humidity',
        '${current.humidity.round()}%',
      );
      await HomeWidget.saveWidgetData<String>(
        'wind',
        '${current.windSpeed.round()} km/h',
      );
      await HomeWidget.saveWidgetData<int>('weather_code', current.weatherCode);
      await HomeWidget.saveWidgetData<bool>('is_day', current.isDay);

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      print('✅ [HomeWidget] Updated: $city ${current.temperature.round()}°C');
    } catch (e) {
      print('❌ [HomeWidget] Error updating widget: $e');
    }
  }

  /// Get weather condition text from WMO code
  static String _getWeatherCondition(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 66:
      case 67:
        return 'Freezing Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow Grains';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with Hail';
      default:
        return 'Unknown';
    }
  }

  /// Check if widget is pinned/added
  static Future<bool> isWidgetPinned() async {
    try {
      final isPinned = await HomeWidget.getInstalledWidgets();
      return isPinned.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Request to pin widget (Android only)
  static Future<void> requestPinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        androidName: androidWidgetName,
      );
    } catch (e) {
      print('❌ [HomeWidget] Error requesting pin: $e');
    }
  }
}
