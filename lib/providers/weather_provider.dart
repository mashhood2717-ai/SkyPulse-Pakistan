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
  final double _currentLatitude = 33.6699; // Default: Islamabad
  final double _currentLongitude = 73.0794; // Default: Islamabad

  // Cache for instant refresh
  WeatherData? _cachedWeatherData;
  String _cachedCityName = '';
  String _cachedCountryCode = '';
  bool _cachedUsingMetar = false;
  MetarData? _cachedMetarData;

  WeatherProvider() {
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
  double get latitude => _currentLatitude;
  double get longitude => _currentLongitude;

  /// Get count of unread alerts
  int get unreadAlertCount {
    return _activeAlerts.where((alert) => !(alert['isRead'] ?? false)).length;
  }

  // Fetch weather by current location (URGENT - blocks on this)
  Future<void> fetchWeatherByLocation() async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;

    // 🚀 SHOW CACHE FIRST (instant)
    if (_cachedWeatherData != null) {
      print('💾 Showing cached weather data...');
      _weatherData = _cachedWeatherData;
      _cityName = _cachedCityName;
      _countryCode = _cachedCountryCode;
      _usingMetar = _cachedUsingMetar;
      _metarData = _cachedMetarData;
      _error = null;
      notifyListeners();
    }

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

      // ⏱️ Get location with 10 second timeout (avoid slow GPS)
      late Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print(
                '⚠️ Location timeout - will use cached location if available');
            throw TimeoutException('Location request timeout');
          },
        );
      } catch (locErr) {
        print('⚠️ Location fetch failed during refresh: $locErr');
        // If we have cached location data, just refresh from API without location change
        if (_cachedWeatherData != null && _cityName.isNotEmpty) {
          print('✅ Using cached location for refresh: $_cityName');
          // Just fetch fresh data for the same location
          final lat = _currentLatitude;
          final lon = _currentLongitude;
          await _fetchWeatherWithMetarAttempt(_cityName, lat, lon);
          _isLoading = false;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 300));
          _doBackgroundTasks(lat, lon);
          return;
        }
        rethrow;
      }

      // 🌐 URGENT: Get city name from coordinates first
      final location = await _weatherService.getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 🌐 URGENT: Fetch fresh weather data and cache it
      await _fetchWeatherWithMetarAttempt(
        location['name'] ?? 'Current Location',
        position.latitude,
        position.longitude,
      );

      // Update country code from reverse geocoding
      if (location['country'] != null && location['country'].isNotEmpty) {
        _countryCode = location['country'];
      }

      // 💾 Update cache with fresh data
      _cachedWeatherData = _weatherData;
      _cachedCityName = _cityName;
      _cachedCountryCode = _countryCode;
      _cachedUsingMetar = _usingMetar;
      _cachedMetarData = _metarData;

      _isLoading = false;
      notifyListeners();

      // Small delay to ensure UI updates before refresh completes
      await Future.delayed(const Duration(milliseconds: 300));

      // NOW do background tasks without blocking UI
      _doBackgroundTasks(position.latitude, position.longitude);
    } catch (e) {
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

  /// Background tasks that don't block UI
  void _doBackgroundTasks(double latitude, double longitude) {
    Future.microtask(() async {
      try {
        // Fetch alerts
        final alerts = await _alertService.checkAlertsForLocation(
          latitude,
          longitude,
        );
        setActiveAlerts(alerts);
        print('✅ Background: Alerts fetched');
      } catch (e) {
        print('⚠️ Background: Error fetching alerts: $e');
      }

      try {
        // Subscribe to Firebase topics
        await _subscribeToTopics();
        print('✅ Background: Firebase topics subscribed');
      } catch (e) {
        print('⚠️ Background: Error subscribing to topics: $e');
      }
    });
  }

  // Fetch weather by city name (URGENT - blocks on this)
  Future<void> fetchWeatherByCity(String cityName) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    notifyListeners();

    try {
      // Get coordinates first
      final location = await _weatherService.getCoordinatesFromCity(cityName);

      // URGENT: Fetch weather with METAR
      await _fetchWeatherWithMetarAttempt(
        cityName,
        location['latitude'],
        location['longitude'],
      );

      _cityName = location['name'];
      _countryCode = location['country'];

      // 💾 Update cache with fresh data
      _cachedWeatherData = _weatherData;
      _cachedCityName = _cityName;
      _cachedCountryCode = _countryCode;
      _cachedUsingMetar = _usingMetar;
      _cachedMetarData = _metarData;

      _isLoading = false;
      notifyListeners();

      // Small delay to ensure UI updates before refresh completes
      await Future.delayed(const Duration(milliseconds: 300));

      // Background tasks
      _doBackgroundTasks(
        location['latitude'],
        location['longitude'],
      );
    } catch (e) {
      print('⚠️ [fetchWeatherByCity] Error: $e');

      // 🔄 Fallback: Use cached data if available
      if (_cachedWeatherData != null) {
        print(
            '💾 [fetchWeatherByCity] Using cached data for $_cachedCityName due to network error');
        _weatherData = _cachedWeatherData;
        _cityName = _cachedCityName;
        _countryCode = _cachedCountryCode;
        _usingMetar = _cachedUsingMetar;
        _metarData = _cachedMetarData;
        _error = 'Using cached data - network unavailable';
      } else {
        _error = e.toString();
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch weather by coordinates directly (for cached location or specific places)
  Future<void> fetchWeatherByCoordinates(
    double latitude,
    double longitude, {
    String? cityName,
    String? countryCode,
  }) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;

    // Update city/country if provided (for specific location searches)
    if (cityName != null) {
      _cityName = cityName;
    }
    if (countryCode != null) {
      _countryCode = countryCode;
    }

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
      print('⚠️ [fetchWeatherByCoordinates] Error: $e');

      // 🔄 Fallback: Use cached data if available
      if (_cachedWeatherData != null) {
        print(
            '💾 [fetchWeatherByCoordinates] Using cached data due to network error');
        _weatherData = _cachedWeatherData;
        _cityName = _cachedCityName;
        _countryCode = _cachedCountryCode;
        _error = 'Using cached data - network unavailable';
      } else {
        _error = e.toString();
      }

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
    try {
      // 🚀 URGENT: Fetch API data FIRST with timeout
      final apiData = await _weatherService
          .getWeatherByCoordinates(
        latitude,
        longitude,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ [API Timeout] Weather API took too long');
          throw TimeoutException('Weather API request timeout');
        },
      );

      // Display API data right away (don't wait for METAR)
      _weatherData = apiData;
      _usingMetar = false;
      _metarData = null;
      _cityName = cityName;
      _error = null;
      notifyListeners();
      print('🌐 Weather API data loaded for $cityName');

      // 📡 BACKGROUND: Fetch METAR and AQI in background without blocking UI
      // Pass cityName to ensure background tasks validate against the correct city
      _fetchMetarInBackground(cityName, latitude, longitude, apiData);
      _fetchAQIInBackground(cityName, latitude, longitude, apiData);
    } catch (e) {
      print('❌ [_fetchWeatherWithMetarAttempt] Failed: $e');
      _error = 'Failed to fetch weather: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Fetch AQI data in background
  void _fetchAQIInBackground(
    String targetCity,
    double latitude,
    double longitude,
    WeatherData apiData,
  ) {
    print(
        '🌍 [AQI] Starting background fetch for lat=$latitude, lon=$longitude');
    _weatherService.getAQIByCoordinates(latitude, longitude).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        print('⏱️ [AQI] Request timeout after 8 seconds');
        return {'current': {}};
      },
    ).then((aqiData) {
      // ⚠️ CRITICAL: Check if we're STILL viewing the same city (case-insensitive)
      if (_cityName.toLowerCase() != targetCity.toLowerCase()) {
        print('⏭️ [AQI] Ignoring AQI for $targetCity - now viewing $_cityName');
        return;
      }

      print('🌍 [AQI] Response received: ${aqiData.keys.toList()}');
      print('🌍 [AQI] Full response: $aqiData');

      if (aqiData['current'] != null) {
        print('🌍 [AQI] Current object exists: ${aqiData['current']}');

        // Try different possible keys for AQI
        var aqi = aqiData['current']['us_aqi'] ?? aqiData['current']['aqi'];
        print('🌍 [AQI] Parsed aqi value: $aqi (type: ${aqi?.runtimeType})');

        if (aqi != null) {
          int aqiInt = 0;
          if (aqi is int) {
            aqiInt = aqi;
          } else if (aqi is double) {
            aqiInt = aqi.toInt();
          } else if (aqi is String) {
            aqiInt = int.tryParse(aqi) ?? 0;
          }

          print('✅ [AQI] AQI Index: $aqiInt - Updating weather data');
          // Update weather data with AQI - preserve current data if METAR is active
          _weatherData = WeatherData(
            current: _usingMetar ? _weatherData!.current : apiData.current,
            forecast: apiData.forecast,
            hourlyTemperatures: apiData.hourlyTemperatures,
            hourlyWeatherCodes: apiData.hourlyWeatherCodes,
            hourlyPrecipitation: apiData.hourlyPrecipitation,
            hourlyTimes: apiData.hourlyTimes,
            aqiIndex: aqiInt,
          );
          print(
              '🌍 [AQI] Weather data updated. aqiIndex = ${_weatherData?.aqiIndex}');
          notifyListeners();
        } else {
          print('⚠️ [AQI] us_aqi and aqi both null in response');
        }
      } else {
        print('⚠️ [AQI] current is null in response');
      }
    }).catchError((e) {
      print('❌ [AQI] Error fetching AQI: $e');
    });
  }

  /// Fetch METAR in background and update UI if it arrives
  void _fetchMetarInBackground(
    String targetCity,
    double latitude,
    double longitude,
    WeatherData apiData,
  ) {
    // Don't await this - let it run in background
    _metarService
        .getMetarDataForCity(targetCity, latitude, longitude)
        .timeout(
          const Duration(seconds: 3),
          onTimeout: () => null,
        )
        .then((metarData) {
      // ⚠️ CRITICAL: Check if we're STILL viewing the same city (case-insensitive)
      // If user swiped to a different location, ignore this METAR
      if (_cityName.toLowerCase() != targetCity.toLowerCase()) {
        print(
            '⏭️ [METAR] Ignoring METAR for $targetCity - now viewing $_cityName');
        return;
      }

      // Only update if METAR was successfully fetched
      if (metarData != null) {
        print('✈️ METAR arrived! Updating weather data for $targetCity...');
        _metarData = metarData;

        // Get sunrise/sunset from API forecast
        final sunrise =
            apiData.forecast.isNotEmpty ? apiData.forecast[0].sunrise : null;
        final sunset =
            apiData.forecast.isNotEmpty ? apiData.forecast[0].sunset : null;

        // Convert METAR to CurrentWeather
        final metarCurrent = metarData.toCurrentWeather(
          sunrise: sunrise,
          sunset: sunset,
        );

        // Create enhanced current weather combining METAR + API UV + API dew point/wind gust
        final enhancedCurrent = CurrentWeather(
          temperature: metarCurrent.temperature,
          humidity: metarCurrent.humidity,
          windSpeed: metarCurrent.windSpeed,
          windGust: metarCurrent.windGust, // Include wind gust from METAR
          windDirection: metarCurrent.windDirection, // Include wind direction
          dewPoint: metarCurrent.dewPoint, // Include dew point from METAR
          weatherCode: metarCurrent.weatherCode,
          pressure: metarCurrent.pressure,
          cloudCover: metarCurrent.cloudCover,
          isDay: metarCurrent.isDay,
          visibility: metarCurrent.visibility,
          uvIndex: apiData.current.uvIndex,
          customDescription:
              metarCurrent.customDescription, // Pass METAR condition
        );

        _weatherData = WeatherData(
          current: enhancedCurrent,
          forecast: apiData.forecast,
          hourlyTemperatures: apiData.hourlyTemperatures,
          hourlyWeatherCodes: apiData.hourlyWeatherCodes,
          hourlyPrecipitation: apiData.hourlyPrecipitation,
          hourlyTimes: apiData.hourlyTimes,
          aqiIndex: _weatherData?.aqiIndex, // PRESERVE AQI INDEX
        );
        _usingMetar = true;

        print('✈️ Using METAR data for $cityName');
        print('   Airport: ${metarData.icaoCode}');
        print('   Temp: ${metarData.temperature}°C');
        print(
            '   Wind: ${metarData.windDirection}° at ${metarData.windSpeed} kt');
        print('   Visibility: ${metarData.visibility} km');
        print('   Is Day: ${metarCurrent.isDay}');

        // Notify listeners only if METAR was successful
        notifyListeners();
      }
    }).catchError((e) {
      // Silently ignore METAR errors - API data is already displayed
      print('⏭️ METAR unavailable, keeping API data');
    });
  }

  /// Subscribe to Firebase topics based on current location
  Future<void> _subscribeToTopics() async {
    try {
      // Subscribe to global alerts topic
      await PushNotificationService.subscribeToTopic('all_alerts');
      print('✅ Subscribed to topic: all_alerts');

      // Subscribe to city-specific topic
      if (_cityName.isNotEmpty && _cityName != 'Current Location') {
        // Sanitize city name: transliterate accents to ASCII, keep only valid Firebase topic chars
        // Firebase topics allow: [a-zA-Z0-9-_]
        String cityTopic = _sanitizeTopicName(_cityName);

        print(
            '📝 [Topic Sanitization] Original: "$_cityName" → Sanitized: "$cityTopic"');

        if (cityTopic.isNotEmpty) {
          try {
            await PushNotificationService.subscribeToTopic(
                '${cityTopic}_alerts');
            print('✅ Subscribed to topic: ${cityTopic}_alerts');
          } catch (topicErr) {
            print('⚠️ Error subscribing to ${cityTopic}_alerts: $topicErr');
            // Don't rethrow - continue with other subscriptions
          }
        } else {
          print(
              '⚠️ City name "$_cityName" sanitized to empty string, skipping topic subscription');
        }
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
        messageId =
            title.isNotEmpty ? title : '${title}_$message'.hashCode.toString();
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

  /// Update read status for an alert by matching its properties
  void markAlertAsRead(Map<String, dynamic> alert) {
    for (int i = 0; i < _activeAlerts.length; i++) {
      // Match by title and timestamp
      if (_activeAlerts[i]['title'] == alert['title'] &&
          _activeAlerts[i]['timestamp'] == alert['timestamp']) {
        _activeAlerts[i]['isRead'] = true;
        notifyListeners();

        final alertTitle = _activeAlerts[i]['title'] ?? 'Alert';
        final unreadCount = unreadAlertCount;
        print('📖 Alert "$alertTitle" marked as read');
        print('📊 Unread alerts: $unreadCount');
        return;
      }
    }
  }

  /// Update read status for an alert (legacy, by index)
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

  /// Delete a single alert by matching its properties
  void deleteAlert(Map<String, dynamic> alert) {
    _activeAlerts.removeWhere((a) =>
        a['title'] == alert['title'] && a['timestamp'] == alert['timestamp']);
    notifyListeners();
    print('🗑️ Alert "${alert['title']}" deleted');
    print('📊 Remaining alerts: ${_activeAlerts.length}');
  }

  /// Clear all alerts
  void clearAllAlerts() {
    final count = _activeAlerts.length;
    _activeAlerts.clear();
    notifyListeners();
    print('🗑️ Cleared all $count alerts');
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
          print('✅ [FCMToken] Token obtained: ${newToken.substring(0, 20)}...');
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
    if (_metarData != null) {
      return '✈️ METAR (${_metarData?.icaoCode ?? 'Airport'})';
    }
    return '🌐 Open-Meteo API';
  }

  /// Sanitize city name for Firebase topics: transliterate accents to ASCII
  /// Firebase topics only allow: [a-zA-Z0-9_-]
  String _sanitizeTopicName(String cityName) {
    // Map of accented characters to ASCII equivalents
    const accentMap = {
      'á': 'a',
      'à': 'a',
      'ā': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ē': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ī': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ō': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ū': 'u',
      'ü': 'u',
      'û': 'u',
      'ç': 'c',
      'ć': 'c',
      'ñ': 'n',
      'ń': 'n',
      'ý': 'y',
      'ỹ': 'y',
      'š': 's',
      'ś': 's',
      'ž': 'z',
      'ź': 'z',
      'ł': 'l',
      'đ': 'd',
      'ð': 'd',
      'þ': 'th',
      'ø': 'o',
      'æ': 'ae',
    };

    String result = cityName.toLowerCase().replaceAll(' ', '_');

    // Replace accented characters
    accentMap.forEach((accented, ascii) {
      result = result.replaceAll(accented, ascii);
    });

    // Keep only valid Firebase topic chars: a-z, 0-9, _, -
    result = result
        .split('')
        .map((char) => (char.codeUnitAt(0) >= 97 &&
                    char.codeUnitAt(0) <= 122) || // a-z
                (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) || // 0-9
                char == '_' ||
                char == '-'
            ? char
            : '')
        .join('');

    return result;
  }

  @override
  void dispose() {
    _stopAlertRefreshTimer();
    super.dispose();
  }
}
