import 'package:flutter/material.dart';
import '../models/weather_model.dart';

class WeatherCard extends StatelessWidget {
  final String cityName;
  final String countryCode;
  final CurrentWeather current;

  const WeatherCard({
    Key? key,
    required this.cityName,
    required this.countryCode,
    required this.current,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Text(
            current.weatherIcon,
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(width: 12),

          // Center: City & Temp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // City
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cityName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (countryCode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          countryCode,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                // Temp & Description
                Text(
                  '${current.temperature.round()}° • ${current.weatherDescription}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Feels like
                Text(
                  'Feels ${current.feelsLike.round()}°C',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right: Quick stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.opacity, size: 11, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text('${current.humidity.round()}%',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.air, size: 11, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text('${current.windSpeed.round()} km/h',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.compress, size: 11, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text('${current.pressure.round()}hPa',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
