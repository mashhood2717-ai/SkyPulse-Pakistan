import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/metar_service.dart';
import '../services/alert_service.dart';
import '../services/push_notification_service.dart';
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

  WeatherProvider() {
    // Register callback for FCM alerts
    PushNotificationService.setOnAlertsReceived((alerts) {
      print('🔔 [WeatherProvider] Received ${alerts.length} alert(s) from FCM');
      setActiveAlerts(alerts);
    });

    // Ensure FCM token is refreshed on app launch
    _ensureFCMTokenFresh();
  }

  WeatherData? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get cityName => _cityName;
  String get countryCode => _countryCode;
  bool get usingMetar => _usingMetar;
  MetarData? get metarData => _metarData;
  List<Map<String, dynamic>> get activeAlerts => _activeAlerts;

  /// Get count of unread alerts
  int get unreadAlertCount {
    return _activeAlerts.where((alert) => !(alert['isRead'] ?? false)).length;
  }

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

      // Subscribe to Firebase topics
      await _subscribeToTopics();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // If location fetch fails, try a lightweight fallback to a default city
      print('⚠️ [WeatherProvider] fetchWeatherByLocation failed: $e');
      try {
        if (_cityName.isEmpty) {
          print('🔄 [WeatherProvider] Falling back to default city: Islamabad');
          await fetchWeatherByCity('Islamabad');
          return;
        }
      } catch (fallbackErr) {
        print('❌ [WeatherProvider] Fallback fetch failed: $fallbackErr');
      }

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

      // Subscribe to Firebase topics
      await _subscribeToTopics();

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

  // Refresh weather data
  Future<void> refresh() async {
    if (_cityName.isEmpty || _cityName == 'Current Location') {
      await fetchWeatherByLocation();
    } else {
      await fetchWeatherByCity(_cityName);
    }
  }

  // Restore cached weather
  void restoreCachedWeather(
    WeatherData cachedData,
    String cityName,
    String countryCode,
  ) {
    _weatherData = cachedData;
    _cityName = cityName;
    _countryCode = countryCode;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Fetch weather with METAR attempt
  Future<void> _fetchWeatherWithMetarAttempt(
    String cityName,
    double latitude,
    double longitude,
  ) async {
    // Fetch API data first
    final apiData = await _weatherService.getWeatherByCoordinates(
      latitude,
      longitude,
    );

    // Try to get METAR data
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
  }

  /// Subscribe to Firebase topics based on current location
  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to global alerts topic
      await PushNotificationService.subscribeToTopic('all_alerts');
      print('✅ Subscribed to topic: all_alerts');

      // Subscribe to city-specific topic
      if (_cityName.isNotEmpty && _cityName != 'Current Location') {
        String cityTopic = _cityName.toLowerCase().replaceAll(' ', '_');
        await PushNotificationService.subscribeToTopic('${cityTopic}_alerts');
        print('✅ Subscribed to topic: ${cityTopic}_alerts');
      }
    } catch (e) {
      print('⚠️ Error subscribing to topics: $e');
    }
  }

  /// Set active alerts - only notify if alerts changed
  /// Preserves read status from previous alerts
  void setActiveAlerts(List<Map<String, dynamic>> alerts) {
    // Preserve read status from existing alerts
    final Map<String, bool> readStatus = {};
    for (var alert in _activeAlerts) {
      final messageId = alert['messageId'] as String?;
      if (messageId != null) {
        readStatus[messageId] = alert['isRead'] ?? false;
      }
    }

    // Process new alerts - ensure each has a consistent messageId
    for (var alert in alerts) {
      var messageId = alert['messageId'] as String?;

      // If no messageId, generate one from the alert content for consistency
      if (messageId == null || messageId.isEmpty) {
        final title = (alert['title'] ?? '').toString();
        final message = (alert['message'] ?? '').toString();
        // Use title as primary ID if available, otherwise use title+message hash
        messageId = title.isNotEmpty
            ? title
            : '${title}_${message}'.hashCode.toString();
        alert['messageId'] = messageId;
      }

      // Apply preserved read status if it exists
      if (readStatus.containsKey(messageId)) {
        alert['isRead'] = readStatus[messageId]!;
      } else if (alert['isRead'] == null) {
        alert['isRead'] = false; // Default to unread for new alerts
      }
    }

    // Check if alerts actually changed by comparing keys and count
    bool alertsChanged = false;

    if (alerts.length != _activeAlerts.length) {
      alertsChanged = true;
    } else {
      // Compare alert messageIds to detect real changes
      final newIds = alerts.map((a) => a['messageId'] ?? '').toSet();
      final oldIds = _activeAlerts.map((a) => a['messageId'] ?? '').toSet();
      alertsChanged = newIds != oldIds;
    }

    // Only update and notify if alerts actually changed
    if (alertsChanged) {
      _activeAlerts = alerts;
      notifyListeners();
      print('🔔 Alerts updated: ${alerts.length} active alert(s)');
      print('   📖 Preserved read status for existing alerts');
    } else {
      // Even if alerts didn't change, update read status if we have new ones
      _activeAlerts = alerts;
      print(
          '🔔 Alerts refreshed: ${alerts.length} active alert(s) (no new alerts)');
      print('   📖 Read status preserved');
    }
  }

  /// Update read status for an alert
  void updateAlertReadStatus(int index, bool isRead) {
    if (index >= 0 && index < _activeAlerts.length) {
      _activeAlerts[index]['isRead'] = isRead;
      notifyListeners();

      final alertTitle = _activeAlerts[index]['title'] ?? 'Alert';
      final unreadCount = unreadAlertCount;
      print('📖 Alert "$alertTitle" marked as ${isRead ? 'read' : 'unread'}');
      print('📊 Unread alerts: $unreadCount');
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

  /// Ensure FCM token is fresh (called on app startup)
  Future<void> _ensureFCMTokenFresh() async {
    try {
      print('🔑 [FCMToken] Ensuring FCM token is fresh on app startup...');

      // Try to get current token
      final currentToken = await PushNotificationService.getFCMToken();

      if (currentToken != null && currentToken.isNotEmpty) {
        print(
            '✅ [FCMToken] Current token is available: ${currentToken.substring(0, 20)}...');
      } else {
        print('⚠️ [FCMToken] No token available, requesting new one...');
        final newToken = await PushNotificationService.getFCMToken();
        if (newToken != null) {
          print(
              '✅ [FCMToken] Token obtained: ${newToken.substring(0, 20)}...');
        }
      }

      // Also re-subscribe to topics to ensure persistence
      print('📢 [FCMToken] Re-subscribing to topics...');
      await _subscribeToTopics();
    } catch (e) {
      print('⚠️ [FCMToken] Error ensuring fresh token: $e');
    }
  }

  /// Stop alert refresh timer
  void _stopAlertRefreshTimer() {
    _alertRefreshTimer?.cancel();
    _alertRefreshTimer = null;
    print('⏹️ [AlertRefresh] Timer stopped');
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

  @override
  void dispose() {
    _stopAlertRefreshTimer();
    super.dispose();
  }
}
