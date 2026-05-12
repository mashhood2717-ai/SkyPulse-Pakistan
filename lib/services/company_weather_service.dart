import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/company_weather_station.dart';

class CompanyWeatherService {
  static const String stationsUrl = String.fromEnvironment(
    'COMPANY_WEATHER_STATIONS_URL',
    defaultValue: 'https://hubservice.weatherwalay.com/gis/get-stats',
  );
  static const String apiKey =
      String.fromEnvironment('COMPANY_WEATHER_API_KEY');
  static const String apiKeyHeader = String.fromEnvironment(
    'COMPANY_WEATHER_API_KEY_HEADER',
    defaultValue: 'Authorization',
  );
  static const String apiKeyPrefix = String.fromEnvironment(
    'COMPANY_WEATHER_API_KEY_PREFIX',
    defaultValue: 'Bearer ',
  );

  static const double maxStationRadiusKm = 5.0;

  bool get isConfigured => stationsUrl.trim().isNotEmpty;

  Future<CompanyWeatherStation?> getNearestStation(
    double latitude,
    double longitude, {
    double maxRadiusKm = maxStationRadiusKm,
  }) async {
    if (!isConfigured) {
      print('[CompanyWeather] API disabled: COMPANY_WEATHER_STATIONS_URL empty');
      return null;
    }

    try {
      final stations = await _fetchStations(latitude, longitude);
      if (stations.isEmpty) {
        print('[CompanyWeather] No valid stations returned by company API');
        return null;
      }

      CompanyWeatherStation? nearest;
      for (final station in stations) {
        final distanceKm = CompanyWeatherStation.distanceBetweenKm(
          latitude,
          longitude,
          station.latitude,
          station.longitude,
        );
        final candidate = station.copyWithDistance(distanceKm);
        if (nearest == null ||
            distanceKm < (nearest.distanceKm ?? double.infinity)) {
          nearest = candidate;
        }
      }

      if (nearest == null || (nearest.distanceKm ?? double.infinity) > maxRadiusKm) {
        print(
          '[CompanyWeather] No station within ${maxRadiusKm.toStringAsFixed(1)} km',
        );
        return null;
      }

      print(
        '[CompanyWeather] Nearest station: ${nearest.name} '
        '(${nearest.distanceKm!.toStringAsFixed(2)} km)',
      );
      return nearest;
    } catch (e) {
      print('[CompanyWeather] Failed to load nearest station: $e');
      return null;
    }
  }

  Future<List<CompanyWeatherStation>> _fetchStations(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      stationsUrl
          .replaceAll('{latitude}', latitude.toString())
          .replaceAll('{longitude}', longitude.toString())
          .replaceAll('{lat}', latitude.toString())
          .replaceAll('{lon}', longitude.toString())
          .replaceAll('{lng}', longitude.toString()),
    );

    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (apiKey.trim().isNotEmpty) {
      headers[apiKeyHeader] = '$apiKeyPrefix$apiKey';
    }

    print('[CompanyWeather] Fetching stations: $url');
    final response = await http.get(url, headers: headers).timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('Company weather API timeout'),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Company weather API HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    final stationItems = _extractStationItems(decoded);

    final stations = <CompanyWeatherStation>[];
    for (final item in stationItems) {
      if (item is! Map) continue;
      final stationMap = Map<String, dynamic>.from(item);
      final status = stationMap['status']?.toString().trim().toLowerCase();
      if (status != null && status.isNotEmpty && status != 'active') {
        continue;
      }
      try {
        stations.add(
          CompanyWeatherStation.fromJson(stationMap),
        );
      } catch (e) {
        print('[CompanyWeather] Skipping invalid station: $e');
      }
    }

    print('[CompanyWeather] Parsed ${stations.length} stations');
    return stations;
  }

  List<dynamic> _extractStationItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map) return const [];

    final map = Map<String, dynamic>.from(decoded);
    for (final key in const [
      'stations',
      'weatherStations',
      'weather_stations',
      'record',
      'data',
      'results',
      'items',
    ]) {
      final value = map[key];
      if (value is List) return value;
      if (value is Map) {
        for (final nestedKey in const [
          'stations',
          'weatherStations',
          'weather_stations',
          'items',
          'results',
        ]) {
          final nestedValue = value[nestedKey];
          if (nestedValue is List) return nestedValue;
        }
      }
    }

    if (map.values.every((value) => value is Map)) {
      return map.values.toList();
    }

    return const [];
  }
}
