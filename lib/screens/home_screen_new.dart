import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/weather_background_animation.dart';

class HomeScreenNew extends StatelessWidget {
  const HomeScreenNew({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, _) {
        if (weatherProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (weatherProvider.weatherData == null) {
          return Scaffold(
            body: Center(
              child: Text('No weather data available'),
            ),
          );
        }

        final weather = weatherProvider.weatherData!;
        final isDark = context.watch<ThemeProvider>().isDarkMode;

        // Determine weather condition for animation
        final currentWeatherCode = weather.current.weatherCode;
        String weatherCondition = 'sunny';
        if (currentWeatherCode == 0 || currentWeatherCode == 1) {
          weatherCondition = 'sunny';
        } else if (currentWeatherCode == 2 || currentWeatherCode == 3) {
          weatherCondition = 'cloudy';
        } else if (currentWeatherCode >= 51 && currentWeatherCode <= 82) {
          weatherCondition = 'rainy';
        } else if (currentWeatherCode >= 71 && currentWeatherCode <= 86) {
          weatherCondition = 'snowy';
        }

        return Scaffold(
          body: WeatherBackgroundAnimation(
            weatherCondition: weatherCondition,
            isDarkMode: isDark,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Status bar spacing
                  SizedBox(height: 16),

                  // Header with location and settings
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weatherProvider.cityName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            Text(
                              'Today',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.dark_mode : Icons.light_mode,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onPressed: () {
                            context.read<ThemeProvider>().toggleTheme();
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Large temperature display
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${weather.current.temperature.toInt()}°',
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w200,
                            color: isDark ? Colors.white : Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          weather.current.weatherDescription,
                          style: TextStyle(
                            fontSize: 18,
                            color: isDark ? Colors.white70 : Colors.white70,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'H: ${weather.forecast.isNotEmpty ? weather.forecast[0].maxTemp.toInt() : '--'}° L: ${weather.forecast.isNotEmpty ? weather.forecast[0].minTemp.toInt() : '--'}°',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white54 : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 40),

                  // Hourly forecast (12-hour)
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Text(
                            'Hourly Forecast',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(
                              weather.hourlyTemperatures.length < 12
                                  ? weather.hourlyTemperatures.length
                                  : 12,
                              (index) {
                                final temp = weather.hourlyTemperatures[index];
                                final code =
                                    index < weather.hourlyWeatherCodes.length
                                        ? weather.hourlyWeatherCodes[index]
                                        : 0;
                                final time = index < weather.hourlyTimes.length
                                    ? weather.hourlyTimes[index]
                                    : '';

                                // Extract hour from time string (e.g., "2025-12-02T14:00" -> "14:00")
                                String hourStr = '—';
                                if (time.isNotEmpty && time.contains('T')) {
                                  hourStr = time.split('T')[1].substring(0, 5);
                                }

                                return Padding(
                                  padding: EdgeInsets.only(right: 16),
                                  child: Column(
                                    children: [
                                      Text(
                                        hourStr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      _getWeatherIcon(code),
                                      SizedBox(height: 8),
                                      Text(
                                        '${temp.toInt()}°',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Daily forecast (10 days)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '10-Day Forecast',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        SizedBox(height: 12),
                        ...List.generate(
                          weather.forecast.length < 10
                              ? weather.forecast.length
                              : 10,
                          (index) {
                            final day = weather.forecast[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      day.dayName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    day.weatherIcon,
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value:
                                              (day.maxTemp - day.minTemp) / 40,
                                          minHeight: 4,
                                          backgroundColor: isDark
                                              ? Colors.white12
                                              : Colors.white24,
                                          valueColor: AlwaysStoppedAnimation(
                                            _getTempColor(day.maxTemp),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '${day.maxTemp.toInt()}° ${day.minTemp.toInt()}°',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // Weather details grid (6 items)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weather Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            _DetailCard(
                              title: 'Feels Like',
                              value:
                                  '${(weather.current.temperature - 3).toInt()}°',
                              icon: Icons.thermostat,
                              isDark: isDark,
                            ),
                            _DetailCard(
                              title: 'Humidity',
                              value: '${weather.current.humidity}%',
                              icon: Icons.water_drop,
                              isDark: isDark,
                            ),
                            _DetailCard(
                              title: 'Wind Speed',
                              value:
                                  '${weather.current.windSpeed.toInt()} km/h',
                              icon: Icons.air,
                              isDark: isDark,
                            ),
                            _DetailCard(
                              title: 'UV Index',
                              value: weather.current.uvIndex.toStringAsFixed(1),
                              icon: Icons.sunny,
                              isDark: isDark,
                            ),
                            _DetailCard(
                              title: 'Pressure',
                              value: '${weather.current.pressure.toInt()} hPa',
                              icon: Icons.compress,
                              isDark: isDark,
                            ),
                            _DetailCard(
                              title: 'Visibility',
                              value: '${weather.current.visibility.toInt()} km',
                              icon: Icons.visibility,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _getWeatherIcon(int code) {
    switch (code) {
      case 0:
        return Text('☀️', style: TextStyle(fontSize: 24));
      case 1:
        return Text('🌤️', style: TextStyle(fontSize: 24));
      case 2:
        return Text('⛅', style: TextStyle(fontSize: 24));
      case 3:
        return Text('☁️', style: TextStyle(fontSize: 24));
      case 45:
      case 48:
        return Text('🌫️', style: TextStyle(fontSize: 24));
      case 51:
      case 53:
      case 55:
        return Text('🌦️', style: TextStyle(fontSize: 24));
      case 61:
      case 63:
      case 65:
        return Text('🌧️', style: TextStyle(fontSize: 24));
      case 71:
      case 73:
      case 75:
        return Text('❄️', style: TextStyle(fontSize: 24));
      case 77:
        return Text('🌨️', style: TextStyle(fontSize: 24));
      case 80:
      case 81:
      case 82:
        return Text('🌧️', style: TextStyle(fontSize: 24));
      case 85:
      case 86:
        return Text('🌨️', style: TextStyle(fontSize: 24));
      case 95:
        return Text('⛈️', style: TextStyle(fontSize: 24));
      case 96:
      case 99:
        return Text('⛈️', style: TextStyle(fontSize: 24));
      default:
        return Text('🌤️', style: TextStyle(fontSize: 24));
    }
  }

  Color _getTempColor(double temp) {
    if (temp <= 0) return Colors.blue;
    if (temp <= 15) return Colors.cyan;
    if (temp <= 25) return Colors.green;
    if (temp <= 35) return Colors.orange;
    return Colors.red;
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isDark;

  const _DetailCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.white,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
