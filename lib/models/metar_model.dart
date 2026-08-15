import 'dart:math' as math;
import '../models/weather_model.dart';
import '../utils/log.dart';

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
    logDebug('📋 Parsing METAR JSON from Aviation Weather API');

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

    logDebug('   🌡️ Temp: $temp°C, Dewpoint: $dewp°C');
    logDebug('   💨 Wind: ${wdir ?? 0}° at ${wspd ?? 0} kt');
    logDebug('   👁️ Visibility: ${visibKm?.toStringAsFixed(2)} km');
    logDebug('   ☁️ Cloud Cover: $cover');
    logDebug('   🌦️ Weather Condition (wxString): $wx');
    logDebug('   📊 Pressure: $altim hPa');

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

  /// Convert METAR data to CurrentWeather model
  /// Now accepts sunrise/sunset times from API to determine day/night correctly
  CurrentWeather toCurrentWeather({int? sunrise, int? sunset}) {
    final weatherCode = _getWeatherCode();
    final isDay = _isDayAtLocation(sunrise, sunset);

    logDebug('🔄 Converting METAR to CurrentWeather:');
    logDebug('   Temperature: ${temperature ?? 20.0}°C');
    logDebug('   Dewpoint: ${dewpoint ?? 15.0}°C');
    logDebug(
        '   Wind Speed: ${(windSpeed ?? 0) * 1.852} km/h (from ${windSpeed ?? 0} kt)');
    logDebug('   Wind Direction: ${windDirection ?? 0}°');
    logDebug('   Weather Code: $weatherCode');
    logDebug('   Visibility: ${visibility ?? 10.0} km');
    logDebug('   Pressure: ${pressure ?? 1013} hPa');
    logDebug(
        '   Is Day: $isDay (sunrise: ${sunrise != null ? DateTime.fromMillisecondsSinceEpoch(sunrise * 1000) : "N/A"}, sunset: ${sunset != null ? DateTime.fromMillisecondsSinceEpoch(sunset * 1000) : "N/A"})');

    return CurrentWeather(
      temperature: temperature ?? 20.0,
      humidity: _calculateHumidity(temperature, dewpoint),
      windSpeed: (windSpeed ?? 0) * 1.852, // Convert knots to km/h
      windGust: 0.0, // METAR doesn't provide wind gust in typical parsing
      dewPoint: (dewpoint ?? 15.0), // NEW: Use dewpoint from METAR
      weatherCode: weatherCode,
      pressure: pressure ?? 1013.0,
      cloudCover: _getCloudCover(),
      isDay: isDay,
      visibility: visibility ?? 10.0, // Already in km
      uvIndex: 0, // METAR doesn't provide UV index - will be replaced by API
      rainRate: 0.0,
      customDescription: _getCustomDescription(), // NEW: Pass METAR condition
    );
  }

  /// Calculate relative humidity from temperature and dewpoint
  static int _calculateHumidity(double? temp, double? dewpoint) {
    if (temp == null || dewpoint == null) return 50;

    const a = 17.27;
    const b = 237.7;

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
    if (condition.contains('FC')) {
      return 95; // Funnel cloud/Tornado - use thunderstorm
    }

    // Severe precipitation with hail
    if (condition.contains('GR')) return 96; // Hail - thunderstorm with hail
    if (condition.contains('TSGR')) return 96;
    if (condition.contains('SHGS')) return 96;

    // Snow and ice precipitation
    if (condition.contains('SN')) return 71;
    if (condition.contains('SNOW')) return 71;
    if (condition.contains('SG')) return 77; // Snow grains
    if (condition.contains('IC')) return 71; // Ice crystals - treat as snow
    if (condition.contains('PL')) {
      return 71; // Ice pellets/Sleet - treat as snow
    }
    if (condition.contains('GS')) return 71; // Small hail - treat as snow
    if (condition.contains('TSSN')) return 71; // Thunderstorm with snow
    if (condition.contains('SHSN')) return 71; // Snow showers
    if (condition.contains('SHIC')) return 71; // Ice crystal showers

    // Rain and showers
    if (condition.contains('TSRA')) return 95; // Thunderstorm with rain
    if (condition.contains('SHRA')) return 80; // Rain showers
    if (condition.contains('SHPL')) {
      return 61; // Ice pellet showers - treat as rain
    }
    if (condition.contains('RASN')) return 61; // Rain and snow
    if (condition.contains('RA')) return 61; // Rain
    if (condition.contains('RAIN')) return 61;
    if (condition.contains('FZ')) return 61; // Freezing (freezing rain)

    // Drizzle and light precipitation
    if (condition.contains('DZ')) return 51; // Drizzle
    if (condition.contains('DRIZZLE')) return 51;
    if (condition.contains('UP')) {
      return 51; // Unknown precipitation - treat as drizzle
    }

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
    if (condition.contains('HZ')) {
      return 1; // Haze - mostly clear but with haze layer
    }
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
          cloudStr.contains('NSC')) {
        return 0;
      }
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
        cloudStr.contains('NSC')) {
      return 0;
    }
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
}
