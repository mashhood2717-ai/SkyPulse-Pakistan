# Quick Setup Guide - Flutter Weather App

## 🚀 Quick Start (5 minutes)

### Step 1: Install Flutter
```bash
# Download Flutter SDK from https://flutter.dev/docs/get-started/install
# Add Flutter to your PATH
```

### Step 2: Setup Project
```bash
# Navigate to project folder
cd flutter_weather_app

# Get dependencies
flutter pub get

# Check if Flutter is ready
flutter doctor
```

### Step 3: Run the App
```bash
# Connect your device or start emulator

# Run the app
flutter run
```

That's it! The app should now be running on your device.

## 📱 First Time Usage

1. **Allow Location Permission**: When prompted, allow location access
2. **Wait for Weather**: The app will automatically fetch weather for your location
3. **Search Cities**: Use the search bar to find weather for any city worldwide
4. **Pull to Refresh**: Swipe down to refresh weather data

## ✨ Key Features

### Status Bar Weather
- Always visible at the top
- Shows current temperature and location
- Updates in real-time

### Circular Sunrise/Sunset Animation
- Beautiful arc showing sun's path
- Sun moves like a clock throughout the day
- Shows exact sunrise and sunset times

### 7-Day Forecast
- Daily high and low temperatures
- Weather conditions with icons
- Precipitation probability

### Weather Details
- Wind speed
- Humidity
- Atmospheric pressure
- Cloud cover

## 🔧 No API Key Required!

This app uses the **Open-Meteo API** which:
- ✅ Is completely free
- ✅ Requires no registration
- ✅ Needs no API key
- ✅ Works out of the box

## 📂 Project Files

```
flutter_weather_app/
├── lib/
│   ├── main.dart              # Start here
│   ├── models/
│   │   └── weather_model.dart # Data models
│   ├── services/
│   │   └── weather_service.dart # API calls
│   ├── providers/
│   │   └── weather_provider.dart # State management
│   ├── screens/
│   │   └── home_screen.dart   # Main UI
│   └── widgets/
│       ├── weather_card.dart
│       ├── forecast_card.dart
│       ├── sun_arc_widget.dart # ⭐ Circular animation
│       └── weather_details.dart
├── android/               # Android config
├── ios/                  # iOS config
└── pubspec.yaml          # Dependencies
```

## 🎨 Customization Examples

### Change Colors
Edit `lib/screens/home_screen.dart`:
```dart
gradient: LinearGradient(
  colors: [
    Color(0xFF667eea),  // Change this
    Color(0xFF764ba2),  // And this
  ],
)
```

### Add More Weather Data
Edit `lib/services/weather_service.dart`:
```dart
'&current=temperature_2m,uv_index,visibility'
// Add any Open-Meteo parameter
```

## 🐛 Troubleshooting

### "Location Permission Denied"
**Solution**: 
- Android: Settings → Apps → Weather App → Permissions → Location
- iOS: Settings → Privacy → Location Services → Weather App

### "City Not Found"
**Solution**: 
- Try full city name (e.g., "New York" instead of "NY")
- Use major cities for better results

### "Failed to Load Weather"
**Solution**:
- Check internet connection
- Verify Open-Meteo API is accessible
- Try refreshing the app

## 📱 Supported Platforms

- ✅ Android (API 21+)
- ✅ iOS (11.0+)
- ✅ Web (coming soon)
- ✅ Desktop (coming soon)

## 🌍 Tested Cities

Works worldwide! Try these:
- London, UK
- New York, USA
- Tokyo, Japan
- Paris, France
- Sydney, Australia
- Dubai, UAE
- Mumbai, India
- Moscow, Russia

## 🔄 Update Weather Data

Three ways to refresh:
1. **Pull Down**: Swipe down on the main screen
2. **Location Button**: Tap the location icon in the status bar
3. **Search**: Enter a city name and press search

## 💡 Tips

1. **Battery Saving**: The app only requests location when needed
2. **Offline Mode**: Last weather data is displayed even without internet
3. **Fast Search**: Recent cities are prioritized in search results
4. **Accurate Location**: Use GPS for most accurate weather data

## 📞 Need Help?

Check the full README.md for:
- Detailed API documentation
- Complete feature list
- Advanced customization
- Contributing guidelines

---

**Enjoy your weather app! ☀️🌧️⛈️❄️**
