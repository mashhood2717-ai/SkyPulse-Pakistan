import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weather_model.dart';
import '../providers/settings_provider.dart';

class HourlyForecast extends StatelessWidget {
  final WeatherData weatherData;

  const HourlyForecast({
    Key? key,
    required this.weatherData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hourlyData = _extractHourlyData(context); // Pass context to get settings

    if (hourlyData.isEmpty) {
      return const SizedBox(
        child: Center(
          child: Text(
            'No hourly data available',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hourly Forecast (Next 24h)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(
              hourlyData.length,
              (index) {
                final hour = hourlyData[index];
                return _buildHourCard(hour);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHourCard(Map<String, dynamic> hour) {
    return Container(
      width: 65,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time
          Text(
            hour['time'],
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Icon
          Text(
            hour['icon'],
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 4),

          // Temperature (from API)
          Text(
            '${hour['temp']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),

          // Precipitation chance
          if (hour['precipitation'] != null && hour['precipitation'] > 0)
            Text(
              '${hour['precipitation']}%',
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  /// Extract next 24 hours from current hour onwards
  List<Map<String, dynamic>> _extractHourlyData(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    List<Map<String, dynamic>> hourly = [];

    try {
      // Check if we have hourly data from API
      if (weatherData.hourlyTemperatures.isEmpty ||
          weatherData.hourlyTimes.isEmpty) {
        return [];
      }

      final now = DateTime.now();
      int startIndex = now.hour; // Direct calculation instead of looping

      // Verify the index matches by checking the first time entry
      // to ensure we're on the same day (API data is always from midnight today)
      if (startIndex >= weatherData.hourlyTemperatures.length) {
        startIndex = 0;
      }

      // Get next 24 hours from start index
      for (int i = 0; i < 24; i++) {
        final apiIndex = startIndex + i;

        // Check if we have data at this index
        if (apiIndex >= weatherData.hourlyTemperatures.length) {
          break;
        }

        // Get time string and format it
        String timeStr = 'N/A';
        if (apiIndex < weatherData.hourlyTimes.length) {
          try {
            final hourTime = DateTime.parse(weatherData.hourlyTimes[apiIndex]);
            timeStr = i == 0 ? 'Now' : '${hourTime.hour}:00';
          } catch (e) {
            timeStr = i == 0 ? 'Now' : '${(now.hour + i) % 24}:00';
          }
        }

        // Get REAL temperature from API
        double temp = weatherData.hourlyTemperatures[apiIndex];

        // Get weather code for icon
        int weatherCode = apiIndex < weatherData.hourlyWeatherCodes.length
            ? weatherData.hourlyWeatherCodes[apiIndex]
            : 0;

        // Get precipitation
        int precipitation = apiIndex < weatherData.hourlyPrecipitation.length
            ? weatherData.hourlyPrecipitation[apiIndex]
            : 0;

        // Get weather icon (using actual hour from API time when available)
        int displayHour = now.hour + i;
        if (apiIndex < weatherData.hourlyTimes.length) {
          try {
            displayHour =
                DateTime.parse(weatherData.hourlyTimes[apiIndex]).hour;
          } catch (_) {}
        }
        // Prefer the API's hourly is_day flag when available
        bool? apiIsDay = apiIndex < weatherData.hourlyIsDay.length
            ? weatherData.hourlyIsDay[apiIndex]
            : null;
        String icon = _getWeatherIcon(weatherCode, displayHour,
            precipProb: precipitation, isDayOverride: apiIsDay);

        hourly.add({
          'time': timeStr,
          'temp': settings.getTempString(temp),
          'icon': icon,
          'precipitation': precipitation > 0 ? precipitation : null,
        });
      }
    } catch (e) {
      print('❌ [HourlyForecast] Error: $e');
    }

    return hourly;
  }

  String _getWeatherIcon(int code, int hour,
      {int precipProb = 0, bool? isDayOverride}) {
    // Determine if day or night.
    // Prefer the API's is_day flag if provided; otherwise fall back to hour-based check.
    final int h = ((hour % 24) + 24) % 24;
    final bool isDay = isDayOverride ?? (h >= 6 && h < 20);

    switch (code) {
      case 0:
        return isDay ? '☀️' : '🌙';
      case 1:
        return isDay ? '🌤️' : '🌙';
      case 2:
        return isDay ? '⛅' : '☁️';
      case 3:
        return '☁️';
      case 45:
      case 48:
        return '🌫️';
      case 51:
      case 53:
      case 55:
        return '🌦️';
      case 61:
      case 63:
      case 65:
        return '🌧️';
      case 71:
      case 73:
      case 75:
      case 77:
        return '❄️';
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 85:
      case 86:
        return '🌨️';
      case 95:
      case 96:
      case 99:
        return '⛈️';
      default:
        return isDay ? '🌤️' : '🌙';
    }
  }
}
