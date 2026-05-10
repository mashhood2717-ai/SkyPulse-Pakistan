import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WeatherLottieIcon extends StatelessWidget {
  final int weatherCode;
  final bool isDay;
  final double size;
  final String? customDescription;

  const WeatherLottieIcon({
    Key? key,
    required this.weatherCode,
    this.isDay = true,
    this.size = 80,
    this.customDescription,
  }) : super(key: key);

  /// Get Lottie animation URL based on weather condition
  String _getLottieUrl() {
    // Handle custom METAR conditions
    if (customDescription != null && customDescription!.isNotEmpty) {
      final desc = customDescription!.toUpperCase();
      if (desc.contains('HAZE') || desc.contains('SMOKE')) {
        return 'https://lottie.host/3e7c58f8-2a67-406c-8e7a-87c89d7f89b3/6FQhVhLbYT.json'; // Haze
      }
      if (desc.contains('FOG') || desc.contains('MIST')) {
        return 'https://lottie.host/8e94b8f4-8c36-4f32-baeb-ecce90f05a5d/wD5Gqd5rXZ.json'; // Fog
      }
      if (desc.contains('DUST') || desc.contains('SAND') || desc.contains('TORNADO')) {
        return 'https://lottie.host/ee3f3e8f-a8b6-4bac-9d5e-3e5b7e8e8e8e/JHG5hkL8mN.json'; // Dust storm
      }
    }

    switch (weatherCode) {
      case 0:
        // Clear sky
        return isDay
            ? 'https://lottie.host/62abb272-ea79-4a63-8e5e-51e99beb2032/gFlHKT7WHy.json' // Sunny
            : 'https://lottie.host/8ac6d21b-13ba-42d8-b8e3-7bd373a91ba3/RcWqYmV5FY.json'; // Clear night
      case 1:
        // Mainly clear
        return isDay
            ? 'https://lottie.host/62abb272-ea79-4a63-8e5e-51e99beb2032/gFlHKT7WHy.json' // Sunny
            : 'https://lottie.host/8ac6d21b-13ba-42d8-b8e3-7bd373a91ba3/RcWqYmV5FY.json'; // Clear night
      case 2:
        // Partly cloudy
        return isDay
            ? 'https://lottie.host/8e4c4b9c-ec54-4e6e-9f8a-8e8e8e8e8e8e/P6L9sM2kN3.json' // Partly cloudy day
            : 'https://lottie.host/9f5d5c0d-fd65-4f7f-0g9g-9f9f9f9f9f9f/Q7M0tN3lO4.json'; // Partly cloudy night
      case 3:
        // Overcast
        return 'https://lottie.host/4e5b5c6d-6e75-4e8e-1h1h-1e1e1e1e1e1e/R8N1uO4mP5.json'; // Cloudy
      case 45:
      case 48:
        // Foggy
        return 'https://lottie.host/8e94b8f4-8c36-4f32-baeb-ecce90f05a5d/wD5Gqd5rXZ.json'; // Fog
      case 51:
      case 53:
      case 55:
        // Drizzle
        return 'https://lottie.host/05d26a93-b0c1-43d5-9a15-b80282ca80f6/JUb8Bic2FK.json'; // Light rain
      case 61:
      case 63:
      case 65:
        // Rain
        return 'https://lottie.host/2c56c93b-2eeb-4f8f-b8e8-f2cc2b8b8f8f/K2L5kJ3hI6.json'; // Heavy rain
      case 71:
      case 73:
      case 75:
        // Snow
        return 'https://lottie.host/96f89e31-9066-4b42-9f2c-4c9f9f9f9f9f/L3M6lK4iJ7.json'; // Snowing
      case 77:
        // Snow grains
        return 'https://lottie.host/96f89e31-9066-4b42-9f2c-4c9f9f9f9f9f/L3M6lK4iJ7.json'; // Snowing
      case 80:
      case 81:
      case 82:
        // Rain showers
        return 'https://lottie.host/2c56c93b-2eeb-4f8f-b8e8-f2cc2b8b8f8f/K2L5kJ3hI6.json'; // Rain
      case 85:
      case 86:
        // Snow showers
        return 'https://lottie.host/96f89e31-9066-4b42-9f2c-4c9f9f9f9f9f/L3M6lK4iJ7.json'; // Snow
      case 95:
      case 96:
      case 99:
        // Thunderstorm
        return 'https://lottie.host/c1f2a1a8-a2c0-44d6-8f9f-3f3f3f3f3f3f/M4N7mL5jK8.json'; // Thunderstorm
      default:
        // Unknown - default to cloudy
        return 'https://lottie.host/4e5b5c6d-6e75-4e8e-1h1h-1e1e1e1e1e1e/R8N1uO4mP5.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.network(
        _getLottieUrl(),
        fit: BoxFit.contain,
        repeat: true,
        reverse: false,
        animate: true,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to emoji if lottie fails
          String fallbackEmoji = _getFallbackEmoji();
          return Center(
            child: Text(
              fallbackEmoji,
              style: TextStyle(fontSize: size * 0.8),
            ),
          );
        },
      ),
    );
  }

  /// Fallback emoji if lottie animation fails to load
  String _getFallbackEmoji() {
    if (customDescription != null && customDescription!.isNotEmpty) {
      final desc = customDescription!.toUpperCase();
      if (desc.contains('HAZE')) return '🌫️';
      if (desc.contains('SMOKE')) return '💨';
      if (desc.contains('DUST') || desc.contains('SAND')) return '🌪️';
    }

    switch (weatherCode) {
      case 0:
        return isDay ? '☀️' : '🌙';
      case 1:
        return isDay ? '🌤️' : '🌟';
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
        return isDay ? '🌤️' : '🌟';
    }
  }
}
