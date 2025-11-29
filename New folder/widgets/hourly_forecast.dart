import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_model.dart';

class HourlyForecast extends StatelessWidget {
  final WeatherData weatherData;

  const HourlyForecast({
    Key? key,
    required this.weatherData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate hourly data for next 24 hours
    final hourlyData = _generateHourlyData();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Hourly Forecast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourlyData.length,
            itemBuilder: (context, index) {
              final hour = hourlyData[index];
              return _buildHourCard(hour);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHourCard(Map<String, dynamic> hour) {
    return Container(
      width: 70,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time
          Text(
            hour['time'],
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Icon
          Text(
            hour['icon'],
            style: TextStyle(fontSize: 28),
          ),

          // Temperature
          Text(
            '${hour['temp']}°',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _generateHourlyData() {
    List<Map<String, dynamic>> hourly = [];

    // Get current time in Pakistan timezone (UTC+5)
    final now = DateTime.now().toUtc().add(Duration(hours: 5));
    final current = weatherData.current;

    // For next 24 hours
    for (int i = 0; i < 24; i++) {
      final time = now.add(Duration(hours: i));
      final timeStr = i == 0 ? 'Now' : DateFormat.Hm().format(time);

      // Simulate temperature variation (in real app, you'd fetch this from API)
      double temp = current.temperature + (i % 6 - 3);

      // Get weather icon based on time and current conditions
      String icon = _getHourlyIcon(time, current.weatherCode, current.isDay);

      hourly.add({
        'time': timeStr,
        'temp': temp.round(),
        'icon': icon,
      });
    }

    return hourly;
  }

  String _getHourlyIcon(DateTime time, int weatherCode, bool currentIsDay) {
    // Determine if this hour is day or night (Pakistan time)
    final hour = time.hour;
    final isDay = hour >= 6 && hour < 20;

    if (!isDay) return '🌙';

    // Use current weather code for icons
    switch (weatherCode) {
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
        return '❄️';
      case 77:
        return '🌨️';
      case 80:
      case 81:
      case 82:
        return '🌧️';
      case 85:
      case 86:
        return '🌨️';
      case 95:
        return '⛈️';
      case 96:
      case 99:
        return '⛈️';
      default:
        return '🌤️';
    }
  }
}
