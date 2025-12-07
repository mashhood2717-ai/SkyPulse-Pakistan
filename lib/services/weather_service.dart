import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String aqiUrl =
      'https://air-quality-api.open-meteo.com/v1/air-quality';

  // Google Geocoding API
  static const String googleGeocodingUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // Google API key (same as Google Maps)
  static const String googleApiKey = 'AIzaSyDjZ0ZlSS19MP0uecz0XeyxriUCl-aNvMo';

  // Fetch weather data by coordinates
  Future<WeatherData> getWeatherByCoordinates(
      double latitude, double longitude) async {
    try {
      final url = Uri.parse('$baseUrl?latitude=$latitude&longitude=$longitude'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max'
          '&hourly=temperature_2m,relative_humidity_2m,dew_point_2m,precipitation,visibility,weather_code,pressure_msl,cloud_cover_low,wind_speed_10m,wind_gusts_10m,wind_direction_10m,is_day'
          '&current=temperature_2m,relative_humidity_2m,dew_point_2m,is_day,precipitation,weather_code,pressure_msl,wind_direction_10m,cloud_cover,wind_gusts_10m,wind_speed_10m,visibility'
          '&timezone=auto'
          '&forecast_days=15');

      print('🌐 [WeatherService] Fetching: $url');
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ [WeatherService] Request timeout after 15 seconds');
          throw TimeoutException('Weather API request timeout');
        },
      );

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
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [AQIService] Request timeout after 10 seconds');
          throw TimeoutException('AQI request timeout');
        },
      );

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

  // Get coordinates from city name using Google Geocoding API
  Future<Map<String, dynamic>> getCoordinatesFromCity(String cityName) async {
    try {
      final url = Uri.parse(
          '$googleGeocodingUrl?address=${Uri.encodeComponent(cityName)}&key=$googleApiKey');

      print('🔍 Searching for city: $cityName');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [Google Geocoding] Request timeout after 10 seconds');
          throw TimeoutException('Geocoding request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK' ||
            data['results'] == null ||
            data['results'].isEmpty) {
          print(
              '⚠️ [Google Geocoding] Status: ${data['status']}, Error: ${data['error_message'] ?? 'No results'}');
          throw Exception('City not found');
        }

        final result = data['results'][0];
        final location = result['geometry']['location'];

        // Extract city name and country from address components
        // Priority: locality > sublocality > administrative_area_level_2 > search term
        String? locality;
        String? sublocality;
        String? adminArea2;
        String country = '';

        for (final component in result['address_components'] ?? []) {
          final types = List<String>.from(component['types'] ?? []);
          if (types.contains('locality')) {
            locality = component['long_name'];
          }
          if (types.contains('sublocality') ||
              types.contains('sublocality_level_1')) {
            sublocality = component['long_name'];
          }
          if (types.contains('administrative_area_level_2')) {
            adminArea2 = component['long_name'];
          }
          if (types.contains('country')) {
            country = component['short_name'] ?? '';
          }
        }

        // Use the most specific name, fall back to original search term
        // This ensures "Mailsi" stays as "Mailsi", not "Punjab"
        String name = locality ?? sublocality ?? adminArea2 ?? cityName;

        // If the original search term looks like a specific place name (not a province),
        // prefer keeping it over a generic admin area
        if (name != cityName &&
            locality == null &&
            !cityName.toLowerCase().contains('province') &&
            !cityName.toLowerCase().contains('state')) {
          // The search term was specific but we only found admin areas
          // Keep the original search term as it's likely more specific
          name = cityName;
        }

        print(
            '✅ City found: $name, $country (locality=$locality, sublocality=$sublocality, admin2=$adminArea2)');
        return {
          'latitude': location['lat'],
          'longitude': location['lng'],
          'name': name,
          'country': country,
        };
      } else {
        throw Exception('Failed to find city: ${response.statusCode}');
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

  // Reverse geocoding: Get city name from coordinates using Google Geocoding API
  // Returns street-level addresses like "I-8/3" instead of just "Islamabad"
  Future<Map<String, dynamic>> getCityFromCoordinates(
      double latitude, double longitude) async {
    try {
      print('🔍 Reverse geocoding: $latitude, $longitude');

      // No result_type filter - get the most detailed address available
      final url = Uri.parse(
          '$googleGeocodingUrl?latlng=$latitude,$longitude&key=$googleApiKey');

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [Google Geocoding] Reverse geocoding timeout');
          throw TimeoutException('Reverse geocoding timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK' ||
            data['results'] == null ||
            data['results'].isEmpty) {
          print('⚠️ [Google Geocoding] Reverse: Status: ${data['status']}');
          return {
            'name': 'Current Location',
            'country': '',
            'latitude': latitude,
            'longitude': longitude,
          };
        }

        final result = data['results'][0];

        // Extract the most specific address available
        String? street;
        String? route;
        String? neighborhood;
        String? sublocality;
        String? locality;
        String? adminArea2;
        String? adminArea1;
        String country = '';

        for (final component in result['address_components'] ?? []) {
          final types = List<String>.from(component['types'] ?? []);
          if (types.contains('street_address')) {
            street = component['long_name'];
          }
          if (types.contains('route')) {
            route = component['long_name'];
          }
          if (types.contains('neighborhood')) {
            neighborhood = component['long_name'];
          }
          if (types.contains('sublocality') ||
              types.contains('sublocality_level_1')) {
            sublocality = component['long_name'];
          }
          if (types.contains('locality')) {
            locality = component['long_name'];
          }
          if (types.contains('administrative_area_level_2')) {
            adminArea2 = component['long_name'];
          }
          if (types.contains('administrative_area_level_1')) {
            adminArea1 = component['long_name'];
          }
          if (types.contains('country')) {
            country = component['short_name'] ?? '';
          }
        }

        // Build a combined address: neighborhood/sublocality + locality (e.g., "I-8/3 Islamabad")
        // Priority: neighborhood (most specific) > sublocality > route, combined with city
        String address;
        final cityName = locality ?? adminArea2 ?? adminArea1;
        final detailedArea = neighborhood ?? sublocality ?? route;

        if (detailedArea != null &&
            cityName != null &&
            detailedArea != cityName) {
          // Combine detailed area with city: "I-8/3 Islamabad"
          address = '$detailedArea $cityName';
        } else {
          // Fallback to most specific available
          address = detailedArea ?? cityName ?? 'Current Location';
        }

        // Clean up common suffixes for cleaner display
        address = address
            .replaceAll(' Capital Territory', '')
            .replaceAll(' Metropolitan Area', '')
            .replaceAll(' District', '')
            .trim();

        print(
            '✅ Location found: $address, $country (street=$street, route=$route, neighborhood=$neighborhood, sublocality=$sublocality, locality=$locality, admin2=$adminArea2, admin1=$adminArea1)');
        return {
          'name': address,
          'country': country,
          'latitude': latitude,
          'longitude': longitude,
        };
      } else {
        print('⚠️ [Google Geocoding] Failed: ${response.statusCode}');
        return {
          'name': 'Current Location',
          'country': '',
          'latitude': latitude,
          'longitude': longitude,
        };
      }
    } catch (e) {
      print('❌ Error reverse geocoding: $e');
      return {
        'name': 'Current Location',
        'country': '',
        'latitude': latitude,
        'longitude': longitude,
      };
    }
  }

  // Google Places Autocomplete for search suggestions
  static const String googlePlacesAutocompleteUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';

  Future<List<Map<String, dynamic>>> getPlaceSuggestions(String input) async {
    if (input.isEmpty) return [];

    try {
      final url = Uri.parse(
          '$googlePlacesAutocompleteUrl?input=${Uri.encodeComponent(input)}&types=(cities)&key=$googleApiKey');

      print('🔍 [Autocomplete] Searching: $input');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏱️ [Autocomplete] Request timeout');
          throw TimeoutException('Autocomplete timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK') {
          print('⚠️ [Autocomplete] Status: ${data['status']}');
          return [];
        }

        final predictions = data['predictions'] as List<dynamic>;
        print('✅ [Autocomplete] Found ${predictions.length} suggestions');

        return predictions.map((p) {
          return {
            'description': p['description'] ?? '',
            'placeId': p['place_id'] ?? '',
            'mainText': p['structured_formatting']?['main_text'] ?? '',
            'secondaryText':
                p['structured_formatting']?['secondary_text'] ?? '',
          };
        }).toList();
      } else {
        print('⚠️ [Autocomplete] Failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [Autocomplete] Error: $e');
      return [];
    }
  }

  // Get place details (coordinates) from place_id
  static const String googlePlaceDetailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
          '$googlePlaceDetailsUrl?place_id=$placeId&fields=geometry,name,address_components&key=$googleApiKey');

      final response = await http.get(url).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Place details timeout'),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK' || data['result'] == null) {
          return null;
        }

        final result = data['result'];
        final location = result['geometry']['location'];

        // Extract city name and country
        String name = result['name'] ?? '';
        String country = '';

        for (final component in result['address_components'] ?? []) {
          final types = List<String>.from(component['types'] ?? []);
          if (types.contains('locality')) {
            name = component['long_name'];
          }
          if (types.contains('country')) {
            country = component['short_name'] ?? '';
          }
        }

        return {
          'latitude': location['lat'],
          'longitude': location['lng'],
          'name': name,
          'country': country,
        };
      }
      return null;
    } catch (e) {
      print('❌ [PlaceDetails] Error: $e');
      return null;
    }
  }
}
