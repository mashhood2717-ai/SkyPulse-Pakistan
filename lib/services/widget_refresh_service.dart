import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../utils/log.dart';
import 'company_weather_service.dart';
import 'home_widget_service.dart';
import 'weather_service.dart';

/// Background refresh for the home-screen widget.
///
/// The widget provider only re-renders values already in SharedPreferences,
/// and the only writer was the running app — so the widget froze at whatever
/// the user last saw and its "Updated HH:MM" line quietly lied. This runs the
/// same fetch path on a schedule and writes the same keys.
class WidgetRefreshService {
  static const String taskName = 'skypulse.widget.refresh';

  /// Android will not run a periodic task more often than every 15 minutes;
  /// the widget itself redraws on a 30-minute cadence.
  static const Duration interval = Duration(minutes: 30);

  static const String _lastLatKey = 'widget_last_latitude';
  static const String _lastLonKey = 'widget_last_longitude';
  static const String _lastCityKey = 'widget_last_city';

  /// Remember where the app last showed weather, so a background run has
  /// somewhere to fetch for even if it cannot obtain a fresh GPS fix.
  static Future<void> rememberLocation({
    required double latitude,
    required double longitude,
    required String city,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatKey, latitude);
    await prefs.setDouble(_lastLonKey, longitude);
    await prefs.setString(_lastCityKey, city);
  }

  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        widgetRefreshDispatcher,
        isInDebugMode: false,
      );
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: interval,
        // `keep` so re-registering on every launch does not reset the
        // schedule and push the next run back by a full interval.
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
      );
      logDebug('[WidgetRefresh] Periodic task registered');
    } catch (e) {
      logDebug('[WidgetRefresh] Could not register task: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(taskName);
    } catch (e) {
      logDebug('[WidgetRefresh] Could not cancel task: $e');
    }
  }

  /// Fetch and push fresh values into the widget. Runs on the background
  /// isolate, so it must not touch any provider or BuildContext.
  static Future<bool> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      double? latitude = prefs.getDouble(_lastLatKey);
      double? longitude = prefs.getDouble(_lastLonKey);
      String city = prefs.getString(_lastCityKey) ?? '';

      // Prefer a current fix, but never block on it.
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 12));
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        logDebug('[WidgetRefresh] Using stored location: $e');
      }

      if (latitude == null || longitude == null) {
        logDebug('[WidgetRefresh] No location available, skipping');
        return true;
      }

      final weatherService = WeatherService();
      final apiData =
          await weatherService.getWeatherByCoordinates(latitude, longitude);

      // Same source priority as the app: station first, then the model.
      final station = await CompanyWeatherService()
          .getNearestStation(latitude, longitude)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);

      final current = station == null
          ? apiData.current
          : station.toCurrentWeather(apiData.current);

      if (city.isEmpty) {
        final place = await weatherService.getCityFromCoordinates(
          latitude,
          longitude,
        );
        city = (place['name'] as String?) ?? 'Current Location';
      }

      await HomeWidgetService.updateWidget(
        city: city,
        current: current,
        weatherData: apiData,
        aqiIndex: station?.aqiIndex ?? apiData.aqiIndex,
        source: station == null ? 'LIVE WEATHER' : 'LIVE STATION',
      );

      logDebug('[WidgetRefresh] Widget updated for $city');
      return true;
    } catch (e) {
      logDebug('[WidgetRefresh] Failed: $e');
      // Returning false lets WorkManager retry with backoff.
      return false;
    }
  }
}

/// WorkManager entry point. Must be a top-level function.
@pragma('vm:entry-point')
void widgetRefreshDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != WidgetRefreshService.taskName) return true;
    return WidgetRefreshService.refresh();
  });
}
