import 'package:flutter/material.dart';

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> forecast;

  WeatherData({
    required this.current,
    required this.forecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    try {
      return WeatherData(
        current: CurrentWeather.fromJson(json['current'] ?? {}),
        forecast: _parseDailyForecast(json['daily'] ?? {}),
      );
    } catch (e) {
      print('Error parsing weather data: $e');
      rethrow;
    }
  }

  static List<DailyForecast> _parseDailyForecast(Map<String, dynamic> daily) {
    final List<DailyForecast> forecasts = [];
    final times = daily['time'] as List?;

    if (times == null || times.isEmpty) {
      return forecasts;
    }

    for (int i = 0; i < times.length; i++) {
      try {
        forecasts.add(DailyForecast.fromJson(daily, i));
      } catch (e) {
        print('Error parsing forecast at index $i: $e');
      }
    }

    return forecasts;
  }
}

class CurrentWeather {
  final double temperature;
  final int humidity;
  final double windSpeed;
  final int windDirection; // NEW: Added wind direction
  final int weatherCode;
  final double pressure;
  final int cloudCover;
  final bool isDay;
  final double visibility;
  final double uvIndex;

  CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    this.windDirection = 0, // Default to 0 (North)
    required this.weatherCode,
    required this.pressure,
    required this.cloudCover,
    required this.isDay,
    this.visibility = 10.0,
    this.uvIndex = 0.0,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: _toDouble(json['temperature_2m']),
      humidity: _toInt(json['relative_humidity_2m']),
      windSpeed: _toDouble(json['wind_speed_10m']),
      windDirection:
          _toInt(json['wind_direction_10m']), // NEW: Parse wind direction
      weatherCode: _toInt(json['weather_code']),
      pressure: _toDouble(json['pressure_msl']),
      cloudCover: _toInt(json['cloud_cover']),
      isDay: json['is_day'] == 1,
      visibility: _toDouble(json['visibility']) / 1000,
      uvIndex: _toDouble(json['uv_index']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String get uvIndexCategory {
    if (uvIndex <= 2) return 'Low';
    if (uvIndex <= 5) return 'Moderate';
    if (uvIndex <= 7) return 'High';
    if (uvIndex <= 10) return 'Very High';
    return 'Extreme';
  }

  Color get uvIndexColor {
    if (uvIndex <= 2) return Colors.green;
    if (uvIndex <= 5) return Colors.yellow;
    if (uvIndex <= 7) return Colors.orange;
    if (uvIndex <= 10) return Colors.red;
    return Colors.purple;
  }

  String get weatherDescription {
    switch (weatherCode) {
      case 0:
        return 'Clear sky';
      case 1:
        return 'Mainly clear';
      case 2:
        return 'Partly cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 77:
        return 'Snow grains';
      case 80:
      case 81:
      case 82:
        return 'Rain showers';
      case 85:
      case 86:
        return 'Snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with hail';
      default:
        return 'Unknown';
    }
  }

  String get weatherIcon {
    if (!isDay) {
      return '🌙';
    }
    switch (weatherCode) {
      case 0:
        return '☀️';
      case 1:
        return '🌤️';
      case 2:
        return '⛅';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
        return '🌦️';
      case 61:
      case 63:
      case 65:
        return '🌧️';
      case 71:
      case 73:
      case 75:
        return '❄️';
      case 77:
        return '🌨️';
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 85:
      case 86:
        return '🌨️';
      case 95:
        return '⛈️';
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌤️';
    }
  }
}

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final int precipitationProbability;
  final double windSpeed;
  final int sunrise;
  final int sunset;
  final double uvIndexMax;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.windSpeed,
    required this.sunrise,
    required this.sunset,
    this.uvIndexMax = 0.0,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json, int index) {
    return DailyForecast(
      date: _parseDate(json['time'][index]),
      maxTemp: _toDouble(json['temperature_2m_max'][index]),
      minTemp: _toDouble(json['temperature_2m_min'][index]),
      weatherCode: _toInt(json['weather_code'][index]),
      precipitationProbability:
          _toInt(json['precipitation_probability_max'][index]),
      windSpeed: _toDouble(json['wind_speed_10m_max'][index]),
      sunrise: _toInt(json['sunrise'][index]),
      sunset: _toInt(json['sunset'][index]),
      uvIndexMax: _toDouble(json['uv_index_max'][index]),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    return DateTime.now();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String get weatherIcon {
    switch (weatherCode) {
      case 0:
        return '☀️';
      case 1:
        return '🌤️';
      case 2:
        return '⛅';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
        return '🌦️';
      case 61:
      case 63:
      case 65:
        return '🌧️';
      case 71:
      case 73:
      case 75:
        return '❄️';
      case 77:
        return '🌨️';
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 85:
      case 86:
        return '🌨️';
      case 95:
        return '⛈️';
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌤️';
    }
  }

  String get dayName {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month) return 'Today';
    if (date.day == now.day + 1 && date.month == now.month) return 'Tomorrow';

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
