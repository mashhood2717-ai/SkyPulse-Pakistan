import 'dart:convert';
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

  /// Try to fetch METAR data for any city by searching nearby airports
  Future<MetarData?> getMetarDataForCity(
      String cityName, double latitude, double longitude) async {
    print('🔍 Attempting to find METAR data for $cityName');

    // 1. First, check if we have a known airport for this city
    final knownIcao = _getKnownIcaoCode(cityName);
    if (knownIcao != null) {
      print('   Found known airport: $knownIcao');
      final metar = await _fetchMetarByIcao(knownIcao);
      if (metar != null) return metar;
    }

    // 2. If not found, search for nearby airports using coordinates
    print('   Searching for nearby airports at ($latitude, $longitude)...');
    final nearbyMetar = await _searchNearbyAirports(latitude, longitude);
    if (nearbyMetar != null) {
      print('   ✅ Found METAR from nearby airport!');
      return nearbyMetar;
    }

    print('   ❌ No METAR data available for this location');
    return null;
  }

  /// Get METAR data for a specific ICAO code
  Future<MetarData?> _fetchMetarByIcao(String icaoCode) async {
    try {
      final url = Uri.parse('$awcBaseUrl?ids=$icaoCode&format=json');

      print('📡 Fetching METAR from: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        if (data is List && data.isNotEmpty) {
          print('✅ Successfully fetched METAR for $icaoCode');
          return MetarData.fromJson(data[0]);
        } else if (data is Map) {
          print('✅ Successfully fetched METAR for $icaoCode (Map format)');
          return MetarData.fromJson(data as Map<String, dynamic>);
        }
      }

      print('⚠️ No METAR data for $icaoCode');
      return null;
    } catch (e) {
      print('❌ Error fetching METAR for $icaoCode: $e');
      return null;
    }
  }

  /// Search for airports within a radius and try to get METAR
  Future<MetarData?> _searchNearbyAirports(
      double latitude, double longitude) async {
    // List of major airports with their approximate coordinates
    // This can be expanded or fetched from a database
    final nearbyAirports =
        _findNearbyAirportICAOs(latitude, longitude, radiusKm: 40);

    for (final icao in nearbyAirports) {
      final metar = await _fetchMetarByIcao(icao);
      if (metar != null) {
        return metar;
      }
    }

    return null;
  }

  /// Find nearby airport ICAO codes (simplified version)
  List<String> _findNearbyAirportICAOs(double latitude, double longitude,
      {double radiusKm = 40}) {
    // Database of major world airports with coordinates
    final airports = {
      // Pakistan
      'OPIS': {'lat': 33.6167, 'lon': 73.0994}, // Islamabad
      'OPKC': {'lat': 24.9065, 'lon': 67.1608}, // Karachi
      'OPLA': {'lat': 31.5217, 'lon': 74.4036}, // Lahore
      'OPPS': {'lat': 33.9939, 'lon': 71.5146}, // Peshawar
      'OPQT': {'lat': 30.2514, 'lon': 66.9378}, // Quetta
      'OPMT': {'lat': 30.2031, 'lon': 71.4197}, // Multan
      'OPFA': {'lat': 31.3650, 'lon': 72.9947}, // Faisalabad

      // International (add more as needed)
      'OMDB': {'lat': 25.2528, 'lon': 55.3644}, // Dubai
      'EGLL': {'lat': 51.4700, 'lon': -0.4543}, // London Heathrow
      'KJFK': {'lat': 40.6413, 'lon': -73.7781}, // New York JFK
      'KLAX': {'lat': 33.9416, 'lon': -118.4085}, // Los Angeles
      'VIDP': {'lat': 28.5665, 'lon': 77.1031}, // Delhi
      'VABB': {'lat': 19.0896, 'lon': 72.8656}, // Mumbai
      // Add more airports here...
    };

    final nearby = <String>[];

    airports.forEach((icao, coords) {
      final distance = _calculateDistance(
        latitude,
        longitude,
        coords['lat']!,
        coords['lon']!,
      );

      if (distance <= radiusKm) {
        nearby.add(icao);
        print('   📍 Found airport $icao at ${distance.toStringAsFixed(1)} km');
      }
    });

    return nearby;
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
