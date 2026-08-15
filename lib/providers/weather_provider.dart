import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../models/weather_model.dart';
import '../services/weather_service.dart';
import '../services/company_weather_service.dart';
import '../services/metar_service.dart';
import '../services/alert_service.dart';
import '../services/alert_store.dart';
import '../services/push_notification_service.dart';
import '../services/home_widget_service.dart';
import '../services/widget_refresh_service.dart';
import '../models/company_weather_station.dart';
import '../models/metar_model.dart';
import '../utils/city_areas.dart';
import '../utils/log.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _weatherService = WeatherService();
  final CompanyWeatherService _companyWeatherService = CompanyWeatherService();
  final MetarService _metarService = MetarService();
  final AlertService _alertService = AlertService();

  WeatherData? _weatherData;
  bool _isLoading = false;
  String? _error;
  String _cityName = '';
  String _countryCode = '';
  bool _usingMetar = false;
  bool _usingCompanyStation = false;
  CompanyWeatherStation? _companyStation;
  MetarData? _metarData;
  List<Map<String, dynamic>> _activeAlerts = [];
  Timer? _alertRefreshTimer;
  Future<void>? _locationFetch;

  /// True when the last alert check could not reach the service.
  bool _alertsUnavailable = false;

  /// The city used for alert topic subscription. Deliberately separate from
  /// _cityName, which is a street-level display label ("I-8/3 Islamabad") and
  /// would produce a topic nobody publishes to.
  String _alertCity = '';
  double _currentLatitude =
      33.6699; // Default: Islamabad (will update on app start)
  double _currentLongitude =
      73.0794; // Default: Islamabad (will update on app start)

  // Cache for instant refresh
  WeatherData? _cachedWeatherData;
  String _cachedCityName = '';
  String _cachedCountryCode = '';
  bool _cachedUsingMetar = false;
  bool _cachedUsingCompanyStation = false;
  CompanyWeatherStation? _cachedCompanyStation;
  MetarData? _cachedMetarData;

  WeatherProvider() {
    // Don't fetch location here - permissions not granted yet
    // Instead, initialize FCM and fetch location when fetchWeatherByLocation is called
    if (!kIsWeb) {
      _ensureFCMTokenFresh();
    }
  }

  WeatherData? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get cityName => _cityName;
  String get countryCode => _countryCode;
  bool get usingMetar => _usingMetar;
  bool get usingCompanyStation => _usingCompanyStation;
  CompanyWeatherStation? get companyStation => _companyStation;
  MetarData? get metarData => _metarData;
  List<Map<String, dynamic>> get activeAlerts => _activeAlerts;
  bool get alertsUnavailable => _alertsUnavailable;
  double get latitude => _currentLatitude;
  double get longitude => _currentLongitude;

  /// Get count of unread alerts
  int get unreadAlertCount {
    return _activeAlerts.where((alert) => !(alert['isRead'] ?? false)).length;
  }

  /// Update the home screen widget with current weather data
  void _updateHomeWidget() {
    if (kIsWeb) return;

    if (_weatherData != null && _cityName.isNotEmpty) {
      HomeWidgetService.updateWidget(
        city: _cityName,
        current: _weatherData!.current,
        weatherData: _weatherData,
        aqiIndex: _weatherData!.aqiIndex,
        source: _widgetSourceLabel,
      );
      // So the background refresh has somewhere to fetch for.
      WidgetRefreshService.rememberLocation(
        latitude: _currentLatitude,
        longitude: _currentLongitude,
        city: _cityName,
      );
    }
  }

  String get _widgetSourceLabel {
    if (_usingCompanyStation) return 'LIVE STATION';
    if (_usingMetar) return 'LIVE METAR';
    return 'LIVE WEATHER';
  }

  /// The launch/refresh fetch currently in flight, or a completed future when
  /// nothing is running. Screens can await this instead of starting their own.
  Future<void> get currentLocationFetch =>
      _locationFetch ?? Future<void>.value();

  // Fetch weather by current location (URGENT - blocks on this)
  //
  // Re-entrant callers share one request. Three separate call sites used to
  // fire this in the same frame at launch, which raced three responses into
  // one provider and tripled the API cost of a cold start.
  Future<void> fetchWeatherByLocation() {
    final inFlight = _locationFetch;
    if (inFlight != null) {
      logDebug('⏳ [WeatherProvider] Location fetch already running - joining it');
      return inFlight;
    }

    // Errors are absorbed here rather than propagated: _fetchWeatherByLocation
    // already records them on `error` for the UI, and this future is handed to
    // several callers at once, so a rethrow would surface as an unhandled
    // async error in whichever one did not attach a handler.
    final future = _fetchWeatherByLocation().catchError((Object e) {
      logDebug('⚠️ [WeatherProvider] Location fetch failed: $e');
    }).whenComplete(() {
      _locationFetch = null;
    });

    _locationFetch = future;
    return future;
  }

  Future<void> _fetchWeatherByLocation() async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    _usingCompanyStation = false;
    _companyStation = null;

    // 🚀 SHOW CACHE FIRST (instant)
    if (_cachedWeatherData != null) {
      logDebug('💾 Showing cached weather data...');
      _weatherData = _cachedWeatherData;
      _cityName = _cachedCityName;
      _countryCode = _cachedCountryCode;
      _usingMetar = _cachedUsingMetar;
      _usingCompanyStation = _cachedUsingCompanyStation;
      _companyStation = _cachedCompanyStation;
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
            logDebug(
                '⚠️ Location timeout - will use cached location if available');
            throw TimeoutException('Location request timeout');
          },
        );
      } catch (locErr) {
        logDebug('⚠️ Location fetch failed during refresh: $locErr');
        // If we have cached location data, just refresh from API without location change
        if (_cachedWeatherData != null && _cityName.isNotEmpty) {
          logDebug('✅ Using cached location for refresh: $_cityName');
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

      // 📍 Update current location coordinates
      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      logDebug(
          '✅ Current location updated: $_currentLatitude, $_currentLongitude');

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
      _alertCity = (location['city'] as String?) ?? '';

      // 💾 Update cache with fresh data
      _cachedWeatherData = _weatherData;
      _cachedCityName = _cityName;
      _cachedCountryCode = _countryCode;
      _cachedUsingMetar = _usingMetar;
      _cachedUsingCompanyStation = _usingCompanyStation;
      _cachedCompanyStation = _companyStation;
      _cachedMetarData = _metarData;

      _isLoading = false;
      notifyListeners();

      // Small delay to ensure UI updates before refresh completes
      await Future.delayed(const Duration(milliseconds: 300));

      // NOW do background tasks without blocking UI
      _doBackgroundTasks(position.latitude, position.longitude);
    } catch (e) {
      logDebug('⚠️ [WeatherProvider] fetchWeatherByLocation failed: $e');
      try {
        if (_cityName.isEmpty) {
          logDebug('🔄 [WeatherProvider] Falling back to default city: Islamabad');
          await fetchWeatherByCity('Islamabad');
          return;
        }
      } catch (fallbackErr) {
        logDebug('❌ [WeatherProvider] Fallback fetch failed: $fallbackErr');
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
        final alerts = await _alertService.checkAlertsForLocation(
          latitude,
          longitude,
        );
        _alertsUnavailable = false;
        await setActiveAlerts(alerts);
        logDebug('✅ Background: Alerts fetched');
      } on AlertServiceUnavailable catch (e) {
        // Distinct from an empty list: the Alerts tab says so rather than
        // showing a reassuring "All Clear".
        _alertsUnavailable = true;
        notifyListeners();
        logDebug('⚠️ Background: Alert service unavailable: $e');
      } catch (e) {
        logDebug('⚠️ Background: Error fetching alerts: $e');
      }

      try {
        // Subscribe to Firebase topics
        await _subscribeToTopics();
        logDebug('✅ Background: Firebase topics subscribed');
      } catch (e) {
        logDebug('⚠️ Background: Error subscribing to topics: $e');
      }
    });
  }

  // Fetch weather by city name (URGENT - blocks on this)
  Future<void> fetchWeatherByCity(String cityName) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    _usingCompanyStation = false;
    _companyStation = null;
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

      _currentLatitude = location['latitude'];
      _currentLongitude = location['longitude'];
      _cityName = location['name'];
      _countryCode = location['country'];
      _alertCity = (location['city'] as String?) ?? location['name'] ?? '';

      // 💾 Update cache with fresh data
      _cachedWeatherData = _weatherData;
      _cachedCityName = _cityName;
      _cachedCountryCode = _countryCode;
      _cachedUsingMetar = _usingMetar;
      _cachedUsingCompanyStation = _usingCompanyStation;
      _cachedCompanyStation = _companyStation;
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
      logDebug('⚠️ [fetchWeatherByCity] Error: $e');

      // 🔄 Fallback: Use cached data if available
      if (_cachedWeatherData != null) {
        logDebug(
            '💾 [fetchWeatherByCity] Using cached data for $_cachedCityName due to network error');
        _weatherData = _cachedWeatherData;
        _cityName = _cachedCityName;
        _countryCode = _cachedCountryCode;
        _usingMetar = _cachedUsingMetar;
        _usingCompanyStation = _cachedUsingCompanyStation;
        _companyStation = _cachedCompanyStation;
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
    String? alertCity,
  }) async {
    _isLoading = true;
    _error = null;
    _usingMetar = false;
    _usingCompanyStation = false;
    _companyStation = null;

    // Update city/country if provided (for specific location searches)
    if (cityName != null) {
      _cityName = cityName;
    }
    if (countryCode != null) {
      _countryCode = countryCode;
    }
    if (alertCity != null && alertCity.isNotEmpty) {
      _alertCity = alertCity;
    }

    _currentLatitude = latitude;
    _currentLongitude = longitude;
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
      logDebug('⚠️ [fetchWeatherByCoordinates] Error: $e');

      // 🔄 Fallback: Use cached data if available
      if (_cachedWeatherData != null) {
        logDebug(
            '💾 [fetchWeatherByCoordinates] Using cached data due to network error');
        _weatherData = _cachedWeatherData;
        _cityName = _cachedCityName;
        _countryCode = _cachedCountryCode;
        _usingMetar = _cachedUsingMetar;
        _usingCompanyStation = _cachedUsingCompanyStation;
        _companyStation = _cachedCompanyStation;
        _metarData = _cachedMetarData;
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
    String countryCode, {
    bool usingMetar = false,
    bool usingCompanyStation = false,
    CompanyWeatherStation? companyStation,
    MetarData? metarData,
  }) {
    _weatherData = cachedData;
    _cityName = cityName;
    _countryCode = countryCode;
    _usingMetar = usingMetar;
    _usingCompanyStation = usingCompanyStation;
    _companyStation = companyStation;
    _metarData = metarData;
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
      final apiFuture =
          _weatherService.getWeatherByCoordinates(latitude, longitude).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          logDebug('⏱️ [API Timeout] Weather API took too long');
          throw TimeoutException('Weather API request timeout');
        },
      );

      final stationFuture =
          _companyWeatherService.getNearestStation(latitude, longitude).timeout(
                const Duration(seconds: 8),
                onTimeout: () => null,
              );

      final apiData = await apiFuture;
      final station = await stationFuture;
      WeatherData displayData;
      bool usingMetar = false;
      bool usingCompanyStation = false;
      CompanyWeatherStation? companyStation;
      MetarData? metarData;

      if (station != null) {
        displayData = WeatherData(
          current: station.toCurrentWeather(apiData.current),
          forecast: apiData.forecast,
          hourlyTemperatures: apiData.hourlyTemperatures,
          hourlyWeatherCodes: apiData.hourlyWeatherCodes,
          hourlyPrecipitation: apiData.hourlyPrecipitation,
          hourlyTimes: apiData.hourlyTimes,
          hourlyIsDay: apiData.hourlyIsDay,
          aqiIndex: station.aqiIndex ?? apiData.aqiIndex,
        );
        usingCompanyStation = true;
        companyStation = station;
      } else {
        metarData = await _metarService
            .getMetarDataForCity(cityName, latitude, longitude)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => null,
            );

        if (metarData != null) {
          displayData = _buildMetarWeatherData(metarData, apiData);
          usingMetar = true;
        } else {
          displayData = apiData;
        }
      }

      // Source priority: active station, then METAR, then Open-Meteo.
      _weatherData = displayData;
      _usingMetar = usingMetar;
      _usingCompanyStation = usingCompanyStation;
      _companyStation = companyStation;
      _metarData = metarData;
      _cityName = cityName;
      _error = null;
      notifyListeners();
      logDebug('Weather data loaded for $cityName from $_widgetSourceLabel');

      // 📱 Update home screen widget
      if (companyStation != null) {
        logDebug(
          '[CompanyWeather] Station data loaded for $cityName from ${companyStation.name}',
        );
      } else if (metarData != null) {
        logDebug('[METAR] Data loaded for $cityName from ${metarData.icaoCode}');
      } else {
        logDebug('[OpenMeteo] Using API fallback for $cityName');
      }
      _updateHomeWidget();

      // Pass cityName to ensure background tasks validate against the correct city.
      if (companyStation == null) {
        _fetchAQIInBackground(cityName, latitude, longitude, displayData);
      }
    } catch (e) {
      logDebug('❌ [_fetchWeatherWithMetarAttempt] Failed: $e');
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
    logDebug(
        '🌍 [AQI] Starting background fetch for lat=$latitude, lon=$longitude');
    _weatherService.getAQIByCoordinates(latitude, longitude).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        logDebug('⏱️ [AQI] Request timeout after 8 seconds');
        return {'current': {}};
      },
    ).then((aqiData) {
      // ⚠️ CRITICAL: Check if we're STILL viewing the same city area
      // Use flexible matching for neighborhoods (e.g., Samanabad ↔ Lahore)
      if (!CityAreas.isSameArea(_cityName, targetCity)) {
        logDebug(
            '⏭️ [AQI] Ignoring AQI for $targetCity - now viewing $_cityName (different area)');
        return;
      }

      logDebug('🌍 [AQI] Response received: ${aqiData.keys.toList()}');
      logDebug('🌍 [AQI] Full response: $aqiData');

      if (aqiData['current'] != null) {
        logDebug('🌍 [AQI] Current object exists: ${aqiData['current']}');

        // Try different possible keys for AQI
        var aqi = aqiData['current']['us_aqi'] ?? aqiData['current']['aqi'];
        logDebug('🌍 [AQI] Parsed aqi value: $aqi (type: ${aqi?.runtimeType})');

        if (aqi != null) {
          int aqiInt = 0;
          if (aqi is int) {
            aqiInt = aqi;
          } else if (aqi is double) {
            aqiInt = aqi.toInt();
          } else if (aqi is String) {
            aqiInt = int.tryParse(aqi) ?? 0;
          }

          logDebug('✅ [AQI] AQI Index: $aqiInt - Updating weather data');
          // Update weather data with AQI - preserve current data if METAR is active
          _weatherData = WeatherData(
            current: (_usingMetar || _usingCompanyStation)
                ? _weatherData!.current
                : apiData.current,
            forecast: apiData.forecast,
            hourlyTemperatures: apiData.hourlyTemperatures,
            hourlyWeatherCodes: apiData.hourlyWeatherCodes,
            hourlyPrecipitation: apiData.hourlyPrecipitation,
            hourlyTimes: apiData.hourlyTimes,
            hourlyIsDay: apiData.hourlyIsDay,
            aqiIndex: aqiInt,
          );
          logDebug(
              '🌍 [AQI] Weather data updated. aqiIndex = ${_weatherData?.aqiIndex}');

          // 💾 Update local cache to preserve AQI when swiping through favorites
          _cachedWeatherData = _weatherData;
          _cachedUsingCompanyStation = _usingCompanyStation;
          _cachedCompanyStation = _companyStation;
          notifyListeners();
          _updateHomeWidget();
        } else {
          logDebug('⚠️ [AQI] us_aqi and aqi both null in response');
        }
      } else {
        logDebug('⚠️ [AQI] current is null in response');
      }
    }).catchError((e) {
      logDebug('❌ [AQI] Error fetching AQI: $e');
    });
  }

  WeatherData _buildMetarWeatherData(MetarData metarData, WeatherData apiData) {
    final sunrise =
        apiData.forecast.isNotEmpty ? apiData.forecast[0].sunrise : null;
    final sunset =
        apiData.forecast.isNotEmpty ? apiData.forecast[0].sunset : null;

    final metarCurrent = metarData.toCurrentWeather(
      sunrise: sunrise,
      sunset: sunset,
    );

    final enhancedCurrent = CurrentWeather(
      temperature: metarCurrent.temperature,
      humidity: metarCurrent.humidity,
      windSpeed: metarCurrent.windSpeed,
      windGust: metarCurrent.windGust,
      windDirection: metarCurrent.windDirection,
      dewPoint: metarCurrent.dewPoint,
      weatherCode: metarCurrent.weatherCode,
      pressure: metarCurrent.pressure,
      cloudCover: metarCurrent.cloudCover,
      isDay: metarCurrent.isDay,
      visibility: metarCurrent.visibility,
      uvIndex: apiData.current.uvIndex,
      rainRate: apiData.current.rainRate,
      dailyRain: apiData.current.dailyRain,
      customDescription: metarCurrent.customDescription,
    );

    return WeatherData(
      current: enhancedCurrent,
      forecast: apiData.forecast,
      hourlyTemperatures: apiData.hourlyTemperatures,
      hourlyWeatherCodes: apiData.hourlyWeatherCodes,
      hourlyPrecipitation: apiData.hourlyPrecipitation,
      hourlyTimes: apiData.hourlyTimes,
      hourlyIsDay: apiData.hourlyIsDay,
      aqiIndex: apiData.aqiIndex,
    );
  }

  /// Fetch METAR in background and update UI if it arrives
  // ignore: unused_element
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
          const Duration(
              seconds:
                  10), // Increase timeout to allow airport search to complete
          onTimeout: () => null,
        )
        .then((metarData) {
      // ⚠️ CRITICAL: Check if we're STILL viewing the same city area
      // If user swiped to a completely different location, ignore this METAR
      // Use flexible matching for neighborhoods (e.g., Samanabad ↔ Lahore)
      if (!CityAreas.isSameArea(_cityName, targetCity)) {
        logDebug(
            '⏭️ [METAR] Ignoring METAR for $targetCity - now viewing $_cityName (different area)');
        return;
      }

      // Only update if METAR was successfully fetched
      if (metarData != null) {
        logDebug('✈️ METAR arrived! Updating weather data for $targetCity...');
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
          rainRate: apiData.current.rainRate,
          dailyRain: apiData.current.dailyRain,
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
          hourlyIsDay: apiData.hourlyIsDay,
          aqiIndex: _weatherData?.aqiIndex, // PRESERVE AQI INDEX
        );
        _usingMetar = true;

        // 💾 Update cache so METAR data persists when swiping back and forth
        _cachedWeatherData = _weatherData;
        _cachedUsingMetar = _usingMetar;
        _cachedMetarData = _metarData;

        logDebug('✈️ Using METAR data for $_cityName');
        logDebug('   Airport: ${metarData.icaoCode}');
        logDebug('   Temp: ${metarData.temperature}°C');
        logDebug(
            '   Wind: ${metarData.windDirection}° at ${metarData.windSpeed} kt');
        logDebug('   Visibility: ${metarData.visibility} km');
        logDebug('   Is Day: ${metarCurrent.isDay}');

        // Notify listeners only if METAR was successful
        notifyListeners();
        _updateHomeWidget();
      }
    }).catchError((e) {
      // Silently ignore METAR errors - API data is already displayed
      logDebug('⏭️ METAR unavailable, keeping API data');
    });
  }

  /// Subscribe to Firebase topics based on current location.
  ///
  /// Exactly two topics are ever active: the global one and the city the user
  /// is currently looking at. Moving to a new city unsubscribes the old one,
  /// otherwise a device accumulates every city it has ever visited and
  /// city-targeted alerts stop meaning anything.
  Future<void> _subscribeToTopics() async {
    if (kIsWeb) return;

    try {
      await PushNotificationService.subscribeToTopic('all_alerts');

      final city = _alertCity.isNotEmpty ? _alertCity : _cityName;
      if (city.isEmpty || city == 'Current Location') return;

      // Firebase topics allow [a-zA-Z0-9-_] only.
      final cityTopic = _sanitizeTopicName(CityAreas.alertCityFor(city));
      if (cityTopic.isEmpty) {
        logDebug('⚠️ City "$city" sanitized to empty, skipping topic');
        return;
      }

      final topic = '${cityTopic}_alerts';
      final previous = await PushNotificationService.getSubscribedCityTopic();
      if (previous == topic) return;

      if (previous != null && previous.isNotEmpty) {
        await PushNotificationService.unsubscribeFromTopic(previous);
      }

      await PushNotificationService.subscribeToTopic(topic);
      await PushNotificationService.setSubscribedCityTopic(topic);
      logDebug('✅ City alert topic: $topic (was ${previous ?? 'none'})');
    } catch (e) {
      logDebug('⚠️ Error subscribing to topics: $e');
    }
  }

  /// Replace the alert list from the API.
  ///
  /// Alerts the user dismissed stay dismissed and read state survives a
  /// restart: both live in [AlertStore], because this list is overwritten on
  /// every poll and anything held only in memory was silently undone.
  Future<void> setActiveAlerts(List<Map<String, dynamic>> alerts) async {
    final dismissed = await AlertStore.dismissedIds();
    final read = await AlertStore.readIds();

    // Alerts pushed while the app was closed are merged in, so the tab agrees
    // with what actually appeared in the notification tray.
    final pending = await AlertStore.takePendingPushes();

    final merged = <String, Map<String, dynamic>>{};
    for (final alert in [...alerts, ...pending]) {
      final id = AlertStore.idFor(alert);
      if (dismissed.contains(id)) continue;

      alert['messageId'] = id;
      alert['isRead'] = read.contains(id);
      merged[id] = alert;
    }

    final next = merged.values.toList();
    final changed = !_sameAlertIds(next, _activeAlerts);
    _activeAlerts = next;

    if (changed) {
      logDebug('🔔 Alerts updated: ${next.length} active alert(s)');
    }
    notifyListeners();
  }

  bool _sameAlertIds(
    List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b,
  ) {
    if (a.length != b.length) return false;
    final idsA = a.map(AlertStore.idFor).toSet();
    final idsB = b.map(AlertStore.idFor).toSet();
    return idsA.containsAll(idsB) && idsB.containsAll(idsA);
  }

  /// Load persisted alert state at startup so the badge and list are correct
  /// before the first poll returns.
  Future<void> loadStoredAlerts() async {
    final pending = await AlertStore.takePendingPushes();
    if (pending.isEmpty) return;
    await setActiveAlerts([..._activeAlerts, ...pending]);
  }

  /// Mark an alert read, durably.
  Future<void> markAlertAsRead(Map<String, dynamic> alert) async {
    final id = AlertStore.idFor(alert);
    for (final existing in _activeAlerts) {
      if (AlertStore.idFor(existing) == id) {
        if (existing['isRead'] == true) return;
        existing['isRead'] = true;
        notifyListeners();
        break;
      }
    }
    await AlertStore.markRead(id);
  }

  /// Delete a single alert, durably.
  Future<void> deleteAlert(Map<String, dynamic> alert) async {
    final id = AlertStore.idFor(alert);
    _activeAlerts.removeWhere((a) => AlertStore.idFor(a) == id);
    notifyListeners();
    await AlertStore.markDismissed([id]);
    logDebug('🗑️ Alert dismissed: ${alert['title']}');
  }

  /// Clear every alert currently shown, durably.
  Future<void> clearAllAlerts() async {
    final ids = _activeAlerts.map(AlertStore.idFor).toList();
    _activeAlerts = [];
    notifyListeners();
    await AlertStore.markDismissed(ids);
    logDebug('🗑️ Cleared ${ids.length} alert(s)');
  }

  /// Ensure FCM token is fresh (called on app startup)
  Future<void> _ensureFCMTokenFresh() async {
    try {
      logDebug('🔑 [FCMToken] Ensuring FCM token is fresh on app startup...');

      // Try to get current token
      final currentToken = await PushNotificationService.getFCMToken();

      if (currentToken != null && currentToken.isNotEmpty) {
        logDebug(
            '✅ [FCMToken] Current token is available: ${currentToken.substring(0, 20)}...');
      } else {
        logDebug('⚠️ [FCMToken] No token available, requesting new one...');
        final newToken = await PushNotificationService.getFCMToken();
        if (newToken != null) {
          logDebug('✅ [FCMToken] Token obtained: ${newToken.substring(0, 20)}...');
        }
      }

      // Also re-subscribe to topics to ensure persistence
      logDebug('📢 [FCMToken] Re-subscribing to topics...');
      await _subscribeToTopics();
    } catch (e) {
      logDebug('⚠️ [FCMToken] Error ensuring fresh token: $e');
    }
  }

  /// Stop alert refresh timer
  void _stopAlertRefreshTimer() {
    _alertRefreshTimer?.cancel();
    _alertRefreshTimer = null;
    logDebug('⏹️ [AlertRefresh] Timer stopped');
  }

  /// Get METAR info string for display
  String? getMetarInfo() {
    if (!_usingMetar || _metarData == null) return null;

    return 'METAR ${_metarData!.icaoCode} - ${_metarData!.rawMetar}';
  }

  /// Get data source badge text
  String getDataSource() {
    if (_usingCompanyStation && _companyStation != null) {
      final distance = _companyStation!.distanceKm;
      final distanceText =
          distance == null ? '' : ' - ${distance.toStringAsFixed(1)} km away';
      return 'Station: ${_companyStation!.name}$distanceText';
    }
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
