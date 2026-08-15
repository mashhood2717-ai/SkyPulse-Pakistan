import 'package:flutter_test/flutter_test.dart';
import 'package:skypulse_pakistan/models/metar_model.dart';

/// A response in the shape the Aviation Weather Center API returns, which is
/// the only path the app actually uses.
Map<String, dynamic> _awc({
  String icao = 'OPLA',
  double? temp = 32,
  double? dewp = 18,
  int? wdir = 270,
  double? wspd = 15,
  double? visib = 6.21,
  String? cover = 'FEW',
  double? altim = 1008,
  String? wxString,
}) =>
    {
      'icaoId': icao,
      'rawOb': '$icao 151200Z 27015KT 9999 FEW020 32/18 Q1008',
      'reportTime': '2026-08-15T12:00:00Z',
      'temp': temp,
      'dewp': dewp,
      'wdir': wdir,
      'wspd': wspd,
      'visib': visib,
      'cover': cover,
      'altim': altim,
      if (wxString != null) 'wxString': wxString,
    };

void main() {
  group('MetarData.fromJson', () {
    test('reads the AWC fields', () {
      final metar = MetarData.fromJson(_awc());

      expect(metar.icaoCode, 'OPLA');
      expect(metar.temperature, 32);
      expect(metar.dewpoint, 18);
      expect(metar.windDirection, 270);
      expect(metar.windSpeed, 15);
      expect(metar.pressure, 1008);
      expect(metar.clouds, 'FEW');
    });

    test('converts visibility from statute miles to kilometres', () {
      final metar = MetarData.fromJson(_awc(visib: 10));
      expect(metar.visibility, closeTo(16.09, 0.01));
    });

    test('handles negative temperatures', () {
      final metar = MetarData.fromJson(_awc(temp: -5, dewp: -8));
      expect(metar.temperature, -5);
      expect(metar.dewpoint, -8);
    });

    test('defaults the condition to Clear when wxString is absent', () {
      expect(MetarData.fromJson(_awc()).weatherCondition, 'Clear');
    });
  });

  group('toCurrentWeather', () {
    test('converts knots to km/h', () {
      final current = MetarData.fromJson(_awc(wspd: 20)).toCurrentWeather();
      // 20 kt == 37.04 km/h
      expect(current.windSpeed, closeTo(37.04, 0.01));
    });

    test('derives relative humidity from temperature and dewpoint', () {
      // Temperature equal to dewpoint means saturation.
      final current =
          MetarData.fromJson(_awc(temp: 20, dewp: 20)).toCurrentWeather();
      expect(current.humidity, 100);

      final dry =
          MetarData.fromJson(_awc(temp: 35, dewp: 5)).toCurrentWeather();
      expect(dry.humidity, lessThan(20));
    });

    test('day/night comes from sunrise and sunset instants', () {
      final metar = MetarData.fromJson(_awc());
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(
        metar.toCurrentWeather(sunrise: now - 3600, sunset: now + 3600).isDay,
        isTrue,
      );
      expect(
        metar.toCurrentWeather(sunrise: now - 7200, sunset: now - 3600).isDay,
        isFalse,
      );
    });

    test('maps smoke to a fog-like code and a readable description', () {
      final current =
          MetarData.fromJson(_awc(wxString: 'FU')).toCurrentWeather();

      expect(current.weatherCode, 45);
      expect(current.customDescription, 'Smoke');
    });

    test('maps thunderstorms with rain to the thunderstorm code', () {
      final current =
          MetarData.fromJson(_awc(wxString: 'TSRA')).toCurrentWeather();

      expect(current.weatherCode, 95);
      expect(current.customDescription, 'Thunderstorm with Rain');
    });

    test('derives cloud cover percentage from the cover code', () {
      expect(
        MetarData.fromJson(_awc(cover: 'OVC')).toCurrentWeather().cloudCover,
        100,
      );
      expect(
        MetarData.fromJson(_awc(cover: 'CLR')).toCurrentWeather().cloudCover,
        0,
      );
    });
  });
}
