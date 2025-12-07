import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import 'wind_compass.dart';

class WeatherDetails extends StatelessWidget {
  final CurrentWeather current;

  const WeatherDetails({
    Key? key,
    required this.current,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get wind direction from METAR if available, otherwise from API
    final provider = Provider.of<WeatherProvider>(context, listen: false);
    final windDirection = provider.metarData?.windDirection?.toDouble() ??
        current.windDirection.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Current Conditions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Row 1: Wind (with compass) and Humidity
        Row(
          children: [
            Expanded(
              child: _buildWindTile(windDirection),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailTile(
                icon: Icons.water_drop,
                iconColor: const Color(0xFF4FC3F7),
                label: 'Humidity',
                value: '${current.humidity}%',
                backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Dew Point and Wind Gust (hide gust if 0, show wind speed instead)
        Row(
          children: [
            Expanded(
              child: _buildDetailTile(
                icon: Icons.thermostat,
                iconColor: const Color(0xFF81C784),
                label: 'Dew Point',
                value: '${current.dewPoint.toStringAsFixed(1)}°C',
                backgroundColor: const Color(0xFF81C784).withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: current.windGust > 0
                  ? _buildDetailTile(
                      icon: Icons.air,
                      iconColor: const Color(0xFF64B5F6),
                      label: 'Wind Gust',
                      value: '${current.windGust.round()} km/h',
                      backgroundColor: const Color(0xFF64B5F6).withOpacity(0.1),
                    )
                  : _buildDetailTile(
                      icon: Icons.air,
                      iconColor: const Color(0xFF64B5F6),
                      label: 'Wind Speed',
                      value: '${current.windSpeed.round()} km/h',
                      backgroundColor: const Color(0xFF64B5F6).withOpacity(0.1),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3: UV Index and Visibility
        Row(
          children: [
            Expanded(
              child: _buildDetailTile(
                icon: Icons.wb_sunny,
                iconColor: _getUVColor(current.uvIndex),
                label: 'UV Index',
                value: '${current.uvIndex.round()}\n${current.uvIndexCategory}',
                backgroundColor: _getUVColor(current.uvIndex).withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailTile(
                icon: Icons.visibility,
                iconColor: const Color(0xFF9C27B0),
                label: 'Visibility',
                value: '${current.visibility.toStringAsFixed(1)} km',
                backgroundColor: const Color(0xFF9C27B0).withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 4: Pressure and Cloud Cover
        Row(
          children: [
            Expanded(
              child: _buildDetailTile(
                icon: Icons.compress,
                iconColor: const Color(0xFFFF7043),
                label: 'Pressure',
                value: '${current.pressure.round()} hPa',
                backgroundColor: const Color(0xFFFF7043).withOpacity(0.1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDetailTile(
                icon: Icons.cloud,
                iconColor: const Color(0xFF78909C),
                label: 'Cloud Cover',
                value: '${current.cloudCover}%',
                backgroundColor: const Color(0xFF78909C).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWindTile(double windDirection) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF66BB6A).withOpacity(0.15),
            const Color(0xFF66BB6A).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Wind Compass
          SizedBox(
            height: 80,
            width: 80,
            child: WindCompass(
              windSpeed: current.windSpeed,
              windDirection: windDirection,
            ),
          ),
          const SizedBox(height: 12),

          // Label and Value
          const Text(
            'Wind Speed',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${current.windSpeed.round()} km/h',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (windDirection > 0) ...[
            const SizedBox(height: 2),
            Text(
              '${windDirection.round()}°',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor.withOpacity(0.3),
            backgroundColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icon with colored background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),

          // Label
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Value
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getUVColor(double uvIndex) {
    if (uvIndex <= 2) return const Color(0xFF66BB6A); // Green
    if (uvIndex <= 5) return const Color(0xFFFDD835); // Yellow
    if (uvIndex <= 7) return const Color(0xFFFF9800); // Orange
    if (uvIndex <= 10) return const Color(0xFFF44336); // Red
    return const Color(0xFF9C27B0); // Purple
  }
}
