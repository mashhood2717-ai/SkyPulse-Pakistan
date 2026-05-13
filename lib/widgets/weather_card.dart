import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather_model.dart';
import '../providers/settings_provider.dart';
import 'weather_lottie_icon.dart';

class WeatherCard extends StatelessWidget {
  final String cityName;
  final String countryCode;
  final CurrentWeather current;
  final double? dailyHigh;
  final double? dailyLow;

  const WeatherCard({
    Key? key,
    required this.cityName,
    required this.countryCode,
    required this.current,
    this.dailyHigh,
    this.dailyLow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 340;
            final tempSize = compact ? 66.0 : 78.0;
            final iconSize = compact ? 82.0 : 96.0;
            final citySize = compact ? 22.0 : 26.0;
            final hasRange = dailyHigh != null && dailyLow != null;
            final feelsText = hasRange
                ? 'Feels like ${settings.getTempString(current.feelsLike)} - High ${settings.getTempString(dailyHigh!)} / Low ${settings.getTempString(dailyLow!)}'
                : 'Feels like ${settings.getTempString(current.feelsLike)}';

            return ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 286),
                  padding: EdgeInsets.all(compact ? 18 : 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: current.isDay
                          ? [
                              Colors.white.withOpacity(0.24),
                              const Color(0xFF4DA3FF).withOpacity(0.20),
                              const Color(0xFF12233A).withOpacity(0.22),
                            ]
                          : [
                              Colors.white.withOpacity(0.16),
                              const Color(0xFF4857B8).withOpacity(0.22),
                              const Color(0xFF080B1A).withOpacity(0.34),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.20),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cityName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: citySize,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  countryCode.isNotEmpty
                                      ? 'Current weather - $countryCode'
                                      : 'Current weather',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: Center(
                              child: WeatherLottieIcon(
                                weatherCode: current.weatherCode,
                                isDay: current.isDay,
                                size: iconSize * 0.78,
                                customDescription: current.customDescription,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 20 : 24),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            settings.getTempString(current.temperature),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tempSize,
                              fontWeight: FontWeight.w800,
                              height: 0.88,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              current.weatherDescription,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.96),
                                fontSize: compact ? 17 : 19,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        feelsText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickStat(
                              icon: Icons.air_rounded,
                              label: 'Wind',
                              value: settings.getWindSpeedString(
                                current.windSpeed,
                              ),
                              color: const Color(0xFF79C7FF),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _QuickStat(
                              icon: Icons.water_drop_rounded,
                              label: 'Humidity',
                              value: '${current.humidity.round()}%',
                              color: const Color(0xFF76E4B1),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _QuickStat(
                              icon: Icons.compress_rounded,
                              label: 'Pressure',
                              value: '${current.pressure.round()} hPa',
                              color: const Color(0xFFFFD166),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
