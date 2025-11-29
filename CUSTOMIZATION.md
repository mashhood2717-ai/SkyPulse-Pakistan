# Customization Examples

## 🎨 Common Customizations

### 1. Change App Colors

**Gradient Background**
```dart
// In lib/screens/home_screen.dart

Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF667eea),  // Change to your color
        Color(0xFF764ba2),  // Change to your color
      ],
    ),
  ),
)

// Example color schemes:

// Sunset
colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)]

// Ocean
colors: [Color(0xFF00B4DB), Color(0xFF0083B0)]

// Forest
colors: [Color(0xFF134E5E), Color(0xFF71B280)]

// Night
colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)]
```

### 2. Temperature Units

**Celsius to Fahrenheit**
```dart
// Create a helper function in lib/models/weather_model.dart

class CurrentWeather {
  // ... existing code ...
  
  double get temperatureF {
    return (temperature * 9/5) + 32;
  }
  
  String getTemperatureString(bool useFahrenheit) {
    if (useFahrenheit) {
      return '${temperatureF.round()}°F';
    }
    return '${temperature.round()}°C';
  }
}

// Usage in widgets:
Text('${current.getTemperatureString(true)}')  // For Fahrenheit
```

### 3. Add UV Index

**Step 1: Update Service**
```dart
// In lib/services/weather_service.dart

Future<WeatherData> getWeatherByCoordinates(double latitude, double longitude) async {
  final url = Uri.parse(
    '$baseUrl?latitude=$latitude&longitude=$longitude'
    '&current=temperature_2m,relative_humidity_2m,weather_code,uv_index'  // Add uv_index
    '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max'  // Add to daily
  );
  // ... rest of the code
}
```

**Step 2: Update Model**
```dart
// In lib/models/weather_model.dart

class CurrentWeather {
  final double uvIndex;
  
  CurrentWeather({
    // ... existing fields
    required this.uvIndex,
  });
  
  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      // ... existing fields
      uvIndex: json['uv_index']?.toDouble() ?? 0.0,
    );
  }
  
  String get uvIndexCategory {
    if (uvIndex <= 2) return 'Low';
    if (uvIndex <= 5) return 'Moderate';
    if (uvIndex <= 7) return 'High';
    if (uvIndex <= 10) return 'Very High';
    return 'Extreme';
  }
}
```

**Step 3: Display in UI**
```dart
// Add to lib/widgets/weather_details.dart

_buildDetailCard(
  icon: '☀️',
  label: 'UV Index',
  value: '${current.uvIndex.round()} ${current.uvIndexCategory}',
)
```

### 4. Add Hourly Forecast

**Step 1: Update Model**
```dart
// Add to lib/models/weather_model.dart

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  
  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });
  
  factory HourlyForecast.fromJson(Map<String, dynamic> json, int index) {
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(json['time'][index] * 1000),
      temperature: json['temperature_2m'][index]?.toDouble() ?? 0.0,
      weatherCode: json['weather_code'][index] ?? 0,
    );
  }
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyForecast> forecast;
  final List<HourlyForecast> hourly;  // Add this
  
  // Update factory method
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      current: CurrentWeather.fromJson(json['current']),
      forecast: // ... existing code
      hourly: (json['hourly']['time'] as List)
          .asMap()
          .entries
          .map((entry) => HourlyForecast.fromJson(json['hourly'], entry.key))
          .toList(),
    );
  }
}
```

**Step 2: Create Widget**
```dart
// Create lib/widgets/hourly_forecast_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_model.dart';

class HourlyForecastWidget extends StatelessWidget {
  final List<HourlyForecast> hourly;

  const HourlyForecastWidget({Key? key, required this.hourly}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show next 24 hours
    final next24Hours = hourly.take(24).toList();
    
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: next24Hours.length,
        itemBuilder: (context, index) {
          final hour = next24Hours[index];
          return Container(
            width: 70,
            margin: EdgeInsets.only(right: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.Hm().format(hour.time),
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 8),
                Text(
                  getWeatherIcon(hour.weatherCode),
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 8),
                Text(
                  '${hour.temperature.round()}°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  String getWeatherIcon(int code) {
    // Copy from weather_model.dart
    if (code == 0) return '☀️';
    // ... etc
    return '🌤️';
  }
}
```

### 5. Custom Weather Icons (Instead of Emoji)

**Using Flutter Icons**
```dart
// Create lib/utils/weather_icons.dart

import 'package:flutter/material.dart';

class WeatherIcons {
  static IconData getIcon(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
        return Icons.wb_cloudy;
      case 3:
        return Icons.cloud;
      case 61:
      case 63:
      case 65:
        return Icons.umbrella;
      case 71:
      case 73:
      case 75:
        return Icons.ac_unit;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on;
      default:
        return Icons.wb_sunny;
    }
  }
  
  static Color getColor(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return Colors.orange;
      case 61:
      case 63:
      case 65:
        return Colors.blue;
      case 71:
      case 73:
      case 75:
        return Colors.lightBlue;
      case 95:
      case 96:
      case 99:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Usage in weather_card.dart:
Icon(
  WeatherIcons.getIcon(current.weatherCode),
  size: 80,
  color: WeatherIcons.getColor(current.weatherCode),
)
```

### 6. Add Animations

**Fade-in Animation**
```dart
// Wrap your weather card in home_screen.dart

AnimatedOpacity(
  opacity: provider.isLoading ? 0.0 : 1.0,
  duration: Duration(milliseconds: 500),
  child: WeatherCard(/* ... */),
)
```

**Slide Animation**
```dart
class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _controller.forward();
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: WeatherCard(/* ... */),
    );
  }
}
```

### 7. Dark/Light Theme Toggle

**Add Theme Provider**
```dart
// Create lib/providers/theme_provider.dart

import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
  
  LinearGradient get backgroundGradient {
    if (_isDarkMode) {
      return LinearGradient(
        colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
      );
    }
    return LinearGradient(
      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
    );
  }
}

// In main.dart:
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => WeatherProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
  ],
  child: MyApp(),
)

// Add toggle button in home_screen.dart:
IconButton(
  icon: Icon(Icons.brightness_6),
  onPressed: () {
    context.read<ThemeProvider>().toggleTheme();
  },
)
```

### 8. Save Favorite Locations

**Using SharedPreferences**
```dart
// Add to pubspec.yaml:
// shared_preferences: ^2.2.0

// Create lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _favoritesKey = 'favorite_locations';
  
  Future<void> saveFavorite(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    if (!favorites.contains(cityName)) {
      favorites.add(cityName);
      await prefs.setString(_favoritesKey, json.encode(favorites));
    }
  }
  
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);
    if (favoritesJson == null) return [];
    return List<String>.from(json.decode(favoritesJson));
  }
  
  Future<void> removeFavorite(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.remove(cityName);
    await prefs.setString(_favoritesKey, json.encode(favorites));
  }
}
```

### 9. Add Weather Alerts

**Display Warnings**
```dart
// Add to lib/widgets/weather_alert.dart

import 'package:flutter/material.dart';

class WeatherAlert extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  
  const WeatherAlert({
    Key? key,
    required this.message,
    this.icon = Icons.warning,
    this.color = Colors.orange,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Usage: Show alerts based on conditions
if (current.temperature > 35) {
  WeatherAlert(
    message: 'High temperature warning! Stay hydrated.',
    icon: Icons.thermostat,
    color: Colors.red,
  )
}

if (current.windSpeed > 50) {
  WeatherAlert(
    message: 'Strong wind warning! Take caution outdoors.',
    icon: Icons.air,
    color: Colors.orange,
  )
}
```

### 10. Add Loading Skeleton

**Shimmer Effect**
```dart
// Add shimmer: ^3.0.0 to pubspec.yaml

import 'package:shimmer/shimmer.dart';

Widget _buildLoadingSkeleton() {
  return Shimmer.fromColors(
    baseColor: Colors.white.withOpacity(0.2),
    highlightColor: Colors.white.withOpacity(0.4),
    child: Column(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        SizedBox(height: 20),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    ),
  );
}

// Use in home_screen.dart:
if (provider.isLoading) {
  return _buildLoadingSkeleton();
}
```

---

## 🎯 Quick Tips

1. **Always rebuild UI**: After model changes, call `notifyListeners()`
2. **Test on device**: Emulators may not support location well
3. **Handle errors**: Always wrap API calls in try-catch
4. **Cache data**: Store last weather data for offline viewing
5. **Optimize images**: Use SVG for icons instead of PNG

## 📚 Resources

- [Open-Meteo API Docs](https://open-meteo.com/en/docs)
- [Flutter Documentation](https://flutter.dev/docs)
- [Provider Package](https://pub.dev/packages/provider)
- [Material Icons](https://fonts.google.com/icons)

---

**Happy Customizing! 🎨**
