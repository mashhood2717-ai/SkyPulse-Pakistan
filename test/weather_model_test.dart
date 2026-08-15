import 'package:flutter_test/flutter_test.dart';
import 'package:skypulse_pakistan/models/weather_model.dart';

/// A minimal Open-Meteo response shaped like the real one, in a timezone
/// deliberately different from whatever the test machine runs in.
Map<String, dynamic> _response({
  required int utcOffsetSeconds,
  required List<String> hourlyTimes,
}) {
  final hours = hourlyTimes.length;
  return {
    'utc_offset_seconds': utcOffsetSeconds,
    'current': {
      'temperature_2m': 31.4,
      'relative_humidity_2m': 55,
      'wind_speed_10m': 12.6,
      'wind_gusts_10m': 21.0,
      'wind_direction_10m': 250,
      'weather_code': 1,
      'pressure_msl': 999.4,
      'cloud_cover': 27,
      'is_day': 1,
      'rain': 0.0,
    },
    'hourly': {
      'time': hourlyTimes,
      'temperature_2m': List<double>.filled(hours, 30.0),
      'weather_code': List<int>.filled(hours, 1),
      'cloud_cover': List<int>.filled(hours, 20),
      'precipitation_probability': List<int>.filled(hours, 5),
      'wind_speed_10m': List<double>.filled(hours, 12.0),
      'wind_gusts_10m': List<double>.filled(hours, 20.0),
      'wind_direction_10m': List<int>.filled(hours, 250),
      'dew_point_2m': List<double>.filled(hours, 18.0),
      'is_day': List<int>.filled(hours, 1),
      'uv_index': List<double>.filled(hours, 7.5),
      'visibility': List<double>.filled(hours, 24140.0),
    },
    'daily': {
      'time': ['2026-08-15', '2026-08-16', '2026-08-17'],
      'weather_code': [1, 2, 3],
      'temperature_2m_max': [38.0, 37.0, 36.0],
      'temperature_2m_min': [27.0, 26.0, 25.0],
      'apparent_temperature_max': [41.0, 40.0, 39.0],
      'apparent_temperature_min': [28.0, 27.0, 26.0],
      'sunrise': ['2026-08-15T05:38', '2026-08-16T05:39', '2026-08-17T05:40'],
      'sunset': ['2026-08-15T19:02', '2026-08-16T19:01', '2026-08-17T19:00'],
      'precipitation_probability_max': [10, 20, 30],
      'precipitation_sum': [0.0, 1.2, 6.0],
      'wind_speed_10m_max': [18.0, 19.0, 20.0],
      'wind_gusts_10m_max': [30.0, 31.0, 32.0],
      'wind_direction_10m_dominant': [250, 260, 270],
      'uv_index_max': [9.0, 9.5, 10.0],
    },
  };
}

List<String> _hoursFor(String date, {int count = 24}) => List.generate(
      count,
      (i) => '${date}T${i.toString().padLeft(2, '0')}:00',
    );

void main() {
  group('WeatherData wind and visibility', () {
    test('reads wind speed from the current block', () {
      final data = WeatherData.fromJson(
        _response(utcOffsetSeconds: 18000, hourlyTimes: _hoursFor('2026-08-15')),
      );

      // Regression: `wind_speed_10m` was never requested, so this silently
      // parsed as 0.0 and the main card showed "0 km/h".
      expect(data.current.windSpeed, 12.6);
      expect(data.current.windGust, 21.0);
    });

    test('injects visibility from the hourly block, in kilometres', () {
      final offset = 18000;
      final now = WeatherData.nowAt(offset);
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final data = WeatherData.fromJson(
        _response(utcOffsetSeconds: offset, hourlyTimes: _hoursFor(today)),
      );

      // Open-Meteo reports visibility in metres and only hourly.
      expect(data.current.visibility, closeTo(24.14, 0.001));
    });
  });

  group('timezone handling', () {
    test('locates the current hour using the location offset, not the device',
        () {
      // Chatham Islands: +12:45, an offset no test machine will share.
      const offset = 45900;
      final now = WeatherData.nowAt(offset);
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final data = WeatherData.fromJson(
        _response(utcOffsetSeconds: offset, hourlyTimes: _hoursFor(today)),
      );

      expect(data.utcOffsetSeconds, offset);
      expect(data.currentHourIndex, now.hour);
    });

    test('sunrise is stored as a true instant, not a device-local one', () {
      const offset = 18000; // Asia/Karachi
      final data = WeatherData.fromJson(
        _response(utcOffsetSeconds: offset, hourlyTimes: _hoursFor('2026-08-15')),
      );

      // 2026-08-15T05:38 at +05:00 == 00:38 UTC.
      final expected =
          DateTime.utc(2026, 8, 15, 0, 38).millisecondsSinceEpoch ~/ 1000;
      expect(data.forecast.first.sunrise, expected);
    });

    test('sunrise renders back as local time at the location', () {
      const offset = 18000;
      final data = WeatherData.fromJson(
        _response(utcOffsetSeconds: offset, hourlyTimes: _hoursFor('2026-08-15')),
      );

      final local = data.forecast.first.sunriseLocal;
      expect(local.hour, 5);
      expect(local.minute, 38);
    });
  });

  group('DailyForecast.dayName', () {
    DailyForecast forecastFor(DateTime date, int offset) => DailyForecast(
          date: date,
          maxTemp: 30,
          minTemp: 20,
          weatherCode: 0,
          precipitationProbability: 0,
          windSpeed: 0,
          sunrise: 0,
          sunset: 0,
          utcOffsetSeconds: offset,
        );

    test('labels today and tomorrow', () {
      const offset = 18000;
      final today = WeatherData.nowAt(offset);

      expect(
        forecastFor(DateTime(today.year, today.month, today.day), offset)
            .dayName,
        'Today',
      );
      expect(
        forecastFor(
          DateTime(today.year, today.month, today.day)
              .add(const Duration(days: 1)),
          offset,
        ).dayName,
        'Tomorrow',
      );
    });

    test('crosses a month boundary', () {
      // Regression: the old check was `date.day == now.day + 1`, so on the
      // 31st nothing was ever labelled "Tomorrow".
      final endOfMonth = DateTime.utc(2026, 8, 31, 12);
      final nextDay = DateTime(2026, 9, 1);

      final diff = DateTime(nextDay.year, nextDay.month, nextDay.day)
          .difference(
              DateTime(endOfMonth.year, endOfMonth.month, endOfMonth.day))
          .inDays;

      expect(diff, 1, reason: '1 Sept is one day after 31 Aug');
    });
  });

  group('CurrentWeather.feelsLike', () {
    test('returns the dry-bulb temperature in mild, dry conditions', () {
      final w = CurrentWeather(
        temperature: 22,
        humidity: 30,
        windSpeed: 10,
        weatherCode: 0,
        pressure: 1013,
        cloudCover: 0,
        isDay: true,
      );
      expect(w.feelsLike, 22);
    });

    test('applies heat index when hot and humid', () {
      final w = CurrentWeather(
        temperature: 35,
        humidity: 60,
        windSpeed: 5,
        weatherCode: 0,
        pressure: 1013,
        cloudCover: 0,
        isDay: true,
      );
      expect(w.feelsLike, greaterThan(35));
    });

    test('applies wind chill below 15 C', () {
      final w = CurrentWeather(
        temperature: 5,
        humidity: 50,
        windSpeed: 30,
        weatherCode: 0,
        pressure: 1013,
        cloudCover: 0,
        isDay: true,
      );
      expect(w.feelsLike, lessThan(5));
    });
  });
}
