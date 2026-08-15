import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';
import 'geocoding_service.dart';
import '../utils/log.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String aqiUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  // Fetch weather data by coordinates
  Future<WeatherData> getWeatherByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$baseUrl?latitude=$latitude&longitude=$longitude'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_probability_max,precipitation_sum,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,uv_index_max'
          '&hourly=temperature_2m,weather_code,cloud_cover,precipitation_probability,wind_speed_10m,wind_gusts_10m,wind_direction_10m,dew_point_2m,is_day,uv_index,visibility'
          '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,rain,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_gusts_10m,wind_direction_10m'
          '&models=icon_seamless'
          '&timezone=auto'
          '&past_days=0'
          '&forecast_days=7');

      logDebug('🌐 [WeatherService] Fetching: $url');
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          logDebug('⏱️ [WeatherService] Request timeout after 15 seconds');
          throw TimeoutException('Weather API request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // metno_seamless may return null UV fields; fetch UV from default model as fallback.
        await _applyUvFallbackIfMissing(data, latitude, longitude);

        logDebug('✅ [WeatherService] Response received');
        logDebug('📊 [WeatherService] Top-level keys: ${data.keys.toList()}');
        if (data['daily'] != null) {
          logDebug(
              '📊 [WeatherService] Daily keys: ${data['daily'].keys.toList()}');
          logDebug(
              '📊 [WeatherService] Daily times count: ${data['daily']['time']?.length ?? 0}');
        }

        return WeatherData.fromJson(data);
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      logDebug('❌ Error fetching weather: $e');
      throw Exception('Error fetching weather: $e');
    }
  }

  Future<void> _applyUvFallbackIfMissing(
    Map<String, dynamic> data,
    double latitude,
    double longitude,
  ) async {
    final hourly = data['hourly'] as Map<String, dynamic>?;
    final daily = data['daily'] as Map<String, dynamic>?;

    final hourlyUv = hourly?['uv_index'] as List?;
    final dailyUvList = daily?['uv_index_max'] as List?;

    final bool hourlyUvMissing = hourlyUv == null ||
        hourlyUv.isEmpty ||
        hourlyUv.every((v) => v == null);
    final bool dailyUvMissing = dailyUvList == null ||
        dailyUvList.isEmpty ||
        dailyUvList.every((v) => v == null);
    if (!hourlyUvMissing && !dailyUvMissing) return;

    final fallbackUrl = Uri.parse(
        '$baseUrl?latitude=$latitude&longitude=$longitude'
        '&daily=uv_index_max'
        '&hourly=uv_index'
        '&timezone=auto'
        '&forecast_days=7');

    try {
      logDebug('🌤️ [WeatherService] UV fallback request: $fallbackUrl');
      final fallbackResponse = await http.get(fallbackUrl).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('UV fallback request timeout'),
      );

      if (fallbackResponse.statusCode != 200) {
        logDebug(
            '⚠️ [WeatherService] UV fallback failed: ${fallbackResponse.statusCode}');
        return;
      }

      final fallbackData = json.decode(fallbackResponse.body);
      final fallbackHourly = fallbackData['hourly'] as Map<String, dynamic>?;
      final fallbackDaily = fallbackData['daily'] as Map<String, dynamic>?;

      if (hourlyUvMissing && hourly != null && fallbackHourly != null) {
        hourly['uv_index'] = fallbackHourly['uv_index'];
      }
      if (dailyUvMissing && daily != null && fallbackDaily != null) {
        daily['uv_index_max'] = fallbackDaily['uv_index_max'];
      }
      logDebug('✅ [WeatherService] UV fallback applied');
    } catch (e) {
      logDebug('⚠️ [WeatherService] UV fallback error: $e');
    }
  }

  // Fetch AQI data by coordinates
  Future<Map<String, dynamic>> getAQIByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$aqiUrl?latitude=$latitude&longitude=$longitude'
          '&current=us_aqi,pm10,pm2_5,nitrogen_dioxide,ozone,sulphur_dioxide'
          '&forecast_days=7');

      logDebug('🌍 [AQIService] Fetching: $url');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          logDebug('⏱️ [AQIService] Request timeout after 10 seconds');
          throw TimeoutException('AQI request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        logDebug('✅ [AQIService] Response received');
        logDebug('📊 [AQIService] Response: $data');
        logDebug('📊 [AQIService] Current: ${data['current']}');
        logDebug('📊 [AQIService] Current AQI: ${data['current']?['us_aqi']}');
        return data;
      } else {
        logDebug('⚠️ [AQIService] Failed to fetch AQI: ${response.statusCode}');
        logDebug('⚠️ [AQIService] Response body: ${response.body}');
        return {
          'current': {'us_aqi': null}
        };
      }
    } catch (e) {
      logDebug('❌ Error fetching AQI: $e');
      return {
        'current': {'us_aqi': null}
      };
    }
  }
  // ---------------------------------------------------------------------
  // Geocoding. All of these delegate to GeocodingService, which runs on free
  // providers (Nominatim + Open-Meteo). Google was removed: its Geocoding and
  // Places web-service APIs cannot be restricted to an Android app, so any key
  // shipped in the APK is extractable.
  // ---------------------------------------------------------------------

  /// City name -> coordinates.
  Future<Map<String, dynamic>> getCoordinatesFromCity(String cityName) {
    return GeocodingService.forward(cityName);
  }

  // Fetch weather data by city name
  Future<WeatherData> getWeatherByCity(String cityName) async {
    try {
      final location = await getCoordinatesFromCity(cityName);
      return await getWeatherByCoordinates(
        location['latitude'],
        location['longitude'],
      );
    } catch (e) {
      throw Exception('Error fetching weather for city: $e');
    }
  }

  /// Coordinates -> display name, e.g. "Blue Area Islamabad".
  ///
  /// Falls back to 'Current Location' only when no provider could name the
  /// point, so the caller still gets something renderable.
  Future<Map<String, dynamic>> getCityFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final result = await GeocodingService.reverse(latitude, longitude);
    final name = (result['name'] as String?) ?? '';

    return {
      'name': name.isEmpty ? 'Current Location' : name,
      'city': result['city'] ?? '',
      'country': result['country'] ?? '',
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Search-bar typeahead.
  Future<List<Map<String, dynamic>>> getPlaceSuggestions(String input) {
    return GeocodingService.suggestions(input);
  }

  /// Resolve a tapped suggestion. Suggestions carry their own coordinates, so
  /// this is a local parse; it returns null for anything unrecognised and the
  /// caller falls back to a name search.
  Future<Map<String, dynamic>?> getPlaceDetails(
    String placeId, {
    String name = '',
  }) async {
    return GeocodingService.resolvePlaceId(placeId, name);
  }
}
