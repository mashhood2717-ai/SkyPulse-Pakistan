import 'package:flutter/foundation.dart';
import '../models/weather_model.dart';

/// Caches weather data for favorite locations to enable instant card navigation
/// and persistent display when switching between favorites
class FavoritesCacheService extends ChangeNotifier {
  /// Maps city names to their cached weather data
  /// Format: { 'CityName': WeatherData }
  final Map<String, WeatherData> _weatherCache = {};

  /// Maps city names to their metadata
  /// Format: { 'CityName': { 'country': 'CountryCode', 'timestamp': DateTime } }
  final Map<String, Map<String, dynamic>> _metadataCache = {};

  /// Get cached weather for a specific city
  WeatherData? getWeatherForCity(String cityName) {
    return _weatherCache[cityName];
  }

  /// Get all cached cities
  List<String> getCachedCities() {
    return _weatherCache.keys.toList();
  }

  /// Check if weather data exists for a city
  bool hasCachedWeather(String cityName) {
    return _weatherCache.containsKey(cityName);
  }

  /// Cache weather data for a city
  void cacheWeather(String cityName, WeatherData weatherData,
      {String country = '', String countryCode = ''}) {
    _weatherCache[cityName] = weatherData;
    _metadataCache[cityName] = {
      'country': country,
      'countryCode': countryCode,
      'timestamp': DateTime.now(),
    };
    notifyListeners();
    print('✅ [FavoritesCacheService] Cached weather for $cityName');
  }

  /// Remove cached data for a city
  void removeCache(String cityName) {
    _weatherCache.remove(cityName);
    _metadataCache.remove(cityName);
    notifyListeners();
    print('❌ [FavoritesCacheService] Cleared cache for $cityName');
  }

  /// Clear all cached data
  void clearAll() {
    _weatherCache.clear();
    _metadataCache.clear();
    notifyListeners();
    print('🗑️ [FavoritesCacheService] Cleared all cache');
  }

  /// Get metadata for a cached city
  Map<String, dynamic>? getMetadata(String cityName) {
    return _metadataCache[cityName];
  }

  /// Check if cache for a city is older than specified duration
  bool isCacheExpired(String cityName, Duration maxAge) {
    final metadata = _metadataCache[cityName];
    if (metadata == null) return true;

    final timestamp = metadata['timestamp'] as DateTime;
    final age = DateTime.now().difference(timestamp);
    return age > maxAge;
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'total_cached_cities': _weatherCache.length,
      'total_metadata': _metadataCache.length,
    };
  }
}
