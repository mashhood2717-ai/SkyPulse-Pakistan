import 'package:flutter_test/flutter_test.dart';
import 'package:skypulse_pakistan/services/geocoding_service.dart';

void main() {
  group('resolvePlaceId', () {
    test('round-trips coordinates, country and parent city', () {
      // Suggestions embed their own coordinates so a tap costs no network
      // call. The separator is a pipe because city names contain commas.
      final resolved = GeocodingService.resolvePlaceId(
        'geo:31.4805|74.3239|PK|Lahore',
        'Model Town',
      );

      expect(resolved, isNotNull);
      expect(resolved!['latitude'], closeTo(31.4805, 1e-9));
      expect(resolved['longitude'], closeTo(74.3239, 1e-9));
      expect(resolved['country'], 'PK');
      expect(resolved['name'], 'Model Town');
      expect(resolved['city'], 'Lahore');
    });

    test('falls back to the tapped label when no parent city is known', () {
      final resolved = GeocodingService.resolvePlaceId(
        'geo:35.2971|75.6333|PK|',
        'Skardu',
      );

      expect(resolved!['city'], 'Skardu');
    });

    test('handles negative coordinates', () {
      final resolved = GeocodingService.resolvePlaceId(
        'geo:-33.8688|151.2093|AU|Sydney',
        'Sydney',
      );

      expect(resolved!['latitude'], closeTo(-33.8688, 1e-9));
      expect(resolved['longitude'], closeTo(151.2093, 1e-9));
    });

    test('returns null for ids it did not produce', () {
      // Google place_ids look like this; callers fall back to a name search.
      expect(
        GeocodingService.resolvePlaceId('ChIJLfyY2E4EGTkRVAmfKtvHQAY', 'Lahore'),
        isNull,
      );
      expect(GeocodingService.resolvePlaceId('geo:notanumber', 'X'), isNull);
      expect(GeocodingService.resolvePlaceId('', 'X'), isNull);
    });
  });

  group('suggestions', () {
    test('ignores queries shorter than two characters', () async {
      // Guards the Nominatim rate limit; must not issue a request.
      expect(await GeocodingService.suggestions(''), isEmpty);
      expect(await GeocodingService.suggestions('L'), isEmpty);
      expect(await GeocodingService.suggestions('  '), isEmpty);
    });
  });
}
