# Weather App - Flutter

A professional weather application built with Flutter that uses the Open-Meteo API to fetch current weather conditions and 7-day forecasts.

## Features

✅ **Current Weather Display**
- Real-time temperature, humidity, wind speed, and pressure
- Weather condition icons and descriptions
- "Feels like" temperature calculation

✅ **7-Day Weather Forecast**
- Daily high/low temperatures
- Weather conditions for each day
- Precipitation probability

✅ **Sunrise & Sunset Visualization**
- Beautiful circular arc showing sun position
- Animated sun that travels like a clock
- Sunrise and sunset times

✅ **Location Services**
- Get weather for current location
- Search weather by city name
- Location permission handling

✅ **Professional UI**
- Gradient background
- Glass-morphism effects
- Status bar with live weather info
- Pull-to-refresh functionality

## Screenshots

```
[Status Bar] ☀️ 18° London                    🕐 2:30 PM
┌─────────────────────────────────────────────────┐
│                  Search City                    │
├─────────────────────────────────────────────────┤
│              London, GB                         │
│                   ☀️                            │
│                  18°C                           │
│               Clear Sky                         │
│            Feels like 16°C                      │
├─────────────────────────────────────────────────┤
│         🌅 Sunrise & Sunset                     │
│                                                 │
│              ━━━━━☀━━━━━                       │
│         🌅 6:30 AM    🌇 8:00 PM                │
├─────────────────────────────────────────────────┤
│  💨 Wind      💧 Humidity                       │
│  15 km/h      72%                               │
│  🌡️ Pressure  ☁️ Cloud                         │
│  1012 hPa     30%                               │
├─────────────────────────────────────────────────┤
│            7-Day Forecast                       │
│ Today    ☀️  💧 10%      12° / 20°             │
│ Tomorrow 🌤️  💧 20%      14° / 22°             │
│ Wed      ⛅  💧 40%      13° / 19°             │
│ ...                                             │
└─────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- A physical device or emulator

### Setup Steps

1. **Clone or download this project**

2. **Navigate to project directory**
   ```bash
   cd flutter_weather_app
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
flutter_weather_app/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── weather_model.dart    # Weather data models
│   ├── services/
│   │   └── weather_service.dart  # API service layer
│   ├── providers/
│   │   └── weather_provider.dart # State management
│   ├── screens/
│   │   └── home_screen.dart      # Main screen
│   └── widgets/
│       ├── weather_card.dart     # Current weather display
│       ├── forecast_card.dart    # Daily forecast item
│       ├── sun_arc_widget.dart   # Sunrise/sunset animation
│       └── weather_details.dart  # Additional weather info
├── android/
│   └── app/src/main/AndroidManifest.xml
├── ios/
│   └── Runner/Info.plist
└── pubspec.yaml
```

## API Information

This app uses the **Open-Meteo API** which is:
- ✅ Free to use
- ✅ No API key required
- ✅ No registration needed
- ✅ Reliable and accurate

**API Endpoints Used:**
- Weather Forecast: `https://api.open-meteo.com/v1/forecast`
- Geocoding: `https://geocoding-api.open-meteo.com/v1/search`

## Dependencies

```yaml
http: ^1.1.0              # HTTP requests
provider: ^6.1.1          # State management
geolocator: ^10.1.0       # Location services
geocoding: ^2.1.1         # Reverse geocoding
permission_handler: ^11.0.1  # Permission handling
intl: ^0.18.1             # Date formatting
flutter_svg: ^2.0.9       # SVG support
```

## Permissions

### Android
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS
Add to `Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to show weather data.</string>
```

## Features Explained

### 1. Status Bar
- Always visible at the top
- Shows current weather icon, temperature, and location
- Displays live clock

### 2. Sunrise/Sunset Arc
- Circular arc visualization
- Sun icon moves along the arc based on current time
- Changes from 🌅 (sunrise) → ☀️ (day) → 🌇 (sunset) → 🌙 (night)
- Shows exact sunrise and sunset times

### 3. Weather Details
- Wind speed in km/h
- Humidity percentage
- Atmospheric pressure in hPa
- Cloud cover percentage

### 4. 7-Day Forecast
- Daily high and low temperatures
- Weather condition icons
- Precipitation probability
- Easy-to-read format

## Usage

1. **First Launch**: The app will request location permission
2. **Grant Permission**: Allow location access for automatic weather detection
3. **Search City**: Use the search bar to find weather for any city
4. **Refresh**: Pull down to refresh weather data
5. **Current Location**: Tap the location icon to get weather for your current position

## Customization

### Change Temperature Unit
In `weather_card.dart` and `forecast_card.dart`, modify:
```dart
'${current.temperature.round()}°C'  // Change to °F if needed
```

### Modify Colors
In `home_screen.dart`, change gradient colors:
```dart
colors: [
  Color(0xFF667eea),  // Top color
  Color(0xFF764ba2),  // Bottom color
],
```

### Add More Weather Details
Extend `weather_service.dart` to fetch additional parameters:
```dart
'&current=temperature_2m,uv_index,visibility'
```

## Troubleshooting

### Location Permission Denied
- Go to device Settings → Apps → Weather App → Permissions
- Enable Location permission

### No Internet Connection
- Check device internet connection
- Verify API is accessible

### City Not Found
- Check spelling
- Try using full city name
- Use major city names

## Future Enhancements

- [ ] Hourly forecast
- [ ] Weather alerts
- [ ] Multiple locations
- [ ] Weather maps
- [ ] Dark/Light theme toggle
- [ ] Widget support
- [ ] Offline caching

## License

This project is open source and available for personal and commercial use.

## Credits

- Weather Data: [Open-Meteo API](https://open-meteo.com/)
- Flutter Framework: [Flutter.dev](https://flutter.dev/)

## Support

For issues or questions, please open an issue on GitHub.

---

**Built with ❤️ using Flutter and Open-Meteo API**
