import 'dart:math';
import 'package:flutter/material.dart';

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> forecast;
  final List<double> hourlyTemperatures;
  final List<int> hourlyWeatherCodes;
  final List<int> hourlyPrecipitation;
  final List<String> hourlyTimes; // Store hourly times from API

  final List<bool> hourlyIsDay; // is_day values per hour
  final int? aqiIndex; // AQI index

  WeatherData({
    required this.current,
    required this.forecast,
    this.hourlyTemperatures = const [],
    this.hourlyWeatherCodes = const [],
    this.hourlyPrecipitation = const [],
    this.hourlyTimes = const [],
    this.hourlyIsDay = const [],
    this.aqiIndex,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, {int? aqi}) {
    try {
      final hourlyData = json['hourly'] as Map<String, dynamic>? ?? {};
      final dailyData = json['daily'] as Map<String, dynamic>? ?? {};

      // Parse hourly lists first (needed for injection into current)
      final hourlyTimes = _parseHourlyTimes(hourlyData);

      final hourlyUvRaw = _parseHourlyDoubleList(hourlyData, 'uv_index');
      final hourlyDew = _parseHourlyDoubleList(hourlyData, 'dew_point_2m');
      final hourlyIsDay = _parseHourlyIsDay(hourlyData);
      final hourlyCloudCover =
          _parseHourlyDoubleList(hourlyData, 'cloud_cover');

      // Rule: if cloud cover >= 75%, force UV to 0 for that hour
      final hourlyUv = List<double>.generate(hourlyUvRaw.length, (i) {
        if (i < hourlyCloudCover.length && hourlyCloudCover[i] >= 75) {
          return 0.0;
        }
        return hourlyUvRaw[i];
      });

      // Find the index for the current hour
      int currentHourIdx = -1;
      final now = DateTime.now();
      for (int i = 0; i < hourlyTimes.length; i++) {
        try {
          final t = DateTime.parse(hourlyTimes[i]);
          if (t.year == now.year &&
              t.month == now.month &&
              t.day == now.day &&
              t.hour == now.hour) {
            currentHourIdx = i;
            break;
          }
        } catch (_) {}
      }

      double? currentUv;
      double? currentDew;
      bool? currentIsDay;
      if (currentHourIdx >= 0) {
        if (currentHourIdx < hourlyUv.length) {
          currentUv = hourlyUv[currentHourIdx];
        }
        if (currentHourIdx < hourlyDew.length) {
          currentDew = hourlyDew[currentHourIdx];
        }
        if (currentHourIdx < hourlyIsDay.length) {
          currentIsDay = hourlyIsDay[currentHourIdx];
        }
      }

      // Parse current weather and inject hourly-derived values
      final currentParsed = CurrentWeather.fromJson(json['current'] ?? {});
      // Rule: if current cloud cover >= 75%, force UV to 0
      final double? gatedCurrentUv =
          currentParsed.cloudCover >= 75 ? 0.0 : currentUv;
      final current = currentParsed.copyWith(
        uvIndex: gatedCurrentUv,
        dewPoint: currentDew,
        isDay: currentIsDay,
      );

      print('🌡️ [CurrentWeather] Parsed from API:');
      print('   Temperature: ${current.temperature}°C');
      print('   Wind Gust: ${current.windGust} km/h');
      print('   UV (current hour): ${current.uvIndex}');
      print('   Dew Point (current hour): ${current.dewPoint}°C');
      print('   Is Day (current hour): ${current.isDay}');

      return WeatherData(
        current: current,
        forecast: _parseDailyForecast(dailyData, hourlyData, hourlyTimes),
        hourlyTemperatures: _parseHourlyTemps(hourlyData),
        hourlyWeatherCodes: _parseHourlyWeatherCodes(hourlyData),
        hourlyPrecipitation: _parseHourlyPrecipitation(hourlyData),
        hourlyTimes: hourlyTimes,
        hourlyIsDay: hourlyIsDay,
        aqiIndex: aqi,
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

  // Parse hourly times (NEW)
  static List<String> _parseHourlyTimes(Map<String, dynamic> hourly) {
    try {
      final times = hourly['time'] as List?;
      if (times == null) {
        print('⚠️ [WeatherData] No time found in hourly data');
        return [];
      }
      final result = times.map((t) => t.toString()).toList();
      print('✅ [WeatherData] Parsed ${result.length} hourly times');
      if (result.isNotEmpty) {
        print('   First time: ${result.first}');
        print('   Last time: ${result.last}');
      }
      return result;
    } catch (e) {
      print('❌ Error parsing hourly times: $e');
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

  // Parse a generic hourly double list (e.g., uv_index, dew_point_2m)
  static List<double> _parseHourlyDoubleList(
      Map<String, dynamic> hourly, String key) {
    try {
      final list = hourly[key] as List?;
      if (list == null) return [];
      return list.map((v) => _toDouble(v)).toList();
    } catch (e) {
      print('❌ Error parsing hourly $key: $e');
      return [];
    }
  }

  // Parse hourly is_day flags (1/0)
  static List<bool> _parseHourlyIsDay(Map<String, dynamic> hourly) {
    try {
      final list = hourly['is_day'] as List?;
      if (list == null) return [];
      return list.map((v) {
        if (v is bool) return v;
        if (v is num) return v == 1;
        if (v is String) return v == '1' || v.toLowerCase() == 'true';
        return true;
      }).toList();
    } catch (e) {
      print('❌ Error parsing hourly is_day: $e');
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

  static List<DailyForecast> _parseDailyForecast(
    Map<String, dynamic> daily,
    Map<String, dynamic> hourly,
    List<String> hourlyTimes,
  ) {
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

    // Compute per-day max values from hourly data as fallback
    // (UKMO model doesn't provide precipitation_probability or wind_speed_10m_max in daily)
    final dailyDates = times.map((t) => t.toString()).toList();
    final hourlyPrecipProb =
        _parseHourlyIntList(hourly, 'precipitation_probability');
    final hourlyWindGusts = _parseHourlyDoubleList(hourly, 'wind_gusts_10m');
    final hourlyWindSpeed = _parseHourlyDoubleList(hourly, 'wind_speed_10m');

    final fallbackPrecipProb =
        _computeDailyMax<int>(hourlyPrecipProb, hourlyTimes, dailyDates);
    final fallbackWindGusts =
        _computeDailyMax<double>(hourlyWindGusts, hourlyTimes, dailyDates);
    final fallbackWindSpeed =
        _computeDailyMax<double>(hourlyWindSpeed, hourlyTimes, dailyDates);

    for (int i = 0; i < times.length; i++) {
      try {
        forecasts.add(DailyForecast.fromJson(
          daily,
          i,
          fallbackPrecipProb:
              i < fallbackPrecipProb.length ? fallbackPrecipProb[i] : null,
          fallbackWindGust:
              i < fallbackWindGusts.length ? fallbackWindGusts[i] : null,
          fallbackWindSpeed:
              i < fallbackWindSpeed.length ? fallbackWindSpeed[i] : null,
        ));
      } catch (e) {
        print('❌ Error parsing forecast at index $i: $e');
      }
    }

    print(
        '✅ [WeatherModel] Successfully parsed ${forecasts.length} forecast days');
    return forecasts;
  }

  /// Parse hourly int list (handles null values gracefully)
  static List<int?> _parseHourlyIntList(
      Map<String, dynamic> hourly, String key) {
    try {
      final list = hourly[key] as List?;
      if (list == null) return [];
      return list.map((v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is String) return int.tryParse(v);
        return null;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Compute per-day max from hourly nullable data
  static List<num?> _computeDailyMax<T extends num>(
    List<T?> hourlyValues,
    List<String> hourlyTimes,
    List<String> dailyDates,
  ) {
    final result = List<num?>.filled(dailyDates.length, null);
    for (int i = 0; i < hourlyTimes.length && i < hourlyValues.length; i++) {
      final val = hourlyValues[i];
      if (val == null) continue;
      try {
        final t = DateTime.parse(hourlyTimes[i]);
        final dateStr =
            '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
        final dayIndex = dailyDates.indexOf(dateStr);
        if (dayIndex >= 0) {
          if (result[dayIndex] == null || val > result[dayIndex]!) {
            result[dayIndex] = val;
          }
        }
      } catch (_) {}
    }
    return result;
  }
}

class CurrentWeather {
  /// Returns the "feels like" temperature using windchill (if <15°C) or heat index (if >=15°C)
  double get feelsLike {
    if (temperature < 15) {
      // Windchill formula (°C):
      // 13.12 + 0.6215*T - 11.37*V^0.16 + 0.3965*T*V^0.16
      // T = temp (°C), V = wind speed (km/h)
      final v = windSpeed > 0 ? windSpeed : 0.1; // avoid zero wind
      return 13.12 +
          0.6215 * temperature -
          11.37 * pow(v, 0.16) +
          0.3965 * temperature * pow(v, 0.16);
    } else {
      // Only apply heat index if temp >= 27°C and RH >= 40%
      final tC = temperature;
      final rh = humidity.toDouble();
      if (tC < 27 || rh < 40) {
        return tC;
      }
      final tF = tC * 9 / 5 + 32;
      final hiF = -42.379 +
          2.04901523 * tF +
          10.14333127 * rh -
          0.22475541 * tF * rh -
          0.00683783 * tF * tF -
          0.05481717 * rh * rh +
          0.00122874 * tF * tF * rh +
          0.00085282 * tF * rh * rh -
          0.00000199 * tF * tF * rh * rh;
      return (hiF - 32) * 5 / 9;
    }
  }

  final double temperature;
  final int humidity;
  final double windSpeed;
  final double windGust; // Wind gust speed
  final int windDirection; // Wind direction
  final double dewPoint; // Dew point temperature
  final int weatherCode;
  final double pressure;
  final int cloudCover;
  final bool isDay;
  final double visibility;
  final double uvIndex;
  final double rainRate;
  final String? customDescription; // For METAR conditions like "Smoke"

  CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    this.windGust = 0.0,
    this.windDirection = 0,
    this.dewPoint = 0.0,
    required this.weatherCode,
    required this.pressure,
    required this.cloudCover,
    required this.isDay,
    this.visibility = 10.0,
    this.uvIndex = 0.0,
    this.rainRate = 0.0,
    this.customDescription,
  });

  /// Return a copy of this CurrentWeather with optional overrides.
  /// Pass null (the default) to keep the existing value.
  CurrentWeather copyWith({
    double? uvIndex,
    double? dewPoint,
    bool? isDay,
  }) {
    return CurrentWeather(
      temperature: temperature,
      humidity: humidity,
      windSpeed: windSpeed,
      windGust: windGust,
      windDirection: windDirection,
      dewPoint: dewPoint ?? this.dewPoint,
      weatherCode: weatherCode,
      pressure: pressure,
      cloudCover: cloudCover,
      isDay: isDay ?? this.isDay,
      visibility: visibility,
      uvIndex: uvIndex ?? this.uvIndex,
      rainRate: rainRate,
      customDescription: customDescription,
    );
  }

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    print(
        '🌡️ [CurrentWeather.fromJson] Input JSON keys: ${json.keys.toList()}');
    print(
        '� [CurrentWeather.fromJson] is_day value: ${json['is_day']} (type: ${json['is_day']?.runtimeType})');

    final isDay = _toBool(json['is_day']);
    print('🌙 [CurrentWeather] Parsed isDay: $isDay');

    return CurrentWeather(
      temperature: _toDouble(json['temperature_2m']),
      humidity: _toInt(json['relative_humidity_2m']),
      windSpeed: _toDouble(json['wind_speed_10m']),
      windGust: _toDouble(json['wind_gusts_10m']),
      windDirection: _toInt(json['wind_direction_10m']),
      dewPoint: _toDouble(json['dew_point_2m']),
      weatherCode: _toInt(json['weather_code']),
      pressure: _toDouble(json['pressure_msl']),
      cloudCover: _toInt(json['cloud_cover']),
      isDay: isDay,
      visibility: _toDouble(json['visibility']) / 1000,
      uvIndex: _toDouble(json['uv_index']),
      rainRate: _toDouble(json['rain']),
    );
  }

  /// Convert various types to bool (handles 0/1, true/false, "true"/"false")
  static bool _toBool(dynamic value) {
    if (value == null) return true; // Default to day
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return true;
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
    // If custom description exists (e.g., from METAR), use appropriate icon
    if (customDescription != null && customDescription!.isNotEmpty) {
      final desc = customDescription!.toUpperCase();
      if (desc.contains('HAZE')) return '🌫️';
      if (desc.contains('SMOKE')) return '💨';
      if (desc.contains('DUST') || desc.contains('SAND')) return '🌪️';
      if (desc.contains('VOLCANIC')) return '🌋';
      if (desc.contains('FOG') || desc.contains('MIST')) return '🌫️';
      if (desc.contains('TORNADO') || desc.contains('FUNNEL')) return '🌪️';
      if (desc.contains('SANDSTORM') || desc.contains('DUSTSTORM')) {
        return '🌪️';
      }
    }

    switch (weatherCode) {
      case 0:
        return isDay ? '☀️' : '🌙';
      case 1:
        // Mainly clear - show sun/partial stars at night instead of just moon
        return isDay ? '🌤️' : '🌟';
      case 2:
        // Partly cloudy - show appropriate night variant
        return isDay ? '⛅' : '☁️';
      case 3:
        return isDay ? '☁️' : '☁️';
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
        return isDay ? '🌤️' : '🌟';
    }
  }
}

class DailyForecast {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final int weatherCode;
  final int precipitationProbability;
  final double precipitationSum;
  final double windSpeed;
  final double windGust;
  final int windDirection;
  final int sunrise;
  final int sunset;
  final double uvIndexMax;
  final double apparentTempMax;
  final double apparentTempMin;

  DailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
    required this.precipitationProbability,
    this.precipitationSum = 0.0,
    required this.windSpeed,
    this.windGust = 0.0,
    this.windDirection = 0,
    required this.sunrise,
    required this.sunset,
    this.uvIndexMax = 0.0,
    this.apparentTempMax = 0.0,
    this.apparentTempMin = 0.0,
  });

  factory DailyForecast.fromJson(
    Map<String, dynamic> json,
    int index, {
    num? fallbackPrecipProb,
    num? fallbackWindGust,
    num? fallbackWindSpeed,
  }) {
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

      // Use daily value if non-null, otherwise fall back to hourly-computed max
      final rawPrecipProb = json['precipitation_probability_max']?[index];
      final rawWindGust = json['wind_gusts_10m_max']?[index];
      final rawWindSpeed = json['wind_speed_10m_max']?[index];

      // Parse precipitation sum first (needed for probability estimation)
      final precipSum = _toDouble(json['precipitation_sum']?[index] ?? 0);

      // Determine precipitation probability:
      // 1. Use daily value if available
      // 2. Use hourly-computed fallback if available
      // 3. Estimate from precipitation_sum when model doesn't provide probability
      int precipProb;
      if (rawPrecipProb != null) {
        precipProb = _toInt(rawPrecipProb);
      } else if (fallbackPrecipProb != null) {
        precipProb = _toInt(fallbackPrecipProb);
      } else if (precipSum > 0) {
        // Estimate from precipitation amount when probability is unavailable
        if (precipSum < 1) {
          precipProb = 30;
        } else if (precipSum < 5) {
          precipProb = 60;
        } else if (precipSum < 15) {
          precipProb = 80;
        } else {
          precipProb = 95;
        }
      } else {
        precipProb = 0;
      }

      final result = DailyForecast(
        date: _parseDate(json['time'][index]),
        maxTemp: _toDouble(json['temperature_2m_max'][index]),
        minTemp: _toDouble(json['temperature_2m_min'][index]),
        weatherCode: _toInt(json['weather_code'][index]),
        precipitationProbability: precipProb,
        precipitationSum: precipSum,
        windSpeed: _toDouble(rawWindSpeed ?? fallbackWindSpeed ?? 0),
        windGust: _toDouble(rawWindGust ?? fallbackWindGust ?? 0),
        windDirection: _toInt(json['wind_direction_10m_dominant']?[index] ?? 0),
        sunrise: sunrise,
        sunset: sunset,
        uvIndexMax: _toDouble(json['uv_index_max']?[index] ?? 0),
        apparentTempMax:
            _toDouble(json['apparent_temperature_max']?[index] ?? 0),
        apparentTempMin:
            _toDouble(json['apparent_temperature_min']?[index] ?? 0),
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
        return 'Foggy';
      case 48:
        return 'Depositing rime fog';
      case 51:
        return 'Light drizzle';
      case 53:
        return 'Moderate drizzle';
      case 55:
        return 'Dense drizzle';
      case 56:
        return 'Light freezing drizzle';
      case 57:
        return 'Dense freezing drizzle';
      case 61:
        return 'Slight rain';
      case 63:
        return 'Moderate rain';
      case 65:
        return 'Heavy rain';
      case 66:
        return 'Light freezing rain';
      case 67:
        return 'Heavy freezing rain';
      case 71:
        return 'Slight snow fall';
      case 73:
        return 'Moderate snow fall';
      case 75:
        return 'Heavy snow fall';
      case 77:
        return 'Snow grains';
      case 80:
        return 'Slight rain showers';
      case 81:
        return 'Moderate rain showers';
      case 82:
        return 'Violent rain showers';
      case 85:
        return 'Slight snow showers';
      case 86:
        return 'Heavy snow showers';
      case 95:
        return 'Thunderstorm';
      case 96:
        return 'Thunderstorm with slight hail';
      case 99:
        return 'Thunderstorm with heavy hail';
      default:
        return 'Unknown';
    }
  }
}
