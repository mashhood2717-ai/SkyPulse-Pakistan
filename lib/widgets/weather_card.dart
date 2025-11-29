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

  double get feelsLike {
    return current.temperature -
        ((current.windSpeed / 10) * 2) -
        ((100 - current.humidity) / 20);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: EdgeInsets.all(12),
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
            style: TextStyle(fontSize: 36),
          ),
          SizedBox(width: 12),

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
                        style: TextStyle(
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
                        padding: EdgeInsets.only(left: 6),
                        child: Text(
                          countryCode,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2),
                // Temp & Description
                Text(
                  '${current.temperature.round()}° • ${current.weatherDescription}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                // Feels like
                Text(
                  'Feels ${feelsLike.round()}°C',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),

          // Right: Quick stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.opacity, size: 11, color: Colors.white70),
                  SizedBox(width: 3),
                  Text('${current.humidity.round()}%',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
              SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.air, size: 11, color: Colors.white70),
                  SizedBox(width: 3),
                  Text('${current.windSpeed.round()} km/h',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
              SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compress, size: 11, color: Colors.white70),
                  SizedBox(width: 3),
                  Text('${current.pressure.round()}hPa',
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
