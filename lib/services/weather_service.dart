import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geocoding;
import '../models/weather_model.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String aqiUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  // Fetch weather data by coordinates
  Future<WeatherData> getWeatherByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$baseUrl?latitude=$latitude&longitude=$longitude'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max'
          '&hourly=temperature_2m,relative_humidity_2m,dew_point_2m,precipitation,visibility,weather_code,pressure_msl,cloud_cover_low,wind_speed_10m,wind_gusts_10m,wind_direction_10m,is_day'
          '&current=temperature_2m,relative_humidity_2m,dew_point_2m,is_day,precipitation,weather_code,pressure_msl,wind_direction_10m,cloud_cover,wind_gusts_10m,wind_speed_10m'
          '&timezone=auto'
          '&forecast_days=15');

      print('🌐 [WeatherService] Fetching: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('✅ [WeatherService] Response received');
        print('📊 [WeatherService] Top-level keys: ${data.keys.toList()}');
        if (data['daily'] != null) {
          print(
              '📊 [WeatherService] Daily keys: ${data['daily'].keys.toList()}');
          print(
              '📊 [WeatherService] Daily times count: ${data['daily']['time']?.length ?? 0}');
        }

        return WeatherData.fromJson(data);
      } else {
        throw Exception('Failed to load weather data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching weather: $e');
      throw Exception('Error fetching weather: $e');
    }
  }

  // Fetch AQI data by coordinates
  Future<Map<String, dynamic>> getAQIByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$aqiUrl?latitude=$latitude&longitude=$longitude'
          '&current=us_aqi,pm10,pm2_5,nitrogen_dioxide,ozone,sulphur_dioxide'
          '&forecast_days=7');

      print('🌍 [AQIService] Fetching: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [AQIService] Response received');
        print('📊 [AQIService] Response: $data');
        print('📊 [AQIService] Current: ${data['current']}');
        print('📊 [AQIService] Current AQI: ${data['current']?['us_aqi']}');
        return data;
      } else {
        print('⚠️ [AQIService] Failed to fetch AQI: ${response.statusCode}');
        print('⚠️ [AQIService] Response body: ${response.body}');
        return {
          'current': {'us_aqi': null}
        };
      }
    } catch (e) {
      print('❌ Error fetching AQI: $e');
      return {
        'current': {'us_aqi': null}
      };
    }
  }

  // Get coordinates from city name
  Future<Map<String, dynamic>> getCoordinatesFromCity(String cityName) async {
    try {
      final url = Uri.parse(
          '$geocodingUrl?name=${Uri.encodeComponent(cityName)}&count=1&language=en&format=json');

      print('🔍 Searching for city: $cityName');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] == null || data['results'].isEmpty) {
          throw Exception('City not found');
        }

        final result = data['results'][0];
        print('✅ City found: ${result['name']}');
        return {
          'latitude': result['latitude'],
          'longitude': result['longitude'],
          'name': result['name'],
          'country': result['country_code'] ?? result['country'] ?? '',
        };
      } else {
        throw Exception('Failed to find city');
      }
    } catch (e) {
      print('❌ Error finding city: $e');
      throw Exception('Error finding city: $e');
    }
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

  // Reverse geocoding: Get city name from coordinates using geocoding package
  Future<Map<String, dynamic>> getCityFromCoordinates(
      double latitude, double longitude) async {
    try {
      print('🔍 Reverse geocoding: $latitude, $longitude');

      // Use the geocoding package for reverse geocoding
      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];
        final cityName = placemark.locality ??
            placemark.administrativeArea ??
            'Current Location';
        final countryCode = placemark.isoCountryCode ?? '';

        print('✅ Location found: $cityName, $countryCode');
        return {
          'name': cityName,
          'country': countryCode,
          'latitude': latitude,
          'longitude': longitude,
        };
      } else {
        print('⚠️ No placemarks found');
        return {
          'name': 'Current Location',
          'country': '',
        };
      }
    } catch (e) {
      print('❌ Error reverse geocoding: $e');
      return {
        'name': 'Current Location',
        'country': '',
      };
    }
  }
}
