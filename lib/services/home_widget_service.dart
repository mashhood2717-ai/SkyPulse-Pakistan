import 'package:home_widget/home_widget.dart';
import '../models/weather_model.dart';
import '../utils/log.dart';

/// Service to update the home screen widget with weather data.
class HomeWidgetService {
  // Must match the applicationId; iOS app groups are prefixed with 'group.'.
  static const String appGroupId = 'group.com.mashhood.skypulsepk';
  static const String iOSWidgetName = 'WeatherWidget';
  static const String androidWidgetName = 'WeatherWidgetProvider';

  /// Initialize the home widget.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(appGroupId);
    logDebug('[HomeWidget] Initialized');
  }

  /// Update widget with weather data.
  static Future<void> updateWidget({
    required String city,
    required CurrentWeather current,
    WeatherData? weatherData,
    int? aqiIndex,
    String source = 'LIVE WEATHER',
  }) async {
    try {
      final forecastToday = weatherData?.forecast.isNotEmpty == true
          ? weatherData!.forecast.first
          : null;
      final dailyRain =
          current.dailyRain ?? forecastToday?.precipitationSum ?? 0.0;
      final windDirection = current.windSpeed <= 0.4
          ? 'Calm'
          : _getWindDirection(current.windDirection);
      final highLow = forecastToday == null
          ? '--'
          : '${forecastToday.maxTemp.round()}/${forecastToday.minTemp.round()}';
      final aqi = aqiIndex ?? weatherData?.aqiIndex;

      await HomeWidget.saveWidgetData<String>('city', city);
      await HomeWidget.saveWidgetData<String>(
        'temperature',
        current.temperature.round().toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'condition',
        current.weatherDescription,
      );
      await HomeWidget.saveWidgetData<String>(
        'humidity',
        '${current.humidity.round()}%',
      );
      await HomeWidget.saveWidgetData<String>(
        'wind',
        '${current.windSpeed.round()} km/h',
      );
      await HomeWidget.saveWidgetData<String>(
        'wind_speed',
        '${current.windSpeed.round()} km/h',
      );
      await HomeWidget.saveWidgetData<String>('wind_direction', windDirection);
      await HomeWidget.saveWidgetData<String>(
        'feels_like',
        current.feelsLike.round().toString(),
      );
      await HomeWidget.saveWidgetData<String>(
        'pressure',
        '${current.pressure.round()} hPa',
      );
      await HomeWidget.saveWidgetData<String>(
        'rain_rate',
        '${current.rainRate.toStringAsFixed(1)} mm/h',
      );
      await HomeWidget.saveWidgetData<String>(
        'daily_rain',
        '${dailyRain.toStringAsFixed(1)} mm',
      );
      await HomeWidget.saveWidgetData<String>('aqi', aqi?.toString() ?? '--');
      await HomeWidget.saveWidgetData<String>('high_low', highLow);
      await HomeWidget.saveWidgetData<String>('source', source);
      await HomeWidget.saveWidgetData<String>('updated', _updatedLabel());
      await HomeWidget.saveWidgetData<int>('weather_code', current.weatherCode);
      await HomeWidget.saveWidgetData<bool>('is_day', current.isDay);

      await HomeWidget.updateWidget(
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );

      logDebug(
        '[HomeWidget] Updated: $city ${current.temperature.round()}C, rain ${dailyRain.toStringAsFixed(1)} mm',
      );
    } catch (e) {
      logDebug('[HomeWidget] Error updating widget: $e');
    }
  }

  static String _getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = degrees % 360;
    final index = ((normalized + 22.5) / 45).floor() % directions.length;
    return directions[index];
  }

  static String _updatedLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'Updated $hour:$minute';
  }

  /// Check if widget is pinned/added.
  static Future<bool> isWidgetPinned() async {
    try {
      final isPinned = await HomeWidget.getInstalledWidgets();
      return isPinned.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Request to pin widget (Android only).
  static Future<void> requestPinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        androidName: androidWidgetName,
      );
    } catch (e) {
      logDebug('[HomeWidget] Error requesting pin: $e');
    }
  }
}
