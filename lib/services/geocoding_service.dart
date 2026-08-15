import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Keyless geocoding for SkyPulse.
///
/// Google was removed here: the Geocoding and Places *web service* APIs cannot
/// be locked to an Android package + signature, so a key shipped in the APK is
/// always extractable. Every job below now runs on free providers.
///
///   reverse (coords -> address)   Nominatim
///   forward (name -> coords)      Open-Meteo -> Nominatim
///   suggestions (typeahead)       Nominatim -> Open-Meteo
///
/// Suggestions carry their own coordinates in the placeId, so resolving a tap
/// costs no network call at all.
class GeocodingService {
  static const String _nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String _openMeteoSearch =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// OSM's usage policy requires an identifying User-Agent.
  static const String _userAgent =
      'SkyPulsePakistan/1.2.0 (+https://weatherwalay.com)';

  /// Bias toward Pakistan without excluding the rest of the world.
  /// Nominatim viewbox order is lon,lat,lon,lat.
  static const String _pkViewbox = '60.5,37.5,78.0,23.0';

  /// OSM asks for at most one request per second. Requests are gated, not
  /// queued behind each other's responses, so spacing is on request *start*.
  static const Duration _minGap = Duration(milliseconds: 1100);
  static DateTime _lastNominatimCall = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void> _gate = Future<void>.value();

  /// Reverse-geocode results keyed to 4 decimal places (~11 m). Session-scoped.
  static final Map<String, Map<String, dynamic>> _reverseCache = {};

  /// Nominatim answers in the local language by default, which for Pakistan
  /// means Urdu ("اسلام آباد"). That breaks two things downstream: FCM topic
  /// names are sanitized to [a-z0-9_-] and would come out empty, and the
  /// city/neighbourhood matching tables are written in Latin script. Ask for
  /// English explicitly on every call.
  static const String _acceptLanguage = 'en';

  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Accept-Language': _acceptLanguage,
        'User-Agent': _userAgent,
      };

  static Future<T> _throttled<T>(Future<T> Function() action) {
    final gated = _gate.then((_) async {
      final since = DateTime.now().difference(_lastNominatimCall);
      if (since < _minGap) {
        await Future<void>.delayed(_minGap - since);
      }
      _lastNominatimCall = DateTime.now();
    });
    _gate = gated.catchError((_) {});
    return gated.then((_) => action());
  }

  // ---------------------------------------------------------------- reverse

  /// Coordinates -> a display name such as "Blue Area Islamabad".
  ///
  /// Never throws: on failure it returns the coordinates with an empty name so
  /// callers can decide what to show.
  static Future<Map<String, dynamic>> reverse(
    double latitude,
    double longitude,
  ) async {
    final cacheKey =
        '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    final cached = _reverseCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final url = Uri.parse('$_nominatimBase/reverse'
          '?lat=$latitude&lon=$longitude'
          '&format=jsonv2&zoom=16&addressdetails=1'
          '&accept-language=$_acceptLanguage');

      final response = await _throttled(
        () => http.get(url, headers: _headers).timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException('Reverse geocode timeout'),
            ),
      );

      if (response.statusCode != 200) {
        throw Exception('Nominatim reverse HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final address = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};

      final result = {
        'name': _composeAddress(address, fallback: data['name'] as String?),
        // The bare city, kept apart from the display name. Alert topics are
        // published per city, so they must not be built from "I-8/3 Islamabad".
        'city': _cityOf(address),
        'country': _countryCode(address),
        'latitude': latitude,
        'longitude': longitude,
      };

      _reverseCache[cacheKey] = result;
      return result;
    } catch (e) {
      return {
        'name': '',
        'city': '',
        'country': '',
        'latitude': latitude,
        'longitude': longitude,
      };
    }
  }

  // ---------------------------------------------------------------- forward

  /// Place name -> coordinates. Throws if no provider can resolve it.
  static Future<Map<String, dynamic>> forward(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw Exception('City name is empty');
    }

    try {
      final result = await _openMeteoForward(trimmed);
      if (result != null) return result;
    } catch (_) {
      // fall through to Nominatim
    }

    final result = await _nominatimForward(trimmed);
    if (result != null) return result;

    throw Exception('City not found: $trimmed');
  }

  static Future<Map<String, dynamic>?> _openMeteoForward(String query) async {
    final url = Uri.parse('$_openMeteoSearch'
        '?name=${Uri.encodeComponent(query)}&count=1&language=en&format=json');

    final response = await http.get(url).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Open-Meteo geocode timeout'),
        );

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null || results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    return {
      'latitude': (first['latitude'] as num).toDouble(),
      'longitude': (first['longitude'] as num).toDouble(),
      'name': (first['name'] as String?) ?? query,
      'city': (first['name'] as String?) ?? query,
      'country': (first['country_code'] as String?)?.toUpperCase() ?? '',
    };
  }

  static Future<Map<String, dynamic>?> _nominatimForward(String query) async {
    final matches = await _nominatimSearch(query, limit: 1);
    if (matches.isEmpty) return null;

    final first = matches.first;
    final address = (first['address'] as Map?)?.cast<String, dynamic>() ?? {};

    return {
      'latitude': double.parse(first['lat'] as String),
      'longitude': double.parse(first['lon'] as String),
      'name': (first['name'] as String?)?.trim().isNotEmpty == true
          ? first['name'] as String
          : query,
      'city': _cityOf(address),
      'country': _countryCode(address),
    };
  }

  // ------------------------------------------------------------ suggestions

  /// Typeahead results for the search bar.
  ///
  /// Nominatim leads because SkyPulse users search neighbourhoods ("Model Town
  /// Lahore", "DHA Phase 5") that Open-Meteo's city gazetteer does not carry.
  /// Open-Meteo covers the case where Nominatim is rate-limited or down.
  static Future<List<Map<String, dynamic>>> suggestions(String input) async {
    final trimmed = input.trim();
    if (trimmed.length < 2) return [];

    try {
      final matches = await _nominatimSearch(trimmed, limit: 6);
      if (matches.isNotEmpty) {
        return matches.map(_toSuggestion).toList();
      }
    } catch (_) {
      // fall through
    }

    try {
      return await _openMeteoSuggestions(trimmed);
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _openMeteoSuggestions(
    String query,
  ) async {
    final url = Uri.parse('$_openMeteoSearch'
        '?name=${Uri.encodeComponent(query)}&count=6&language=en&format=json');

    final response = await http.get(url).timeout(
          const Duration(seconds: 6),
          onTimeout: () => throw TimeoutException('Open-Meteo suggest timeout'),
        );

    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List?;
    if (results == null) return [];

    return results.map((raw) {
      final r = raw as Map<String, dynamic>;
      final name = (r['name'] as String?) ?? query;
      final region = [
        r['admin1'] as String?,
        r['country'] as String?,
      ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

      return {
        'description': region.isEmpty ? name : '$name, $region',
        'placeId': _encodePlaceId(
          (r['latitude'] as num).toDouble(),
          (r['longitude'] as num).toDouble(),
          (r['country_code'] as String?)?.toUpperCase() ?? '',
          name,
        ),
        'mainText': name,
        'secondaryText': region,
      };
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> _nominatimSearch(
    String query, {
    required int limit,
  }) async {
    final url = Uri.parse('$_nominatimBase/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=jsonv2&addressdetails=1&limit=$limit'
        '&accept-language=$_acceptLanguage'
        '&viewbox=$_pkViewbox&bounded=0');

    final response = await _throttled(
      () => http.get(url, headers: _headers).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Nominatim search timeout'),
          ),
    );

    if (response.statusCode != 200) {
      throw Exception('Nominatim search HTTP ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  static Map<String, dynamic> _toSuggestion(Map<String, dynamic> match) {
    final display = (match['display_name'] as String?) ?? '';
    final parts = display.split(',').map((p) => p.trim()).toList();
    final address = (match['address'] as Map?)?.cast<String, dynamic>() ?? {};

    final name = (match['name'] as String?)?.trim().isNotEmpty == true
        ? match['name'] as String
        : (parts.isNotEmpty ? parts.first : display);

    // Drop postcodes from the secondary line; they add noise, not context.
    final rest = parts
        .skip(1)
        .where((p) => p.isNotEmpty && !RegExp(r'^\d{4,}$').hasMatch(p))
        .take(3)
        .join(', ');

    return {
      'description': display,
      'placeId': _encodePlaceId(
        double.parse(match['lat'] as String),
        double.parse(match['lon'] as String),
        _countryCode(address),
        _cityOf(address),
      ),
      'mainText': name,
      'secondaryText': rest,
    };
  }

  // ------------------------------------------------------------- place ids

  /// Suggestions carry their coordinates inline, so a tap resolves locally.
  /// Pipe-separated because city names can contain commas.
  static String _encodePlaceId(
    double lat,
    double lon,
    String country,
    String city,
  ) =>
      'geo:$lat|$lon|$country|$city';

  /// Returns null when the id is not one of ours, so callers can fall back to
  /// a name search.
  static Map<String, dynamic>? resolvePlaceId(String placeId, String name) {
    if (!placeId.startsWith('geo:')) return null;

    final parts = placeId.substring(4).split('|');
    if (parts.length < 2) return null;

    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;

    final city = parts.length > 3 ? parts[3] : '';

    return {
      'latitude': lat,
      'longitude': lon,
      'name': name,
      // Falls back to the tapped label when the provider gave no parent city.
      'city': city.isNotEmpty ? city : name,
      'country': parts.length > 2 ? parts[2] : '',
    };
  }

  // --------------------------------------------------------------- helpers

  static String? _pick(Map<String, dynamic> address, List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// Nominatim labels Pakistani cities with their administrative suffix
  /// ("Karachi Division", "Lahore District"); users expect the bare name.
  static String _stripAdminSuffixes(String value) => value
      .replaceAll(' Capital Territory', '')
      .replaceAll(' Metropolitan Area', '')
      .replaceAll(' Division', '')
      .replaceAll(' District', '')
      .replaceAll(' Tehsil', '')
      .trim();

  /// The city a point belongs to, with no street-level detail.
  static String _cityOf(Map<String, dynamic> address) {
    final city = _pick(address, const [
      'city',
      'town',
      'village',
      'municipality',
      'city_district',
      'county',
      'state_district',
      'state',
    ]);
    return city == null ? '' : _stripAdminSuffixes(city);
  }

  /// Mirrors the old Google composition: most specific area + city, e.g.
  /// "I-8/3 Islamabad".
  static String _composeAddress(
    Map<String, dynamic> address, {
    String? fallback,
  }) {
    // 'residential' outranks 'suburb' here: in Islamabad it carries the sector
    // notation people actually use ("I-8/3") while suburb gives a landmark
    // ("I-8 Markaz Ground").
    final detailed = _pick(address, const [
      'neighbourhood',
      'residential',
      'suburb',
      'quarter',
      'city_block',
      'road',
    ]);
    final city = _cityOf(address);

    if (detailed != null && city.isNotEmpty && detailed != city) {
      return _stripAdminSuffixes('$detailed $city');
    }
    if (detailed != null) return _stripAdminSuffixes(detailed);
    if (city.isNotEmpty) return city;
    return _stripAdminSuffixes(fallback ?? '');
  }

  static String _countryCode(Map<String, dynamic> address) {
    final code = address['country_code'];
    if (code is String && code.isNotEmpty) return code.toUpperCase();
    return '';
  }
}
