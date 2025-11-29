import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  // Fetch weather data by coordinates
  Future<WeatherData> getWeatherByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$baseUrl?latitude=$latitude&longitude=$longitude'
          '&current=temperature_2m,relative_humidity_2m,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,visibility,uv_index'
          '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,weather_code,precipitation_probability_max,wind_speed_10m_max,uv_index_max'
          '&timezone=auto&timeformat=unixtime');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      throw Exception('Error fetching weather: $e');
    }
  }

  // Get coordinates from city name
  Future<Map<String, dynamic>> getCoordinatesFromCity(String cityName) async {
    try {
      final url = Uri.parse(
          '$geocodingUrl?name=${Uri.encodeComponent(cityName)}&count=1&language=en&format=json');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] == null || data['results'].isEmpty) {
          throw Exception('City not found');
        }

        final result = data['results'][0];
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
}
