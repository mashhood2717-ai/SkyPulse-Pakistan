import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/metar_service.dart';
import '../services/alert_service.dart';
import '../models/metar_model.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final MetarService _metarService = MetarService();
  final AlertService _alertService = AlertService();

  WeatherData? _weatherData;
  bool _isLoading = false;
  String? _error;
  String _cityName = '';
  String _countryCode = '';
  bool _usingMetar = false;
  MetarData? _metarData;
  List<Map<String, dynamic>> _activeAlerts = [];
  Timer? _alertRefreshTimer;
  double? _lastLocationLat;
  double? _lastLocationLon;

  WeatherData? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get cityName => _cityName;
  String get countryCode => _countryCode;
  bool get usingMetar => _usingMetar;
  MetarData? get metarData => _metarData;
  List<Map<String, dynamic>> get activeAlerts => _activeAlerts;

  // Fetch weather by current location
  Future<void> fetchWeatherByLocation() async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    notifyListeners();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Try to fetch METAR for current location
      await _fetchWeatherWithMetarAttempt(
        'Current Location',
        position.latitude,
        position.longitude,
      );

      // Fetch alerts
      try {
        final alerts = await _alertService.checkAlertsForLocation(
          position.latitude,
          position.longitude,
        );
        setActiveAlerts(alerts);

        // Store location for auto-refresh
        _lastLocationLat = position.latitude;
        _lastLocationLon = position.longitude;

        // Start alert refresh timer
        _startAlertRefreshTimer();
      } catch (e) {
        print('⚠️ Error fetching alerts: $e');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch weather by city name
  Future<void> fetchWeatherByCity(String cityName) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    notifyListeners();

    try {
      // Get coordinates first
      final location = await _weatherService.getCoordinatesFromCity(cityName);

      // Always try METAR first for any city
      await _fetchWeatherWithMetarAttempt(
        cityName,
        location['latitude'],
        location['longitude'],
      );

      _cityName = location['name'];
      _countryCode = location['country'];

      // Fetch alerts
      try {
        final alerts = await _alertService.checkAlertsForLocation(
          location['latitude'],
          location['longitude'],
        );
        setActiveAlerts(alerts);

        // Store location for auto-refresh
        _lastLocationLat = location['latitude'];
        _lastLocationLon = location['longitude'];

        // Start alert refresh timer
        _startAlertRefreshTimer();
      } catch (e) {
        print('⚠️ Error fetching alerts: $e');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch weather by coordinates directly (for cached location)
  Future<void> fetchWeatherByCoordinates(
      double latitude, double longitude) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    notifyListeners();

    try {
      // Directly fetch weather with METAR attempt
      await _fetchWeatherWithMetarAttempt(
        _cityName.isNotEmpty ? _cityName : 'Current Location',
        latitude,
        longitude,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Try to fetch METAR data for ANY location, fallback to API if not available
  Future<void> _fetchWeatherWithMetarAttempt(
    String cityName,
    double latitude,
    double longitude,
  ) async {
    try {
      print('🔍 Attempting METAR for $cityName at ($latitude, $longitude)');

      // 1. Fetch API data (we need this for forecast, UV, and sunrise/sunset anyway)
      final apiData = await _weatherService.getWeatherByCoordinates(
        latitude,
        longitude,
      );

      // 2. Try to get METAR data
      final metarData = await _metarService.getMetarDataForCity(
        cityName,
        latitude,
        longitude,
      );

      if (metarData != null) {
        // ✅ METAR AVAILABLE - Use it for current weather
        _metarData = metarData;

        // Get sunrise/sunset from API forecast (today's data)
        final sunrise =
            apiData.forecast.isNotEmpty ? apiData.forecast[0].sunrise : null;
        final sunset =
            apiData.forecast.isNotEmpty ? apiData.forecast[0].sunset : null;

        // Convert METAR to CurrentWeather WITH sunrise/sunset for correct day/night detection
        final metarCurrent = metarData.toCurrentWeather(
          sunrise: sunrise,
          sunset: sunset,
        );

        // Create enhanced current weather combining METAR + API UV
        final enhancedCurrent = CurrentWeather(
          temperature: metarCurrent.temperature,
          humidity: metarCurrent.humidity,
          windSpeed: metarCurrent.windSpeed,
          weatherCode: metarCurrent.weatherCode,
          pressure: metarCurrent.pressure,
          cloudCover: metarCurrent.cloudCover,
          isDay: metarCurrent
              .isDay, // Now correctly calculated using location's sunrise/sunset
          visibility: metarCurrent.visibility,
          uvIndex: apiData.current.uvIndex, // UV from API
        );

        _weatherData = WeatherData(
          current: enhancedCurrent,
          forecast: apiData.forecast,
          hourlyTemperatures: apiData.hourlyTemperatures,
          hourlyWeatherCodes: apiData.hourlyWeatherCodes,
          hourlyPrecipitation: apiData.hourlyPrecipitation,
        );
        _usingMetar = true;
        _cityName = cityName;

        print('✈️ Using METAR data for $cityName');
        print('   Airport: ${metarData.icaoCode}');
        print('   Temp: ${metarData.temperature}°C');
        print(
            '   Wind: ${metarData.windDirection}° at ${metarData.windSpeed} kt');
        print('   Visibility: ${metarData.visibility} km');
        print('   Weather: ${metarData.weatherCondition}');
        print('   Clouds: ${metarData.clouds}');
        print('   Is Day: ${metarCurrent.isDay}');
      } else {
        // ❌ NO METAR - Use API data only
        _weatherData = apiData;
        _usingMetar = false;
        _metarData = null;
        _cityName = cityName;
        print('🌐 Using API data for $cityName (no METAR available)');
      }
    } catch (e) {
      print('❌ Error fetching weather: $e');
      throw e;
    }
  }

  // Refresh current weather
  Future<void> refresh() async {
    if (_cityName.isEmpty || _cityName == 'Current Location') {
      await fetchWeatherByLocation();
    } else {
      await fetchWeatherByCity(_cityName);
    }
  }

  // Restore cached weather data (for instant page switching)
  void restoreCachedWeather(
      WeatherData cachedData, String cityName, String countryCode) {
    _weatherData = cachedData;
    _cityName = cityName;
    _countryCode = countryCode;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Get METAR info string for display
  String? getMetarInfo() {
    if (!_usingMetar || _metarData == null) return null;

    return 'METAR ${_metarData!.icaoCode} - ${_metarData!.rawMetar}';
  }

  /// Get data source badge text
  String getDataSource() {
    if (_usingMetar) {
      return '✈️ METAR (${_metarData?.icaoCode ?? 'Airport'})';
    }
    return '🌐 Open-Meteo API';
  }

  /// Set active alerts - only notify if alerts changed
  void setActiveAlerts(List<Map<String, dynamic>> alerts) {
    // Check if alerts actually changed
    bool alertsChanged = false;

    if (alerts.length != _activeAlerts.length) {
      alertsChanged = true;
    } else {
      // Compare alert contents
      for (int i = 0; i < alerts.length; i++) {
        if (alerts[i].toString() != _activeAlerts[i].toString()) {
          alertsChanged = true;
          break;
        }
      }
    }

    // Only update and notify if alerts actually changed
    if (alertsChanged) {
      _activeAlerts = alerts;
      notifyListeners();
      print('🔔 Alerts updated: ${alerts.length} active alert(s)');
    }
  }

  /// Start auto-refresh timer for alerts
  void _startAlertRefreshTimer() {
    // Cancel existing timer
    _alertRefreshTimer?.cancel();

    print('🔄 [AlertRefresh] Starting auto-refresh timer...');

    // Start new timer - refresh every 30 seconds
    _alertRefreshTimer = Timer.periodic(Duration(seconds: 30), (_) async {
      if (_lastLocationLat != null && _lastLocationLon != null) {
        print('🔄 [AlertRefresh] Auto-refreshing alerts at ${DateTime.now()}');
        try {
          final alerts = await _alertService.checkAlertsForLocation(
            _lastLocationLat!,
            _lastLocationLon!,
          );
          setActiveAlerts(alerts);
        } catch (e) {
          print('❌ [AlertRefresh] Error: $e');
        }
      }
    });

    print('✅ [AlertRefresh] Timer started - will check every 30 seconds');
  }

  /// Stop alert refresh timer
  void _stopAlertRefreshTimer() {
    _alertRefreshTimer?.cancel();
    _alertRefreshTimer = null;
    print('⏹️ [AlertRefresh] Timer stopped');
  }

  @override
  void dispose() {
    _stopAlertRefreshTimer();
    super.dispose();
  }
}
