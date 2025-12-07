import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/metar_model.dart';

class MetarService {
  // Aviation Weather Center (no API key needed)
  static const String awcBaseUrl = 'https://aviationweather.gov/api/data/metar';

  // Major airport ICAO codes database (expandable)
  static const Map<String, List<String>> cityAirports = {
    // Pakistan
    'Islamabad': ['OPIS'],
    'Rawalpindi': ['OPIS'],
    'Karachi': ['OPKC'],
    'Lahore': ['OPLA'],
    'Peshawar': ['OPPS'],
    'Quetta': ['OPQT'],
    'Multan': ['OPMT'],
    'Faisalabad': ['OPFA'],
    'Sialkot': ['OPST'],
    'Gwadar': ['OPGD'],

    // Major International Cities (examples - expandable)
    'Dubai': ['OMDB'],
    'London': ['EGLL', 'EGKK', 'EGGW'], // Heathrow, Gatwick, Luton
    'New York': ['KJFK', 'KEWR', 'KLGA'], // JFK, Newark, LaGuardia
    'Los Angeles': ['KLAX'],
    'Tokyo': ['RJTT', 'RJAA'], // Haneda, Narita
    'Paris': ['LFPG', 'LFPO'], // Charles de Gaulle, Orly
    'Frankfurt': ['EDDF'],
    'Singapore': ['WSSS'],
    'Hong Kong': ['VHHH'],
    'Mumbai': ['VABB'],
    'Delhi': ['VIDP'],
    'Bangkok': ['VTBS'],
    'Istanbul': ['LTFM'],
    'Toronto': ['CYYZ'],
    'Sydney': ['YSSY'],
    'Melbourne': ['YMML'],
    'Beijing': ['ZBAA'],
    'Shanghai': ['ZSPD'],
    'Seoul': ['RKSI'],
    'Amsterdam': ['EHAM'],
    'Madrid': ['LEMD'],
    'Barcelona': ['LEBL'],
    'Rome': ['LIRF'],
    'Milan': ['LIMC'],
    'Zurich': ['LSZH'],
    'Vienna': ['LOWW'],
    'Moscow': ['UUEE'],
    'Cairo': ['HECA'],
    'Johannesburg': ['FAOR'],
    'Sao Paulo': ['SBGR'],
    'Mexico City': ['MMMX'],
  };

  /// Try to fetch METAR data for any city by searching nearby airports (optimized)
  /// PRIORITY: Uses coordinates first (more accurate), then falls back to city name lookup
  Future<MetarData?> getMetarDataForCity(
      String cityName, double latitude, double longitude) async {
    print(
        '🔍 Attempting to find METAR data for $cityName at ($latitude, $longitude)');

    // 1. FIRST: Search for nearby airports using coordinates (most reliable)
    print('   📍 Searching for nearby airports by coordinates...');
    final nearbyMetar = await _searchNearbyAirports(latitude, longitude);
    if (nearbyMetar != null) {
      print('   ✅ Found METAR from nearby airport using coordinates!');
      return nearbyMetar;
    }

    // 2. FALLBACK: Check if we have a known airport for this city name
    final knownIcao = _getKnownIcaoCode(cityName);
    if (knownIcao != null) {
      print(
          '   🔄 Fallback: trying known airport $knownIcao for city name "$cityName"');
      final metar = await _fetchMetarByIcao(knownIcao).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (metar != null) {
        return metar;
      }
    }

    print('   ⏭️ No METAR available, using weather API only');
    return null;
  }

  /// Get METAR data for a specific ICAO code with timeout
  Future<MetarData?> _fetchMetarByIcao(String icaoCode) async {
    try {
      final url = Uri.parse('$awcBaseUrl?ids=$icaoCode&format=json');

      // Add 2-second timeout to prevent slow responses from blocking
      final response = await http.get(url).timeout(const Duration(seconds: 2),
          onTimeout: () {
        throw TimeoutException('METAR request timed out');
      });

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        if (data is List && data.isNotEmpty) {
          print('✅ METAR fetched for $icaoCode');
          return MetarData.fromJson(data[0]);
        } else if (data is Map) {
          print('✅ METAR fetched for $icaoCode');
          return MetarData.fromJson(data as Map<String, dynamic>);
        }
      }

      return null;
    } catch (e) {
      // Silent fail - METAR is optional
      return null;
    }
  }

  /// Search for airports within a radius and try to get METAR (tries up to 3 closest airports)
  Future<MetarData?> _searchNearbyAirports(
      double latitude, double longitude) async {
    // List of nearby airports (20km radius for accurate local weather)
    final nearbyAirports =
        _findNearbyAirportICAOs(latitude, longitude, radiusKm: 20);

    if (nearbyAirports.isEmpty) {
      print('   ⚠️ No airports found within 20km radius');
      return null;
    }

    // Try up to 3 closest airports in case some don't have METAR data
    for (final icao in nearbyAirports.take(3)) {
      final metar = await _fetchMetarByIcao(icao).timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      if (metar != null) {
        print('   ✅ Found METAR from nearby airport using coordinates!');
        return metar;
      }
    }

    return null;
  }

  /// Find nearby airport ICAO codes (optimized - return sorted by distance)
  List<String> _findNearbyAirportICAOs(double latitude, double longitude,
      {double radiusKm = 20}) {
    // Database of major world airports with coordinates
    // 20km radius is sufficient for metro areas
    final airports = {
      // Pakistan - all major airports
      'OPIS': {'lat': 33.6167, 'lon': 73.0994}, // Islamabad International
      'OPRN': {
        'lat': 33.6169,
        'lon': 73.0991
      }, // Benazir Bhutto (old Islamabad)
      'OPKC': {'lat': 24.9065, 'lon': 67.1608}, // Karachi Jinnah
      'OPLA': {'lat': 31.5217, 'lon': 74.4036}, // Lahore Allama Iqbal
      'OPPS': {'lat': 33.9939, 'lon': 71.5146}, // Peshawar Bacha Khan
      'OPQT': {'lat': 30.2514, 'lon': 66.9378}, // Quetta
      'OPMT': {'lat': 30.2031, 'lon': 71.4197}, // Multan
      'OPFA': {'lat': 31.3650, 'lon': 72.9947}, // Faisalabad
      'OPST': {'lat': 32.5356, 'lon': 74.3639}, // Sialkot
      'OPGD': {'lat': 25.2333, 'lon': 62.3294}, // Gwadar
      'OPDI': {'lat': 35.9186, 'lon': 74.7364}, // Gilgit
      'OPSD': {'lat': 35.3356, 'lon': 75.5364}, // Skardu

      // International - major hubs
      'OMDB': {'lat': 25.2528, 'lon': 55.3644}, // Dubai
      'OMDW': {'lat': 24.8961, 'lon': 55.1619}, // Dubai Al Maktoum
      'OERK': {'lat': 24.9576, 'lon': 46.6988}, // Riyadh
      'OEJN': {'lat': 21.6796, 'lon': 39.1565}, // Jeddah
      'OEMA': {'lat': 21.4859, 'lon': 39.6987}, // Makkah (nearby)
      'EGLL': {'lat': 51.4700, 'lon': -0.4543}, // London Heathrow
      'KJFK': {'lat': 40.6413, 'lon': -73.7781}, // New York JFK
      'KEWR': {'lat': 40.6925, 'lon': -74.1687}, // Newark
      'KLGA': {'lat': 40.7769, 'lon': -73.8740}, // LaGuardia
      'KLAX': {'lat': 33.9416, 'lon': -118.4085}, // Los Angeles
      'VIDP': {'lat': 28.5665, 'lon': 77.1031}, // Delhi Indira Gandhi
      'VABB': {'lat': 19.0896, 'lon': 72.8656}, // Mumbai
      'VTBS': {'lat': 13.6900, 'lon': 100.7501}, // Bangkok
      'WSSS': {'lat': 1.3644, 'lon': 103.9915}, // Singapore Changi
      'VHHH': {'lat': 22.3080, 'lon': 113.9185}, // Hong Kong
      'RJTT': {'lat': 35.5533, 'lon': 139.7811}, // Tokyo Haneda
      'LFPG': {'lat': 49.0097, 'lon': 2.5479}, // Paris CDG
      'EDDF': {'lat': 50.0264, 'lon': 8.5431}, // Frankfurt
      'EHAM': {'lat': 52.3105, 'lon': 4.7683}, // Amsterdam
      'LTFM': {'lat': 41.2608, 'lon': 28.7419}, // Istanbul
      'CYYZ': {'lat': 43.6772, 'lon': -79.6306}, // Toronto
      'YSSY': {'lat': -33.9461, 'lon': 151.1772}, // Sydney
    };

    final nearby = <MapEntry<String, double>>[];

    // Calculate distances for all airports
    airports.forEach((icao, coords) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        coords['lat']!,
        coords['lon']!,
      );

      if (distance <= radiusKm) {
        nearby.add(MapEntry(icao, distance));
      }
    });

    // Sort by distance (closest first)
    nearby.sort((a, b) => a.value.compareTo(b.value));

    // Print only the closest one for efficiency
    if (nearby.isNotEmpty) {
      print(
          '   📍 Closest airport: ${nearby.first.key} at ${nearby.first.value.toStringAsFixed(1)} km');
    }

    // Return only ICAO codes, sorted by distance
    return nearby.map((e) => e.key).toList();
  }

  /// Get known ICAO code for a city
  String? _getKnownIcaoCode(String cityName) {
    // Try exact match (case-insensitive)
    for (var entry in cityAirports.entries) {
      if (entry.key.toLowerCase() == cityName.toLowerCase()) {
        return entry.value.first; // Return first airport
      }
    }

    // Try partial match
    for (var entry in cityAirports.entries) {
      if (entry.key.toLowerCase().contains(cityName.toLowerCase()) ||
          cityName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value.first;
      }
    }

    return null;
  }

  /// Check if a city has METAR support
  static bool isCitySupported(String cityName) {
    return cityAirports.keys
        .any((city) => city.toLowerCase() == cityName.toLowerCase());
  }

  /// Get ICAO code for a specific city (for known airports)
  static String? getIcaoCode(String cityName) {
    for (var entry in cityAirports.entries) {
      if (entry.key.toLowerCase() == cityName.toLowerCase()) {
        return entry.value.first;
      }
    }
    return null;
  }

  /// Get list of all supported cities
  static List<String> getSupportedCities() {
    return cityAirports.keys.toList();
  }

  /// Calculate distance between two coordinates (in kilometers)
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
