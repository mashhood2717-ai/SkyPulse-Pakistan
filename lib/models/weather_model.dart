import 'package:flutter/material.dart';

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> forecast;
  final List<double> hourlyTemperatures; // NEW: Store hourly temps
  final List<int> hourlyWeatherCodes; // NEW: Store hourly weather codes
  final List<int> hourlyPrecipitation; // NEW: Store hourly precipitation

  WeatherData({
    required this.current,
    required this.forecast,
    this.hourlyTemperatures = const [],
    this.hourlyWeatherCodes = const [],
    this.hourlyPrecipitation = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    try {
      return WeatherData(
        current: CurrentWeather.fromJson(json['current'] ?? {}),
        forecast: _parseDailyForecast(json['daily'] ?? {}),
        hourlyTemperatures: _parseHourlyTemps(json['hourly'] ?? {}),
        hourlyWeatherCodes: _parseHourlyWeatherCodes(json['hourly'] ?? {}),
        hourlyPrecipitation: _parseHourlyPrecipitation(json['hourly'] ?? {}),
      );
    } catch (e) {
      print('Error parsing weather data: $e');
      rethrow;
    }
  }

  // Parse hourly temperatures
  static List<double> _parseHourlyTemps(Map<String, dynamic> hourly) {
    try {
      print('📊 [WeatherData] Hourly keys: ${hourly.keys.toList()}');
      final temps = hourly['temperature_2m'] as List?;
      if (temps == null) {
        print('⚠️ [WeatherData] No temperature_2m found in hourly data');
        return [];
      }
      final result = temps.map((t) => _toDouble(t)).toList();
      print('✅ [WeatherData] Parsed ${result.length} hourly temperatures');
      return result;
    } catch (e) {
      print('❌ Error parsing hourly temps: $e');
      return [];
    }
  }

  // Parse hourly weather codes
  static List<int> _parseHourlyWeatherCodes(Map<String, dynamic> hourly) {
    try {
      final codes = hourly['weather_code'] as List?;
      if (codes == null) {
        print('⚠️ [WeatherData] No weather_code found in hourly data');
        return [];
      }
      final result = codes.map((c) => _toInt(c)).toList();
      print('✅ [WeatherData] Parsed ${result.length} hourly weather codes');
      return result;
    } catch (e) {
      print('❌ Error parsing hourly weather codes: $e');
      return [];
    }
  }

  // Parse hourly precipitation
  static List<int> _parseHourlyPrecipitation(Map<String, dynamic> hourly) {
    try {
      final precips = hourly['precipitation_probability'] as List?;
      if (precips == null) {
        print(
            '⚠️ [WeatherData] No precipitation_probability found in hourly data');
        return [];
      }
      final result = precips.map((p) => _toInt(p)).toList();
      print(
          '✅ [WeatherData] Parsed ${result.length} hourly precipitation values');
      return result;
    } catch (e) {
      print('❌ Error parsing hourly precipitation: $e');
      return [];
    }
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

  static List<DailyForecast> _parseDailyForecast(Map<String, dynamic> daily) {
    final List<DailyForecast> forecasts = [];
    final times = daily['time'] as List?;

    print('📊 [WeatherModel] Daily data keys: ${daily.keys.toList()}');
    print('📊 [WeatherModel] Forecast days count: ${times?.length ?? 0}');

    // Debug: Print sunrise/sunset values
    if (daily['sunrise'] != null) {
      print('🌅 [WeatherModel] First sunrise (raw): ${daily['sunrise']?[0]}');
    }
    if (daily['sunset'] != null) {
      print('🌇 [WeatherModel] First sunset (raw): ${daily['sunset']?[0]}');
    }

    if (times == null || times.isEmpty) {
      print('⚠️ [WeatherModel] No time data found in daily forecast!');
      return forecasts;
    }

    for (int i = 0; i < times.length; i++) {
      try {
        forecasts.add(DailyForecast.fromJson(daily, i));
      } catch (e) {
        print('❌ Error parsing forecast at index $i: $e');
      }
    }

    print(
        '✅ [WeatherModel] Successfully parsed ${forecasts.length} forecast days');
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
  final String? customDescription; // NEW: For METAR conditions like "Smoke"

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
    this.customDescription, // NEW: Custom description for METAR
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
    // Use custom description if provided (e.g., from METAR "Smoke")
    if (customDescription != null && customDescription!.isNotEmpty) {
      return customDescription!;
    }

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
    switch (weatherCode) {
      case 0:
        return isDay ? '☀️' : '🌙';
      case 1:
        return isDay ? '🌤️' : '🌙';
      case 2:
        return isDay ? '⛅' : '🌙';
      case 3:
        return isDay ? '☁️' : '☁️'; // Clouds visible at night too
      case 45:
      case 48:
        return '🌫️'; // Fog visible at night
      case 51:
      case 53:
      case 55:
        return '🌦️'; // Drizzle visible at night
      case 61:
      case 63:
      case 65:
        return '🌧️'; // Rain visible at night
      case 71:
      case 73:
      case 75:
        return '❄️'; // Snow visible at night
      case 77:
        return '🌨️'; // Snow grains visible at night
      case 80:
      case 81:
      case 82:
        return '🌧️'; // Rain showers visible at night
      case 85:
      case 86:
        return '🌨️'; // Snow showers visible at night
      case 95:
        return '⛈️'; // Thunderstorm visible at night
      case 96:
      case 99:
        return '⛈️'; // Thunderstorm with hail visible at night
      default:
        return isDay ? '🌤️' : '🌙';
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
    try {
      // Parse sunrise - handle both string and int timestamps
      int sunrise = 0;
      if (json['sunrise'] != null) {
        final sunriseVal = json['sunrise'][index];
        if (sunriseVal is String) {
          // If it's a datetime string like "2025-11-29T06:30"
          sunrise = DateTime.parse(sunriseVal).millisecondsSinceEpoch ~/ 1000;
        } else if (sunriseVal is int) {
          sunrise = sunriseVal;
        }
      }

      // Parse sunset - handle both string and int timestamps
      int sunset = 0;
      if (json['sunset'] != null) {
        final sunsetVal = json['sunset'][index];
        if (sunsetVal is String) {
          sunset = DateTime.parse(sunsetVal).millisecondsSinceEpoch ~/ 1000;
        } else if (sunsetVal is int) {
          sunset = sunsetVal;
        }
      }

      final result = DailyForecast(
        date: _parseDate(json['time'][index]),
        maxTemp: _toDouble(json['temperature_2m_max'][index]),
        minTemp: _toDouble(json['temperature_2m_min'][index]),
        weatherCode: _toInt(json['weather_code'][index]),
        precipitationProbability:
            _toInt(json['precipitation_probability_max']?[index] ?? 0),
        windSpeed: _toDouble(json['wind_speed_10m_max']?[index] ?? 0),
        sunrise: sunrise,
        sunset: sunset,
        uvIndexMax: _toDouble(json['uv_index_max']?[index] ?? 0),
      );

      // Debug output
      if (index == 0) {
        print(
            '🌅 [DailyForecast] Sunrise timestamp: $sunrise (${DateTime.fromMillisecondsSinceEpoch(sunrise * 1000)})');
        print(
            '🌇 [DailyForecast] Sunset timestamp: $sunset (${DateTime.fromMillisecondsSinceEpoch(sunset * 1000)})');
      }

      return result;
    } catch (e) {
      print('❌ Error in DailyForecast.fromJson at index $index: $e');
      print('   Available keys: ${json.keys.toList()}');
      rethrow;
    }
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
