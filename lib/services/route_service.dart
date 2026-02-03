import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'weather_service.dart';

/// Simple route helper with motorway interchange coordinates (ordered)
class RouteService {
  /// Example ordered interchanges for the M2 motorway (Islamabad → Lahore)
  /// Note: coordinates are approximate and used to demonstrate the feature.
  static const Map<String, List<Map<String, dynamic>>> _motorways = {
    'M2': [
      {
        'name': 'Islamabad Toll Plaza',
        'lat': (33.6103 + 33.6098) / 2,
        'lon': (72.9010 + 72.9015) / 2,
        'km': 349
      },
      {
        'name': 'Thalian',
        'lat': (33.5500 + 33.5495) / 2,
        'lon': (72.8600 + 72.8605) / 2,
        'km': 340
      },
      {
        'name': 'Capital Smart City',
        'lat': (33.4800 + 33.4795) / 2,
        'lon': (72.8200 + 72.8205) / 2,
        'km': 332
      },
      {
        'name': 'Chakri',
        'lat': (33.4100 + 33.4095) / 2,
        'lon': (72.8000 + 72.8005) / 2,
        'km': 320
      },
      {
        'name': 'Neela Dullah',
        'lat': (33.1500 + 33.1495) / 2,
        'lon': (72.7500 + 72.7505) / 2,
        'km': 295
      },
      {
        'name': 'Balkasar',
        'lat': (32.9200 + 32.9195) / 2,
        'lon': (72.6800 + 72.6805) / 2,
        'km': 266
      },
      {
        'name': 'Kallar Kahar',
        'lat': (32.7830 + 32.7825) / 2,
        'lon': (72.7000 + 72.7005) / 2,
        'km': 245
      },
      {
        'name': 'Lillah',
        'lat': (32.6500 + 32.6495) / 2,
        'lon': (72.9500 + 72.9505) / 2,
        'km': 220
      },
      {
        'name': 'Bhera',
        'lat': (32.4800 + 32.4795) / 2,
        'lon': (72.9300 + 72.9305) / 2,
        'km': 195
      },
      {
        'name': 'Salam',
        'lat': (32.3500 + 32.3495) / 2,
        'lon': (72.9800 + 72.9805) / 2,
        'km': 175
      },
      {
        'name': 'Kot Momin',
        'lat': (32.1900 + 32.1895) / 2,
        'lon': (73.0200 + 73.0205) / 2,
        'km': 155
      },
      {
        'name': 'Sial Morr/Makhdoom',
        'lat': (32.0500 + 32.0495) / 2,
        'lon': (73.1500 + 73.1505) / 2,
        'km': 135
      },
      {
        'name': 'Pindi Bhattian',
        'lat': (31.8950 + 31.8945) / 2,
        'lon': (73.2706 + 73.2711) / 2,
        'km': 115
      },
      {
        'name': 'Kot Sarwar',
        'lat': (31.8300 + 31.8295) / 2,
        'lon': (73.4000 + 73.4005) / 2,
        'km': 95
      },
      {
        'name': 'Khanqah Dogran',
        'lat': (31.8317 + 31.8312) / 2,
        'lon': (73.6231 + 73.6236) / 2,
        'km': 82
      },
      {
        'name': 'Hiran Minar',
        'lat': (31.7500 + 31.7495) / 2,
        'lon': (73.8000 + 73.8005) / 2,
        'km': 65
      },
      {
        'name': 'Sheikhupura',
        'lat': (31.7100 + 31.7095) / 2,
        'lon': (73.9800 + 73.9805) / 2,
        'km': 50
      },
      {
        'name': 'Kot Pindi Das',
        'lat': (31.6500 + 31.6495) / 2,
        'lon': (74.0500 + 74.0505) / 2,
        'km': 38
      },
      {
        'name': 'Kot Abdul Malik',
        'lat': (31.6200 + 31.6195) / 2,
        'lon': (74.1200 + 74.1205) / 2,
        'km': 28
      },
      {
        'name': 'Faizpur',
        'lat': (31.5800 + 31.5795) / 2,
        'lon': (74.1800 + 74.1805) / 2,
        'km': 18
      },
      {
        'name': 'Ravi',
        'lat': (31.5570 + 31.5565) / 2,
        'lon': (74.2340 + 74.2345) / 2,
        'km': 10
      },
      {
        'name': 'Babu Sabu',
        'lat': (31.5400 + 31.5395) / 2,
        'lon': (74.2800 + 74.2805) / 2,
        'km': 5
      },
    ],
  };

  /// Return the list of interchanges for a motorway, or empty list
  static List<Map<String, dynamic>> getInterchanges(String motorway) {
    return _motorways[motorway] ?? [];
  }

  /// Find the index of the nearest interchange to current coords
  static int _nearestIndex(double lat, double lon, List<Map<String, dynamic>> pts) {
    double best = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final d = _haversineDistance(lat, lon, p['lat'], p['lon']);
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  /// Get the next interchange ahead on the motorway.
  /// If [destLat]/[destLon] provided, determine travel direction by
  /// comparing nearest interchange indices for current and destination.
  /// Returns null if motorway not known or there is no next interchange.
  static Map<String, dynamic>? getNextInterchange(
      String motorway, double lat, double lon,
      {double? destLat, double? destLon}) {
    final pts = getInterchanges(motorway);
    if (pts.isEmpty) return null;

    final nearest = _nearestIndex(lat, lon, pts);

    // Determine direction: forward (increasing index) or backward
    bool forward = true;
    if (destLat != null && destLon != null) {
      final destIdx = _nearestIndex(destLat, destLon, pts);
      forward = destIdx >= nearest;
    }

    int? nextIdx;
    if (forward) {
      nextIdx = (nearest + 1) < pts.length ? (nearest + 1) : null;
    } else {
      nextIdx = (nearest - 1) >= 0 ? (nearest - 1) : null;
    }

    if (nextIdx == null) return null;

    final next = pts[nextIdx];
    final distanceKm = _haversineDistance(lat, lon, next['lat'], next['lon']);

    return {
      'index': nextIdx,
      'name': next['name'],
      'lat': next['lat'],
      'lon': next['lon'],
      'distance_km': distanceKm,
      'forward': forward,
    };
  }

  /// Haversine distance (km)
  static double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) * math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  /// Public helper for distance between two coords (km)
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    return _haversineDistance(lat1, lon1, lat2, lon2);
  }

  /// Fetch route polyline from Google Directions API and decode to LatLng list
  /// Falls back to empty list on error.
  static Future<List<LatLng>> getRoutePolyline(
      double originLat, double originLon, double destLat, double destLon) async {
    await _ensureCacheLoaded();
    // Simple in-memory cache (TTL)
    const ttl = Duration(hours: 1);
    final key = _routeKey(originLat, originLon, destLat, destLon);
    final now = DateTime.now();
    final ts = _directionsCacheTimes[key];
    if (ts != null && now.difference(ts) <= ttl) {
      final cached = _directionsCache[key];
      if (cached != null && cached.isNotEmpty) return cached;
    }

    try {
      final apiKey = WeatherService.googleApiKey;
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=$originLat,$originLon&destination=$destLat,$destLon&key=$apiKey&mode=driving');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      final data = json.decode(resp.body);
      if (data == null || data['routes'] == null || data['routes'].isEmpty) return [];
      final encoded = data['routes'][0]['overview_polyline']?['points'] ?? '';
      if (encoded.isEmpty) return [];
      final poly = _decodePolyline(encoded);
      _directionsCache[key] = poly;
      _directionsCacheTimes[key] = now;
      _persistCacheEntry(key, encoded, now);
      return poly;
    } catch (e) {
      print('❌ [RouteService] Error fetching directions: $e');
      return [];
    }
  }

  /// Decode Google's encoded polyline into list of LatLng
  static List<LatLng> _decodePolyline(String encoded) {
    var poly = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      final latLng = LatLng(lat / 1e5, lng / 1e5);
      poly.add(latLng);
    }
    return poly;
  }

  // Simple cache storage for directions
  static final Map<String, List<LatLng>> _directionsCache = {};
  static final Map<String, DateTime> _directionsCacheTimes = {};

  // Persistent cache backing
  static bool _cacheLoaded = false;
  static const String _prefsKey = 'RouteService.directions_cache_v1';

  static Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        _cacheLoaded = true;
        return;
      }
      final Map<String, dynamic> m = json.decode(raw) as Map<String, dynamic>;
      m.forEach((key, value) {
        try {
          final entry = value as Map<String, dynamic>;
          final timeStr = entry['time'] as String?;
          final points = entry['points'] as List<dynamic>?;
          if (timeStr != null && points != null) {
            final dt = DateTime.tryParse(timeStr);
            if (dt != null) {
              _directionsCacheTimes[key] = dt;
              final list = <LatLng>[];
              for (final p in points) {
                if (p is List && p.length >= 2) {
                  final lat = (p[0] as num).toDouble();
                  final lon = (p[1] as num).toDouble();
                  list.add(LatLng(lat, lon));
                }
              }
              if (list.isNotEmpty) _directionsCache[key] = list;
            }
          }
        } catch (_) {}
      });
    } catch (_) {}
    _cacheLoaded = true;
  }

  static Future<void> _persistCacheEntry(String key, String encodedPolyline, DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      Map<String, dynamic> m = {};
      if (raw != null) {
        try {
          m = json.decode(raw) as Map<String, dynamic>;
        } catch (_) {
          m = {};
        }
      }
      // store decoded points to avoid relying on Google encoded format on read
      final pts = _decodePolyline(encodedPolyline).map((p) => [p.latitude, p.longitude]).toList();
      m[key] = {'time': time.toIso8601String(), 'points': pts};
      await prefs.setString(_prefsKey, json.encode(m));
    } catch (e) {
      print('❌ [RouteService] Failed to persist cache entry: $e');
    }
  }

  static String _routeKey(double oLat, double oLon, double dLat, double dLon) {
    // Round coords to 5 decimal places to reduce key variability
    String r(double v) => (v.toStringAsFixed(5));
    return '${r(oLat)},${r(oLon)}|${r(dLat)},${r(dLon)}';
  }

  /// Default threshold (km) used to decide if an interchange is considered passed
  static const double defaultPassThresholdKm = 0.5;

  /// Estimate the vehicle's approximate km marker along the motorway by
  /// interpolating between the two nearest interchanges' km markers.
  /// Returns the nearest interchange km if interpolation isn't possible.
  static double estimateVehicleKm(String motorway, double lat, double lon) {
    final pts = getInterchanges(motorway);
    if (pts.isEmpty) return 0.0;

    // find two nearest points
    int bestIdx = -1;
    int secondIdx = -1;
    double bestD = double.infinity;
    double secondD = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final d = _haversineDistance(lat, lon, p['lat'], p['lon']);
      if (d < bestD) {
        secondD = bestD;
        secondIdx = bestIdx;
        bestD = d;
        bestIdx = i;
      } else if (d < secondD) {
        secondD = d;
        secondIdx = i;
      }
    }

    if (bestIdx == -1) return 0.0;
    final bestKm = (pts[bestIdx]['km'] as num).toDouble();
    if (secondIdx == -1) return bestKm;
    final secondKm = (pts[secondIdx]['km'] as num).toDouble();

    // simple inverse-distance interpolation between the two nearest markers
    final w1 = secondD;
    final w2 = bestD;
    final denom = (w1 + w2);
    if (denom == 0) return bestKm;
    final frac = w1 / denom; // fraction towards bestIdx->secondIdx
    return bestKm * (1.0 - frac) + secondKm * frac;
  }

  /// Determine whether the vehicle has passed the given interchange using
  /// km-marker logic and a small threshold (default 0.5 km).
  /// [interchange] is a map entry from the interchanges list and must contain
  /// a numeric 'km' field.
  static bool hasPassedInterchange(String motorway, double lat, double lon,
      Map<String, dynamic> interchange, bool forward,
      {double thresholdKm = defaultPassThresholdKm}) {
    final vehicleKm = estimateVehicleKm(motorway, lat, lon);
    final interchangeKm = (interchange['km'] as num).toDouble();
    if (forward) {
      return vehicleKm >= (interchangeKm + thresholdKm);
    } else {
      return vehicleKm <= (interchangeKm - thresholdKm);
    }
  }
}
