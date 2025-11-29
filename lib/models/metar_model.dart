import 'dart:math' as math;
import '../models/weather_model.dart';

class MetarData {
  final String icaoCode;
  final String rawMetar;
  final DateTime observationTime;
  final double? temperature;
  final double? dewpoint;
  final int? windDirection;
  final double? windSpeed;
  final double? visibility; // in kilometers
  final String? clouds;
  final double? pressure;
  final String weatherCondition;

  MetarData({
    required this.icaoCode,
    required this.rawMetar,
    required this.observationTime,
    this.temperature,
    this.dewpoint,
    this.windDirection,
    this.windSpeed,
    this.visibility,
    this.clouds,
    this.pressure,
    this.weatherCondition = 'Clear',
  });

  /// Parse from Aviation Weather Center JSON format
  factory MetarData.fromJson(Map<String, dynamic> json) {
    print('📋 Parsing METAR JSON from Aviation Weather API');

    final icao = json['icaoId'] ?? json['icao'] ?? '';
    final raw = json['rawOb'] ?? json['rawText'] ?? '';

    // Temperature and dewpoint (already in Celsius)
    final temp = _toDouble(json['temp']);
    final dewp = _toDouble(json['dewp']);

    // Wind direction and speed (already in knots)
    final wdir = _toInt(json['wdir']);
    final wspd = _toDouble(json['wspd']);

    // Visibility (in statute miles, need to convert to km)
    final visibMiles = _toDouble(json['visib']);
    final visibKm = visibMiles != null ? visibMiles * 1.60934 : null;

    // Cloud cover from 'cover' field
    final cover = json['cover'] as String?;

    // Pressure (in mb/hPa)
    final altim = _toDouble(json['altim']);

    // Weather condition from 'wxString' field (this is the key!)
    final wxString = json['wxString'] as String?;
    final wx = wxString != null && wxString.isNotEmpty ? wxString : 'Clear';

    print('   🌡️ Temp: $temp°C, Dewpoint: $dewp°C');
    print('   💨 Wind: ${wdir ?? 0}° at ${wspd ?? 0} kt');
    print('   👁️ Visibility: ${visibKm?.toStringAsFixed(2)} km');
    print('   ☁️ Cloud Cover: $cover');
    print('   🌦️ Weather Condition (wxString): $wx');
    print('   📊 Pressure: $altim hPa');

    return MetarData(
      icaoCode: icao,
      rawMetar: raw,
      observationTime:
          _parseObservationTime(json['reportTime'] ?? json['obsTime']),
      temperature: temp,
      dewpoint: dewp,
      windDirection: wdir,
      windSpeed: wspd,
      visibility: visibKm,
      clouds: cover,
      pressure: altim,
      weatherCondition: wx,
    );
  }

  /// Parse from CheckWX JSON format
  factory MetarData.fromCheckWxJson(Map<String, dynamic> json) {
    return MetarData(
      icaoCode: json['icao'] ?? '',
      rawMetar: json['raw_text'] ?? '',
      observationTime: _parseObservationTime(json['observed']),
      temperature: _toDouble(json['temperature']?['celsius']),
      dewpoint: _toDouble(json['dewpoint']?['celsius']),
      windDirection: _toInt(json['wind']?['degrees']),
      windSpeed: _toDouble(json['wind']?['speed_kts']),
      visibility: _toDouble(json['visibility']?['meters_float']) != null
          ? _toDouble(json['visibility']?['meters_float'])! / 1000
          : null,
      clouds: json['clouds']?.toString(),
      pressure: _toDouble(json['barometer']?['mb']),
      weatherCondition: json['conditions']?[0]?['code'] ?? 'Clear',
    );
  }

  /// Parse from raw METAR string
  factory MetarData.fromRawMetar(String rawMetar, String icaoCode) {
    final parts = rawMetar.split(' ');

    double? temp;
    double? dewp;
    int? windDir;
    double? windSpd;
    double? pressure;
    double? visibility;
    String clouds = 'CLR';
    String condition = 'Clear';

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];

      // Temperature and Dewpoint (e.g., 15/08 or M05/M08)
      if (part.contains('/') && part.length <= 6) {
        final temps = part.split('/');
        if (temps.length == 2) {
          temp = _parseTemp(temps[0]);
          dewp = _parseTemp(temps[1]);
        }
      }

      // Wind (e.g., 27015KT or VRB05KT)
      if (part.endsWith('KT') && part.length >= 5) {
        final windStr = part.replaceAll('KT', '');
        if (!windStr.startsWith('VRB')) {
          if (windStr.length >= 5) {
            windDir = int.tryParse(windStr.substring(0, 3));
            windSpd = double.tryParse(windStr.substring(3));
          }
        } else {
          // Variable wind
          windDir = 0;
          windSpd = double.tryParse(windStr.substring(3));
        }
      }

      // Altimeter/Pressure (e.g., Q1013 or A2992)
      if (part.startsWith('Q') && part.length == 5) {
        pressure = double.tryParse(part.substring(1));
      } else if (part.startsWith('A') && part.length == 5) {
        final inHg = double.tryParse(part.substring(1));
        if (inHg != null) {
          pressure = (inHg / 100) * 33.8639;
        }
      }

      // Visibility (e.g., 9999 or 4000)
      if (part.length == 4 && int.tryParse(part) != null) {
        final visMeters = int.tryParse(part);
        if (visMeters != null) {
          visibility = visMeters / 1000.0; // Convert to km
        }
      }

      // Cloud coverage (e.g., FEW020, SCT040, BKN100, OVC200, NSC)
      if (part == 'NSC' || part == 'SKC' || part == 'CLR') {
        clouds = 'CLR';
      } else if (part.startsWith('FEW')) {
        clouds = 'FEW';
      } else if (part.startsWith('SCT')) {
        clouds = 'SCT';
      } else if (part.startsWith('BKN')) {
        clouds = 'BKN';
      } else if (part.startsWith('OVC')) {
        clouds = 'OVC';
      }

      // Weather phenomena (wxString equivalents)
      if (part == 'HZ') condition = 'HZ'; // Haze
      if (part == 'BR') condition = 'BR'; // Mist
      if (part == 'FG') condition = 'FG'; // Fog
      if (part == 'RA') condition = 'RA'; // Rain
      if (part == '-RA') condition = 'RA'; // Light Rain
      if (part == '+RA') condition = 'RA'; // Heavy Rain
      if (part == 'SN') condition = 'SN'; // Snow
      if (part == 'TS') condition = 'TS'; // Thunderstorm
      if (part == 'TSRA') condition = 'TSRA'; // Thunderstorm with rain
      if (part == 'DZ') condition = 'DZ'; // Drizzle
    }

    return MetarData(
      icaoCode: icaoCode,
      rawMetar: rawMetar,
      observationTime: DateTime.now(),
      temperature: temp,
      dewpoint: dewp,
      windDirection: windDir,
      windSpeed: windSpd,
      visibility: visibility,
      clouds: clouds,
      pressure: pressure,
      weatherCondition: condition,
    );
  }

  /// Convert METAR data to CurrentWeather model
  /// Now accepts sunrise/sunset times from API to determine day/night correctly
  CurrentWeather toCurrentWeather({int? sunrise, int? sunset}) {
    final weatherCode = _getWeatherCode();
    final isDay = _isDayAtLocation(sunrise, sunset);

    print('🔄 Converting METAR to CurrentWeather:');
    print('   Temperature: ${temperature ?? 20.0}°C');
    print(
        '   Wind Speed: ${(windSpeed ?? 0) * 1.852} km/h (from ${windSpeed ?? 0} kt)');
    print('   Wind Direction: ${windDirection ?? 0}°');
    print('   Weather Code: $weatherCode');
    print('   Visibility: ${visibility ?? 10.0} km');
    print('   Pressure: ${pressure ?? 1013} hPa');
    print(
        '   Is Day: $isDay (sunrise: ${sunrise != null ? DateTime.fromMillisecondsSinceEpoch(sunrise * 1000) : "N/A"}, sunset: ${sunset != null ? DateTime.fromMillisecondsSinceEpoch(sunset * 1000) : "N/A"})');

    return CurrentWeather(
      temperature: temperature ?? 20.0,
      humidity: _calculateHumidity(temperature, dewpoint),
      windSpeed: (windSpeed ?? 0) * 1.852, // Convert knots to km/h
      weatherCode: weatherCode,
      pressure: pressure ?? 1013.0,
      cloudCover: _getCloudCover(),
      isDay: isDay,
      visibility: visibility ?? 10.0, // Already in km
      uvIndex: 0, // METAR doesn't provide UV index - will be replaced by API
    );
  }

  /// Calculate relative humidity from temperature and dewpoint
  static int _calculateHumidity(double? temp, double? dewpoint) {
    if (temp == null || dewpoint == null) return 50;

    final a = 17.27;
    final b = 237.7;

    final rh = 100 *
        (math.exp((a * dewpoint) / (b + dewpoint)) /
            math.exp((a * temp) / (b + temp)));

    return rh.round().clamp(0, 100);
  }

  /// Get weather code based on METAR wxString condition
  int _getWeatherCode() {
    final condition = weatherCondition.toUpperCase();

    // Priority order: Most severe weather first

    // Thunderstorms (highest priority)
    if (condition.contains('TS')) return 95;
    if (condition.contains('THUNDER')) return 95;

    // Snow
    if (condition.contains('SN')) return 71;
    if (condition.contains('SNOW')) return 71;

    // Rain
    if (condition.contains('RA')) return 61;
    if (condition.contains('RAIN')) return 61;
    if (condition.contains('SHRA')) return 61;

    // Drizzle
    if (condition.contains('DZ')) return 51;
    if (condition.contains('DRIZZLE')) return 51;

    // Fog only
    if (condition.contains('FG')) return 45;
    if (condition.contains('FOG')) return 45;

    // Haze and Mist - treat as mostly clear (code 1)
    if (condition.contains('BR')) return 1;
    if (condition.contains('MIST')) return 1;
    if (condition.contains('HZ')) return 1;
    if (condition.contains('HAZE')) return 1;

    // If no significant weather, check cloud cover
    if (clouds != null) {
      final cloudStr = clouds!.toUpperCase();
      if (cloudStr.contains('OVC')) return 3; // Overcast
      if (cloudStr.contains('BKN')) return 3; // Broken
      if (cloudStr.contains('SCT')) return 2; // Scattered
      if (cloudStr.contains('FEW')) return 1; // Few
      if (cloudStr.contains('CLR') ||
          cloudStr.contains('SKC') ||
          cloudStr.contains('NSC')) return 0;
    }

    // Default to clear if no conditions reported
    return 0;
  }

  /// Get cloud cover percentage from METAR clouds
  int _getCloudCover() {
    if (clouds == null) return 0;

    final cloudStr = clouds!.toUpperCase();

    if (cloudStr.contains('SKC') ||
        cloudStr.contains('CLR') ||
        cloudStr.contains('NSC')) return 0;
    if (cloudStr.contains('FEW')) return 20;
    if (cloudStr.contains('SCT')) return 50;
    if (cloudStr.contains('BKN')) return 75;
    if (cloudStr.contains('OVC')) return 100;

    return 0;
  }

  /// Determine if it's day or night at the actual location using sunrise/sunset times
  bool _isDayAtLocation(int? sunrise, int? sunset) {
    if (sunrise == null || sunset == null) {
      // Fallback to simple time check if sunrise/sunset not available
      final hour = DateTime.now().hour;
      return hour >= 6 && hour < 20;
    }

    // Get current Unix timestamp
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check if current time is between sunrise and sunset
    final isDayTime = now >= sunrise && now < sunset;

    return isDayTime;
  }

  static DateTime _parseObservationTime(dynamic timeStr) {
    if (timeStr == null) return DateTime.now();

    try {
      if (timeStr is String) {
        return DateTime.parse(timeStr);
      }
      if (timeStr is int) {
        return DateTime.fromMillisecondsSinceEpoch(timeStr * 1000);
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseTemp(String tempStr) {
    // Handle negative temps (e.g., M05 = -5)
    if (tempStr.startsWith('M')) {
      final temp = double.tryParse(tempStr.substring(1));
      return temp != null ? -temp : null;
    }
    return double.tryParse(tempStr);
  }
}
