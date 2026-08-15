import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/company_weather_station.dart';
import '../utils/log.dart';

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

  static const double maxStationRadiusKm = 15.0;

  /// A nowcast older than this is not "live". A station that stops reporting
  /// used to keep winning over METAR and Open-Meteo purely because it was
  /// nearby, and its stale reading was shown under a green LIVE badge.
  static const Duration maxObservationAge = Duration(minutes: 30);

  bool get isConfigured => stationsUrl.trim().isNotEmpty;

  Future<CompanyWeatherStation?> getNearestStation(
    double latitude,
    double longitude, {
    double maxRadiusKm = maxStationRadiusKm,
  }) async {
    if (!isConfigured) {
      logDebug(
          '[CompanyWeather] API disabled: COMPANY_WEATHER_STATIONS_URL empty');
      return null;
    }

    try {
      final stations = await _fetchStations(latitude, longitude);
      if (stations.isEmpty) {
        logDebug('[CompanyWeather] No valid stations returned by company API');
        return null;
      }

      CompanyWeatherStation? nearest;
      var staleSkipped = 0;
      for (final station in stations) {
        // Freshness is checked before distance: the closest station is no use
        // if its last reading is hours old.
        if (!station.isFresh(maxObservationAge)) {
          staleSkipped++;
          logDebug(
            '[CompanyWeather] Skipping stale station ${station.name} '
            '(${station.age?.inMinutes} min old)',
          );
          continue;
        }

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

      if (staleSkipped > 0) {
        logDebug('[CompanyWeather] $staleSkipped station(s) skipped as stale');
      }

      if (nearest == null ||
          (nearest.distanceKm ?? double.infinity) > maxRadiusKm) {
        logDebug(
          '[CompanyWeather] No station within ${maxRadiusKm.toStringAsFixed(1)} km',
        );
        return null;
      }

      logDebug(
        '[CompanyWeather] Nearest station: ${nearest.name} '
        '(${nearest.distanceKm!.toStringAsFixed(2)} km)',
      );
      return nearest;
    } catch (e) {
      logDebug('[CompanyWeather] Failed to load nearest station: $e');
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

    logDebug('[CompanyWeather] Fetching stations: $url');
    final response = await http.get(url, headers: headers).timeout(
          const Duration(seconds: 8),
          onTimeout: () =>
              throw TimeoutException('Company weather API timeout'),
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
      if (!_isActiveStation(stationMap)) {
        final name = stationMap['name'] ??
            stationMap['stationName'] ??
            stationMap['poi'] ??
            'unknown station';
        logDebug('[CompanyWeather] Skipping inactive station: $name');
        continue;
      }
      try {
        stations.add(
          CompanyWeatherStation.fromJson(stationMap),
        );
      } catch (e) {
        logDebug('[CompanyWeather] Skipping invalid station: $e');
      }
    }

    logDebug('[CompanyWeather] Parsed ${stations.length} stations');
    return stations;
  }

  bool _isActiveStation(Map<String, dynamic> stationMap) {
    final activeFlag = _readBool(stationMap, const [
      'active',
      'isActive',
      'is_active',
      'enabled',
      'isEnabled',
      'is_enabled',
      'online',
      'isOnline',
      'is_online',
      'stationActive',
      'station_active',
      'activeStatus',
      'active_status',
      'current.active',
      'weather.active',
      'nowcast.active',
    ]);
    if (activeFlag == false) return false;

    final latestStats = _latestWeatherStats(stationMap);
    final latestActiveFlag = latestStats == null
        ? null
        : _readBool(latestStats, const [
            'active',
            'isActive',
            'is_active',
            'enabled',
            'isEnabled',
            'is_enabled',
            'online',
            'isOnline',
            'is_online',
            'activeStatus',
            'active_status',
            'nowcast.active',
          ]);
    if (latestActiveFlag == false) return false;

    final statuses = <String>[
      ..._readStatusStrings(stationMap),
      if (latestStats != null) ..._readStatusStrings(latestStats),
    ];

    if (statuses.any(_isInactiveStatus)) return false;
    if (statuses.any(_isActiveStatus)) return true;
    if (activeFlag == true || latestActiveFlag == true) return true;

    return true;
  }

  Map<String, dynamic>? _latestWeatherStats(Map<String, dynamic> stationMap) {
    final weatherStats = stationMap['weatherStats'];
    if (weatherStats is List && weatherStats.isNotEmpty) {
      final latest = weatherStats.first;
      if (latest is Map) return Map<String, dynamic>.from(latest);
    }
    return null;
  }

  List<String> _readStatusStrings(Map<String, dynamic> map) {
    return const [
      'status',
      'state',
      'stationStatus',
      'station_status',
      'activeStatus',
      'active_status',
      'siteStatus',
      'site_status',
      'deviceStatus',
      'device_status',
      'onlineStatus',
      'online_status',
      'health',
      'current.status',
      'weather.status',
      'nowcast.status',
    ]
        .map((path) => _readPath(map, path))
        .where((value) => value != null)
        .map((value) => value.toString().trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  bool _isInactiveStatus(String status) {
    return status == 'inactive' ||
        status == 'offline' ||
        status == 'disabled' ||
        status == 'disable' ||
        status == 'down' ||
        status == 'dead' ||
        status == 'stale' ||
        status == 'disconnected' ||
        status == 'not active' ||
        status == 'not_active' ||
        status.contains('inactive') ||
        status.contains('offline') ||
        status.contains('disabled') ||
        status.contains('disconnected');
  }

  bool _isActiveStatus(String status) {
    return status == 'active' ||
        status == 'online' ||
        status == 'enabled' ||
        status == 'live' ||
        status == 'ok' ||
        status == 'running' ||
        status == 'connected';
  }

  bool? _readBool(Map<String, dynamic> json, List<String> paths) {
    for (final path in paths) {
      final value = _readPath(json, path);
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized.isEmpty) continue;
        if (const {'true', '1', 'yes', 'y', 'active', 'online', 'enabled'}
            .contains(normalized)) {
          return true;
        }
        if (const {'false', '0', 'no', 'n', 'inactive', 'offline', 'disabled'}
            .contains(normalized)) {
          return false;
        }
      }
    }
    return null;
  }

  dynamic _readPath(Map<String, dynamic> json, String path) {
    dynamic current = json;
    for (final part in path.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
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
