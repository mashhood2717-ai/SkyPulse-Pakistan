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
      // Descriptors (can precede weather)
      if (part == 'VC') condition = 'VC'; // Vicinity
      if (part == 'MI') condition = 'MI'; // Shallow
      if (part == 'PR') condition = 'PR'; // Partial
      if (part == 'BC') condition = 'BC'; // Patches
      if (part == 'DR') condition = 'DR'; // Low Drifting
      if (part == 'BL') condition = 'BL'; // Blowing
      if (part == 'FZ') condition = 'FZ'; // Freezing

      // Precipitation
      if (part == 'RA' || part == '-RA' || part == '+RA')
        condition = 'RA'; // Rain
      if (part == 'DZ' || part == '-DZ' || part == '+DZ')
        condition = 'DZ'; // Drizzle
      if (part == 'SN' || part == '-SN' || part == '+SN')
        condition = 'SN'; // Snow
      if (part == 'SG') condition = 'SG'; // Snow Grains
      if (part == 'IC') condition = 'IC'; // Ice Crystals
      if (part == 'PL') condition = 'PL'; // Ice Pellets/Sleet
      if (part == 'GR') condition = 'GR'; // Hail
      if (part == 'GS') condition = 'GS'; // Small Hail and/or Snow Pellets
      if (part == 'UP') condition = 'UP'; // Unknown Precipitation

      // Shower/Storm
      if (part == 'SHRA') condition = 'SHRA'; // Rain Showers
      if (part == 'SHSN') condition = 'SHSN'; // Snow Showers
      if (part == 'SHGS') condition = 'SHGS'; // Hail Showers
      if (part == 'SHPL') condition = 'SHPL'; // Ice Pellet Showers
      if (part == 'SHIC') condition = 'SHIC'; // Ice Crystal Showers
      if (part == 'TS' || part == 'THUNDERSTORM')
        condition = 'TS'; // Thunderstorm
      if (part == 'TSRA') condition = 'TSRA'; // Thunderstorm with Rain
      if (part == 'TSGR') condition = 'TSGR'; // Thunderstorm with Hail
      if (part == 'TSSN') condition = 'TSSN'; // Thunderstorm with Snow
      if (part == 'TSPL') condition = 'TSPL'; // Thunderstorm with Ice Pellets
      if (part == 'RASN') condition = 'RASN'; // Rain and Snow

      // Obscuration (Visibility Reduction)
      if (part == 'BR' || part == 'MIST') condition = 'BR'; // Mist
      if (part == 'FG' || part == 'FOG') condition = 'FG'; // Fog
      if (part == 'FU' || part == 'SMOKE') condition = 'FU'; // Smoke
      if (part == 'VA') condition = 'VA'; // Volcanic Ash
      if (part == 'DU') condition = 'DU'; // Widespread Dust
      if (part == 'SA') condition = 'SA'; // Sand
      if (part == 'HZ' || part == 'HAZE') condition = 'HZ'; // Haze
      if (part == 'PY') condition = 'PY'; // Spray

      // Other phenomena
      if (part == 'PO') condition = 'PO'; // Well-Developed Dust/Sand Whirls
      if (part == 'SQ') condition = 'SQ'; // Squalls
      if (part == 'FC') condition = 'FC'; // Funnel Cloud / Tornado
      if (part == '+FC') condition = 'FC'; // Tornado (with intensity)
      if (part == 'SS') condition = 'SS'; // Sandstorm
      if (part == 'DS') condition = 'DS'; // Duststorm
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
      customDescription: _getCustomDescription(), // NEW: Pass METAR condition
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
    if (condition.contains('FC'))
      return 95; // Funnel cloud/Tornado - use thunderstorm

    // Severe precipitation with hail
    if (condition.contains('GR')) return 96; // Hail - thunderstorm with hail
    if (condition.contains('TSGR')) return 96;
    if (condition.contains('SHGS')) return 96;

    // Snow and ice precipitation
    if (condition.contains('SN')) return 71;
    if (condition.contains('SNOW')) return 71;
    if (condition.contains('SG')) return 77; // Snow grains
    if (condition.contains('IC')) return 71; // Ice crystals - treat as snow
    if (condition.contains('PL'))
      return 71; // Ice pellets/Sleet - treat as snow
    if (condition.contains('GS')) return 71; // Small hail - treat as snow
    if (condition.contains('TSSN')) return 71; // Thunderstorm with snow
    if (condition.contains('SHSN')) return 71; // Snow showers
    if (condition.contains('SHIC')) return 71; // Ice crystal showers

    // Rain and showers
    if (condition.contains('TSRA')) return 95; // Thunderstorm with rain
    if (condition.contains('SHRA')) return 80; // Rain showers
    if (condition.contains('SHPL'))
      return 61; // Ice pellet showers - treat as rain
    if (condition.contains('RASN')) return 61; // Rain and snow
    if (condition.contains('RA')) return 61; // Rain
    if (condition.contains('RAIN')) return 61;
    if (condition.contains('FZ')) return 61; // Freezing (freezing rain)

    // Drizzle and light precipitation
    if (condition.contains('DZ')) return 51; // Drizzle
    if (condition.contains('DRIZZLE')) return 51;
    if (condition.contains('UP'))
      return 51; // Unknown precipitation - treat as drizzle

    // Fog (severe visibility reduction)
    if (condition.contains('FG')) return 45;
    if (condition.contains('FOG')) return 45;

    // Mist (significant visibility reduction - similar to fog)
    if (condition.contains('BR')) return 45;
    if (condition.contains('MIST')) return 45;

    // Smoke and volcanic effects (visibility reduction)
    if (condition.contains('FU')) return 45; // Smoke - use fog icon
    if (condition.contains('SMOKE')) return 45;
    if (condition.contains('VA')) return 45; // Volcanic ash - use fog icon

    // Haze (lighter visibility reduction)
    if (condition.contains('HZ'))
      return 1; // Haze - mostly clear but with haze layer
    if (condition.contains('HAZE')) return 1;

    // Dust, Sand, and Storms
    if (condition.contains('DU')) return 3; // Dust - use overcast
    if (condition.contains('SA')) return 3; // Sand - use overcast
    if (condition.contains('PY')) return 3; // Spray - use overcast
    if (condition.contains('PO')) return 3; // Dust/Sand Whirls - use overcast
    if (condition.contains('SS')) return 3; // Sandstorm - use overcast
    if (condition.contains('DS')) return 3; // Duststorm - use overcast
    if (condition.contains('SQ')) return 95; // Squall - use thunderstorm icon

    // Descriptors (low priority - modifiers to other conditions)
    if (condition.contains('VC')) return 2; // Vicinity - partial cloudy
    if (condition.contains('MI')) return 1; // Shallow - mostly clear
    if (condition.contains('PR')) return 1; // Partial - mostly clear
    if (condition.contains('BC')) return 1; // Patches - mostly clear
    if (condition.contains('DR')) return 1; // Low Drifting - mostly clear
    if (condition.contains('BL')) return 2; // Blowing - partly cloudy

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

  /// Get custom description text from METAR condition (e.g., "Smoke")
  String? _getCustomDescription() {
    final condition = weatherCondition.toUpperCase().trim();

    if (condition.isEmpty || condition == 'CLEAR') return null;

    // Map METAR codes to readable descriptions
    // Descriptors
    if (condition.contains('VC')) return 'Vicinity';
    if (condition.contains('MI')) return 'Shallow';
    if (condition.contains('PR')) return 'Partial';
    if (condition.contains('BC')) return 'Patches';
    if (condition.contains('DR')) return 'Low Drifting';
    if (condition.contains('BL')) return 'Blowing';
    if (condition.contains('FZ')) return 'Freezing';

    // Thunderstorms and severe weather
    if (condition.contains('FC')) return 'Funnel Cloud';
    if (condition.contains('+FC')) return 'Tornado';
    if (condition.contains('TSGR')) return 'Thunderstorm with Hail';
    if (condition.contains('TSSN')) return 'Thunderstorm with Snow';
    if (condition.contains('TSPL')) return 'Thunderstorm with Ice Pellets';
    if (condition.contains('TSRA')) return 'Thunderstorm with Rain';
    if (condition.contains('TS')) return 'Thunderstorm';
    if (condition.contains('SQ')) return 'Squalls';

    // Hail and ice
    if (condition.contains('SHGS')) return 'Hail Showers';
    if (condition.contains('GR')) return 'Hail';
    if (condition.contains('GS')) return 'Small Hail and/or Snow Pellets';
    if (condition.contains('PL')) return 'Ice Pellets';
    if (condition.contains('SHPL')) return 'Ice Pellet Showers';
    if (condition.contains('IC')) return 'Ice Crystals';
    if (condition.contains('SHIC')) return 'Ice Crystal Showers';

    // Snow
    if (condition.contains('SHSN')) return 'Snow Showers';
    if (condition.contains('SN')) return 'Snow';
    if (condition.contains('SG')) return 'Snow Grains';

    // Rain
    if (condition.contains('SHRA')) return 'Rain Showers';
    if (condition.contains('RASN')) return 'Rain and Snow';
    if (condition.contains('RA')) return 'Rain';

    // Drizzle
    if (condition.contains('DZ')) return 'Drizzle';

    // Obscuration phenomena
    if (condition.contains('FU')) return 'Smoke';
    if (condition.contains('VA')) return 'Volcanic Ash';
    if (condition.contains('DU')) return 'Widespread Dust';
    if (condition.contains('SA')) return 'Sand';
    if (condition.contains('PY')) return 'Spray';
    if (condition.contains('FG')) return 'Fog';
    if (condition.contains('BR')) return 'Mist';
    if (condition.contains('HZ')) return 'Haze';

    // Other phenomena
    if (condition.contains('PO')) return 'Dust/Sand Whirls';
    if (condition.contains('SS')) return 'Sandstorm';
    if (condition.contains('DS')) return 'Duststorm';

    // Unknown
    if (condition.contains('UP')) return 'Unknown Precipitation';

    // Return the condition as-is if no mapping found
    return condition.isNotEmpty ? condition : null;
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
