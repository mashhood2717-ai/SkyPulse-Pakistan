import 'package:flutter_test/flutter_test.dart';
import 'package:skypulse_pakistan/utils/city_areas.dart';

void main() {
  group('majorCityFor', () {
    test('maps neighbourhoods onto their city', () {
      expect(CityAreas.majorCityFor('Model Town'), 'lahore');
      expect(CityAreas.majorCityFor('Old Clifton'), 'karachi');
      expect(CityAreas.majorCityFor('Hayatabad'), 'peshawar');
    });

    test('a city name outranks a shared neighbourhood name', () {
      // "cantt" and "dha" appear under several cities, so a match on the city
      // itself has to win or the result depends on map ordering.
      expect(CityAreas.majorCityFor('Multan Cantt'), 'multan');
      expect(CityAreas.majorCityFor('Lahore DHA'), 'lahore');
    });

    test('returns null for places it does not know', () {
      expect(CityAreas.majorCityFor('Skardu'), isNull);
      expect(CityAreas.majorCityFor('Dubai'), isNull);
    });
  });

  group('alertCityFor', () {
    test('collapses sub-areas and administrative suffixes to the city', () {
      // These are the exact strings Nominatim returns for real GPS points.
      expect(CityAreas.alertCityFor('Model Town'), 'lahore');
      expect(CityAreas.alertCityFor('Peshawar City'), 'peshawar');
      expect(CityAreas.alertCityFor('Faisalabad City'), 'faisalabad');
      expect(CityAreas.alertCityFor('Islamabad'), 'islamabad');
    });

    test('leaves smaller towns on their own topic', () {
      // mailsi_city_alerts and hazro_alerts are published topics; collapsing
      // them would silently unsubscribe those users.
      expect(CityAreas.alertCityFor('Mailsi City'), 'mailsi city');
      expect(CityAreas.alertCityFor('Hazro'), 'hazro');
    });
  });

  group('isSameArea', () {
    test('treats a neighbourhood and its city as the same area', () {
      expect(CityAreas.isSameArea('Samanabad Lahore', 'Lahore'), isTrue);
      expect(CityAreas.isSameArea('I-8/3 Islamabad', 'Islamabad'), isTrue);
    });

    test('keeps different cities apart', () {
      expect(CityAreas.isSameArea('Lahore', 'Karachi'), isFalse);
      expect(CityAreas.isSameArea('Model Town', 'Peshawar'), isFalse);
    });

    test('handles unknown places without false positives', () {
      expect(CityAreas.isSameArea('Skardu', 'Gilgit'), isFalse);
      expect(CityAreas.isSameArea('Mailsi', 'Mailsi City'), isTrue);
    });

    test('is false for empty input', () {
      expect(CityAreas.isSameArea('', 'Lahore'), isFalse);
    });
  });
}
