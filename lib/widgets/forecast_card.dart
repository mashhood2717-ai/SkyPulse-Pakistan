import 'package:flutter/material.dart';
import 'dart:ui';
import '../models/weather_model.dart';

class ForecastCard extends StatelessWidget {
  final DailyForecast forecast;

  const ForecastCard({
    Key? key,
    required this.forecast,
  }) : super(key: key);

  void _showDetailDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDetailSheet(context),
    );
  }

  Widget _buildDetailSheet(BuildContext context) {
    final sunriseTime =
        DateTime.fromMillisecondsSinceEpoch(forecast.sunrise * 1000);
    final sunsetTime =
        DateTime.fromMillisecondsSinceEpoch(forecast.sunset * 1000);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E).withOpacity(0.95),
            const Color(0xFF0D47A1).withOpacity(0.95),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with date and icon
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      forecast.weatherIcon,
                      style: const TextStyle(fontSize: 50),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            forecast.dayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${forecast.date.day}/${forecast.date.month}/${forecast.date.year}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            forecast.weatherDescription,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${forecast.maxTemp.round()}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${forecast.minTemp.round()}°',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white24, height: 1),

              // Details grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Temperature row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.thermostat_outlined,
                              label: 'Feels Like High',
                              value: '${forecast.apparentTempMax.round()}°C',
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.thermostat_outlined,
                              label: 'Feels Like Low',
                              value: '${forecast.apparentTempMin.round()}°C',
                              color: Colors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Wind row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.air,
                              label: 'Max Wind',
                              value: '${forecast.windSpeed.round()} km/h',
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.storm,
                              label: 'Wind Gust',
                              value: '${forecast.windGust.round()} km/h',
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Wind direction and UV
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.explore,
                              label: 'Wind Direction',
                              value: _getWindDirection(forecast.windDirection),
                              color: Colors.indigo,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.wb_sunny_outlined,
                              label: 'UV Index',
                              value: forecast.uvIndexMax.toStringAsFixed(1),
                              color: _getUVColor(forecast.uvIndexMax),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Precipitation row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.water_drop,
                              label: 'Rain Chance',
                              value: '${forecast.precipitationProbability}%',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.grain,
                              label: 'Precipitation',
                              value:
                                  '${forecast.precipitationSum.toStringAsFixed(1)} mm',
                              color: Colors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Sunrise/Sunset row
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.wb_twilight,
                              label: 'Sunrise',
                              value:
                                  '${sunriseTime.hour.toString().padLeft(2, '0')}:${sunriseTime.minute.toString().padLeft(2, '0')}',
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDetailTile(
                              icon: Icons.nightlight_round,
                              label: 'Sunset',
                              value:
                                  '${sunsetTime.hour.toString().padLeft(2, '0')}:${sunsetTime.minute.toString().padLeft(2, '0')}',
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getWindDirection(int degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return '${directions[index]} ($degrees°)';
  }

  Color _getUVColor(double uv) {
    if (uv <= 2) return Colors.green;
    if (uv <= 5) return Colors.yellow;
    if (uv <= 7) return Colors.orange;
    if (uv <= 10) return Colors.red;
    return Colors.purple;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Day Name
            SizedBox(
              width: 70,
              child: Text(
                forecast.dayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Weather Icon
            Text(
              forecast.weatherIcon,
              style: const TextStyle(fontSize: 30),
            ),

            const SizedBox(width: 12),

            // Precipitation (if any)
            if (forecast.precipitationProbability > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.water_drop,
                      color: Color(0xFF42A5F5),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${forecast.precipitationProbability}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Tap indicator
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.4),
              size: 20,
            ),

            const SizedBox(width: 8),

            // Temperature Range
            Row(
              children: [
                // Min temp
                Text(
                  '${forecast.minTemp.round()}°',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF42A5F5),
                        Color(0xFFEF5350),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                // Max temp
                Text(
                  '${forecast.maxTemp.round()}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
