import 'dart:math';

import 'weather_model.dart';

class CompanyWeatherStation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> raw;
  final double? distanceKm;
  final int? aqiIndex;

  CompanyWeatherStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.raw,
    this.distanceKm,
    this.aqiIndex,
  });

  CompanyWeatherStation copyWithDistance(double distanceKm) {
    return CompanyWeatherStation(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      raw: raw,
      distanceKm: distanceKm,
      aqiIndex: aqiIndex,
    );
  }

  factory CompanyWeatherStation.fromJson(Map<String, dynamic> json) {
    final raw = _withWeatherWalayNowcast(json);

    final latitude = _readDouble(raw, const [
      'latitude',
      'lat',
      'stationLatitude',
      'station_latitude',
      'location.latitude',
      'location.lat',
      'coordinates.latitude',
      'coordinates.lat',
      'geo.latitude',
      'geo.lat',
    ]);

    final longitude = _readDouble(raw, const [
      'longitude',
      'long',
      'lon',
      'lng',
      'stationLongitude',
      'station_longitude',
      'location.longitude',
      'location.lon',
      'location.lng',
      'coordinates.longitude',
      'coordinates.lon',
      'coordinates.lng',
      'geo.longitude',
      'geo.lon',
      'geo.lng',
    ]);

    if (latitude == null || longitude == null) {
      throw const FormatException('Station is missing latitude or longitude');
    }

    final id = _readString(raw, const [
          'id',
          'stationID',
          'stationId',
          'station_id',
          'code',
          'stationCode',
          'station_code',
        ]) ??
        '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

    final name = _readString(raw, const [
          'name',
          'poi',
          'stationName',
          'station_name',
          'title',
          'siteName',
          'site_name',
          'city',
          'location.name',
        ]) ??
        'Weather Station';

    return CompanyWeatherStation(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      raw: raw,
      aqiIndex: _readInt(raw, const [
        'aqi',
        'aqiPak',
        'aqiUSA',
        'aqiParams.aqiPak',
        'aqiParams.aqiUSA',
      ]),
    );
  }

  CurrentWeather toCurrentWeather(CurrentWeather fallback) {
    final temperature = _readDouble(raw, const [
          'temperature',
          'temp',
          'tempC',
          'temp_c',
          'temperatureC',
          'temperature_c',
          'airTemperature',
          'air_temperature',
          'current.temperature',
          'current.temp',
          'weather.temperature',
        ]) ??
        fallback.temperature;

    final humidity = _readInt(raw, const [
          'humidity',
          'hum',
          'relativeHumidity',
          'relative_humidity',
          'rh',
          'current.humidity',
          'weather.humidity',
        ]) ??
        fallback.humidity;

    final windSpeed = _readDouble(raw, const [
          'windSpeed',
          'wind_speed',
          'windSpeedKmh',
          'wind_speed_kmh',
          'wind_kph',
          'windspeed',
          'current.windSpeed',
          'weather.windSpeed',
        ]) ??
        fallback.windSpeed;

    final windGust = _readDouble(raw, const [
          'windGust',
          'wind_gust',
          'windGustKmh',
          'wind_gust_kmh',
          'gust',
          'current.windGust',
          'weather.windGust',
        ]) ??
        fallback.windGust;

    final windDirection = _readInt(raw, const [
          'windDirection',
          'wind_direction',
          'windDir',
          'wind_dir',
          'current.windDirection',
          'weather.windDirection',
        ]) ??
        fallback.windDirection;

    final dewPoint = _readDouble(raw, const [
          'dewPoint',
          'dew_point',
          'dewpoint',
          'current.dewPoint',
          'weather.dewPoint',
        ]) ??
        fallback.dewPoint;

    final pressure = _readDouble(raw, const [
          'pressure',
          'pressureMsl',
          'pressure_msl',
          'barometer',
          'current.pressure',
          'weather.pressure',
        ]) ??
        fallback.pressure;

    final cloudCover = _readInt(raw, const [
          'cloudCover',
          'cloud_cover',
          'clouds',
          'current.cloudCover',
          'weather.cloudCover',
        ]) ??
        fallback.cloudCover;

    final visibility = _normalizeVisibilityKm(
      _readDouble(raw, const [
        'visibility',
        'visibilityKm',
        'visibility_km',
        'vis',
        'current.visibility',
        'weather.visibility',
      ]),
      fallback.visibility,
    );

    final uvIndex = _readDouble(raw, const [
          'uvIndex',
          'uv_index',
          'uv',
          'current.uvIndex',
          'weather.uvIndex',
        ]) ??
        fallback.uvIndex;

    final rainRate = _readDouble(raw, const [
          'rainRate',
          'rain_rate',
          'rainIntensity',
          'rain_intensity',
          'prec',
          'precipitationRate',
          'precipitation_rate',
          'current.rainRate',
          'weather.rainRate',
        ]) ??
        fallback.rainRate;

    final weatherCode = _readInt(raw, const [
          'weatherCode',
          'weather_code',
          'wmoCode',
          'wmo_code',
          'conditionCode',
          'condition_code',
          'current.weatherCode',
          'weather.weatherCode',
        ]) ??
        _inferWeatherCode(raw) ??
        fallback.weatherCode;

    return CurrentWeather(
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      windGust: windGust,
      windDirection: windDirection,
      dewPoint: dewPoint,
      weatherCode: weatherCode,
      pressure: pressure,
      cloudCover: cloudCover,
      isDay: fallback.isDay,
      visibility: visibility,
      uvIndex: uvIndex,
      rainRate: rainRate,
      customDescription: _readString(raw, const [
        'condition',
        'weather',
        'description',
        'weatherConditionEnglish',
        'weatherConditionCategory',
        'weatherDescription',
        'weather_description',
        'current.condition',
        'weather.description',
      ]),
    );
  }

  static double distanceBetweenKm(
    double fromLatitude,
    double fromLongitude,
    double toLatitude,
    double toLongitude,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(toLatitude - fromLatitude);
    final dLon = _degreesToRadians(toLongitude - fromLongitude);
    final lat1 = _degreesToRadians(fromLatitude);
    final lat2 = _degreesToRadians(toLatitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) => degrees * pi / 180;

  static double _normalizeVisibilityKm(double? value, double fallback) {
    if (value == null || value <= 0) return fallback;
    return value > 100 ? value / 1000 : value;
  }

  static int? _inferWeatherCode(Map<String, dynamic> json) {
    final condition = [
      _readString(json, const ['weatherConditionEnglish']),
      _readString(json, const ['weatherConditionCategory']),
      _readString(json, const ['condition']),
      _readString(json, const ['weather']),
      _readString(json, const ['description']),
      _readString(json, const ['weatherDescription']),
      _readString(json, const ['weather_description']),
      _readString(json, const ['current.condition']),
      _readString(json, const ['weather.description']),
    ].whereType<String>().join(' ').toLowerCase();

    if (condition.contains('thunder') || condition.contains('storm')) return 95;
    if (condition.contains('snow')) return 71;
    if (condition.contains('shower')) return 80;
    if (condition.contains('rain')) return 61;
    if (condition.contains('drizzle')) return 51;
    if (condition.contains('fog') ||
        condition.contains('mist') ||
        condition.contains('haze') ||
        condition.contains('smoke')) {
      return 45;
    }
    if (condition.contains('overcast')) return 3;
    if (condition.contains('partly') || condition.contains('scattered')) {
      return 2;
    }
    if (condition.contains('cloud')) return 2;
    if (condition.contains('clear') ||
        condition.contains('sunny') ||
        condition.contains('calm') ||
        condition.contains('hot')) {
      return 0;
    }
    return null;
  }

  static String? _readString(Map<String, dynamic> json, List<String> paths) {
    for (final path in paths) {
      final value = _readPath(json, path);
      if (value == null) continue;
      if (value is Map || value is List) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, List<String> paths) {
    for (final path in paths) {
      final value = _readPath(json, path);
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed.round();
      }
    }
    return null;
  }

  static double? _readDouble(Map<String, dynamic> json, List<String> paths) {
    for (final path in paths) {
      final value = _readPath(json, path);
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static dynamic _readPath(Map<String, dynamic> json, String path) {
    dynamic current = json;
    for (final part in path.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
  }

  static Map<String, dynamic> _withWeatherWalayNowcast(
    Map<String, dynamic> json,
  ) {
    final raw = Map<String, dynamic>.from(json);
    final weatherStats = raw['weatherStats'];
    if (weatherStats is List && weatherStats.isNotEmpty) {
      final latest = weatherStats.first;
      if (latest is Map) {
        final nowcast = latest['nowcast'];
        if (nowcast is Map) {
          raw.addAll(Map<String, dynamic>.from(nowcast));
        }
      }
    }
    return raw;
  }
}
