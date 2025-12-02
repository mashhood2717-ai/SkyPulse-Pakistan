import 'package:flutter/material.dart';
import '../models/weather_model.dart';

class HourlyForecast extends StatelessWidget {
  final WeatherData weatherData;

  const HourlyForecast({
    Key? key,
    required this.weatherData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hourlyData = _extractHourlyData();

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
            '${hour['temp']}°',
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
  List<Map<String, dynamic>> _extractHourlyData() {
    List<Map<String, dynamic>> hourly = [];

    try {
      // Check if we have hourly data from API
      if (weatherData.hourlyTemperatures.isEmpty ||
          weatherData.hourlyTimes.isEmpty) {
        return [];
      }

      // Find current time in the hourly times array
      // API returns times in ISO format: "2025-01-08T07:00" or similar
      final now = DateTime.now();
      int startIndex = 0;

      // Find the index that matches the current hour
      if (weatherData.hourlyTimes.isNotEmpty) {
        for (int i = 0; i < weatherData.hourlyTimes.length; i++) {
          final timeStr = weatherData.hourlyTimes[i]; // e.g., "2025-01-08T07:00"
          try {
            final hourTime = DateTime.parse(timeStr);
            // Check if this hour is >= current time
            if (hourTime.hour == now.hour && hourTime.day == now.day) {
              startIndex = i;
              print('🕐 [HourlyForecast] Found current hour at index $i: $timeStr');
              break;
            }
            // Also check if we're past this hour and approaching next one
            if (hourTime.hour > now.hour && hourTime.day == now.day) {
              // Use the previous hour (closest match)
              startIndex = i > 0 ? i - 1 : 0;
              print(
                  '🕐 [HourlyForecast] No exact match, using nearest index $startIndex');
              break;
            }
          } catch (e) {
            // Skip parsing errors
          }
        }
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
            final hourTime =
                DateTime.parse(weatherData.hourlyTimes[apiIndex]);
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

        // Get weather icon (using hour from the actual API time)
        int displayHour = now.hour + i;
        String icon = _getWeatherIcon(weatherCode, displayHour);

        // Get precipitation
        int precipitation = apiIndex < weatherData.hourlyPrecipitation.length
            ? weatherData.hourlyPrecipitation[apiIndex]
            : 0;

        hourly.add({
          'time': timeStr,
          'temp': temp.round(),
          'icon': icon,
          'precipitation': precipitation > 0 ? precipitation : null,
        });
      }
    } catch (e) {
      print('❌ [HourlyForecast] Error: $e');
    }

    return hourly;
  }

  String _getWeatherIcon(int code, int hour) {
    // Determine if day or night (6am-8pm is day in Pakistan)
    final isDay = hour >= 6 && hour < 20;

    if (!isDay) return '🌙';

    switch (code) {
      case 0:
        return '☀️';
      case 1:
        return '🌤️';
      case 2:
        return '⛅';
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
        return '🌤️';
    }
  }
}
