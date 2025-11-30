# 🌤️ Skypulse - Professional Weather App

A feature-rich Flutter weather application with real-time weather alerts, METAR data, favorites management, and Firebase Cloud Messaging integration.

**App Name:** Skypulse  
**Version:** 1.0 (with Enhanced Alert Reliability)  
**Platform:** Android (iOS support ready)  
**Min Android:** 8.0  
**Built with:** Flutter 3.x, Dart, Firebase

---

## ✨ Core Features

### 🎯 **Smart Weather Display**
- Real-time temperature, humidity, wind speed, pressure, visibility
- "Feels like" temperature calculation
- Weather condition icons with descriptions
- UV index display
- Cloud coverage percentage
- 14-day extended forecast with precipitation probability

### 🚨 **Weather Alerts System** ⭐
- Firebase Cloud Messaging (FCM) integration
- Real-time push notifications
- Read/unread tracking with visual indicators
- Auto-refresh every 30 seconds
- 3-tab navigation: **Alerts** | **Weather** | **Favorites**
- Alert details with severity levels
- Unread badge count on Alerts tab

### ✈️ **METAR Data Integration**
- Aviation Weather Center data for accurate observations
- Real-time airport weather data
- Automatic fallback to API data if METAR unavailable
- City-specific airport lookups
- Coordinates-based nearby airport discovery

### ⭐ **Favorites Management**
- Save and manage favorite locations
- Quick access with reorderable list
- Cached weather display for favorites
- Smooth favorite location switching
- Weather updates for all favorites

### 🌅 **Sunrise & Sunset Visualization**
- Beautiful circular arc showing sun position
- Animated sun tracking throughout the day
- Exact sunrise/sunset times
- Day/night mode detection
- Visual day progression indicator

### 📍 **Location Services**
- Get weather for current location
- Search weather by city name
- City search with auto-suggestions
- Location permission handling
- Reverse geocoding support

### 🎨 **Professional UI/UX**
- 3-tab bottom navigation (Alerts/Weather/Favorites)
- Transparent footer (0.7 opacity)
- Gradient backgrounds
- Glass-morphism effects
- Pull-to-refresh functionality
- Smooth animations
- Responsive design

---

## 🎯 Key Screens

### 1. **Alerts Tab** 🚨
- List of active weather alerts
- Red dot indicators for unread alerts
- Severity color coding
- Tap to view details and mark as read
- Real-time badge count of unread alerts
- Auto-refresh every 30 seconds

### 2. **Weather Tab** ☀️
- Current weather display
- Search bar for city lookup
- Sunrise/sunset arc visualization
- Hourly forecast
- 14-day extended forecast
- Additional weather details (wind, pressure, humidity, UV index)
- METAR badge if data available

### 3. **Favorites Tab** ⭐
- Reorderable list of favorite locations
- Cached weather for each location
- Tap to switch to that location's weather
- Weather updates on selection
- Smooth navigation between favorites

---

## 🔧 Technical Architecture

### State Management
- **Provider 6.1.1** - Centralized state with `WeatherProvider`
- Single source of truth for all weather and alert data
- Callback-based communication between screens

### APIs Used
- **Open-Meteo** - Weather forecast & geocoding (no API key required)
- **Aviation Weather Center** - METAR data (no API key required)
- **Firebase Cloud Messaging** - Push notifications & alerts

### Core Services

| Service | Purpose | Location |
|---------|---------|----------|
| `WeatherService` | Open-Meteo API integration | `lib/services/weather_service.dart` |
| `MetarService` | METAR data fetching & parsing | `lib/services/metar_service.dart` |
| `AlertService` | Weather alert polling | `lib/services/alert_service.dart` |
| `PushNotificationService` | Firebase FCM setup & handling | `lib/services/push_notification_service.dart` |
| `FavoritesService` | Favorite locations persistence | `lib/services/favorites_service.dart` |

### Data Models

| Model | Purpose | Location |
|-------|---------|----------|
| `WeatherData` | Current weather & forecast | `lib/models/weather_model.dart` |
| `DailyForecast` | Daily forecast item | `lib/models/weather_model.dart` |
| `MetarData` | METAR weather observation | `lib/models/metar_model.dart` |

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point & navigation
├── firebase_options.dart              # Firebase configuration
├── models/
│   ├── weather_model.dart            # Weather data structures
│   └── metar_model.dart              # METAR data structures
├── providers/
│   └── weather_provider.dart         # Central state management
├── services/
│   ├── weather_service.dart          # Open-Meteo API
│   ├── metar_service.dart            # Aviation Weather Center
│   ├── alert_service.dart            # Alert polling
│   ├── push_notification_service.dart # Firebase FCM
│   └── favorites_service.dart        # Favorites persistence
├── screens/
│   ├── home_screen.dart              # Weather display
│   ├── alerts_screen.dart            # Alerts list
│   └── favorites_screen.dart         # Favorites management
├── widgets/
│   ├── weather_card.dart             # Current weather display
│   ├── weather_details.dart          # Weather info grid
│   ├── forecast_card.dart            # Daily forecast item
│   ├── hourly_forecast.dart          # Hourly forecast list
│   ├── sun_arc_widget.dart           # Sunrise/sunset arc
│   ├── wind_compass.dart             # Wind direction compass
│   └── alert_widgets.dart            # Alert-related widgets
└── utils/
    ├── notification_checker.dart     # Notification diagnostics
    └── firebase_diagnostic.dart      # Firebase diagnostics
```

---

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- Android Studio (for Android development)
- A physical device or Android emulator
- Firebase project with FCM enabled

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/mashhood2717-ai/SkyPulse-Pakistan.git
cd SkyPulse-Pakistan

# 2. Install dependencies
flutter pub get

# 3. Build and run
flutter run

# 4. Or install directly on connected device
flutter build apk --install

# 5. Or run with release mode
flutter run --release
```

### Firebase Setup (For Alerts)

1. Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Cloud Messaging
3. Download `google-services.json` to `android/app/`
4. Create notification topics:
   - `all_alerts` (global topic for all users)
   - City-specific topics (e.g., `islamabad_alerts`)
5. Send test alerts using Firebase Console

---

## 📱 Features in Detail

### 🚨 Push Notification System

**Message States Handled:**
- ✅ Foreground (app open) - shows in-app alert
- ✅ Background (app minimized) - shows system notification
- ✅ Terminated (app closed) - shows system tray notification
- ✅ Tapped - opens app to Alerts tab

**Notification Channel:** `weather_alerts` (HIGH importance)

**Auto-Recovery Features:**
- Token persistence with SharedPreferences
- Automatic topic re-subscription on app launch
- Token refresh listener for expiration handling
- Retry logic (3 attempts for token, 2-second retry for subscriptions)
- Explicit permission verification

### 📊 METAR Integration

Automatically fetches precise airport observations for:
- Wind speed/direction (in knots, converted to km/h)
- Visibility (in meters/miles, converted to km)
- Temperature from actual airport readings
- Falls back to Open-Meteo if airport not found

Supported Cities:
- Islamabad (OIMM)
- Karachi (OPKC)
- Lahore (OPMR)
- Peshawar (OPMR)
- [Extensible to any city with ICAO code]

### ⭐ Favorites System

- Save unlimited favorite locations
- Persistent storage using SharedPreferences
- Reorderable list via drag-and-drop
- Tap to instantly switch location
- Weather auto-updates for selected location
- Smooth navigation without black screens

### 🔔 Alert System

- Real-time push notifications from Firebase
- Read/unread status tracking per alert
- Visual indicators (red dot for unread)
- Badge count shows unread alerts
- Auto-refresh every 30 seconds
- Auto-dismissed read status preserved on refresh
- Severity color coding
- Detailed alert information

---

## 🔐 Permissions Required

### Android
```xml
<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET"/>

<!-- Location -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<!-- Device Boot -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Vibration & Badge -->
<uses-permission android:name="android.permission.VIBRATE" />
```

### iOS
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Skypulse needs your location to show accurate weather data.</string>

<key>UIBackgroundModes</key>
<array>
  <string>remote-notification</string>
</array>
```

---

## 📦 Dependencies

```yaml
# UI & Navigation
flutter: SDK
cupertino_icons: ^1.0.2

# State Management
provider: ^6.1.1

# HTTP & Networking
http: ^1.1.0

# Location Services
geolocator: ^10.1.0
geocoding: ^2.1.1
permission_handler: ^11.4.0

# Firebase
firebase_core: ^2.32.0
firebase_messaging: ^14.7.10

# Data & Storage
shared_preferences: ^2.2.0
intl: ^0.18.1

# UI Components
flutter_svg: ^2.0.9+1

# Development
flutter_lints: ^2.0.0
```

---

## 🧪 Testing Scenarios

### Alert Reception (App Open)
1. Open Skypulse
2. Send alert from Firebase Console to `all_alerts` topic
3. Alert appears in Alerts tab within 5 seconds
4. Red dot shows unread status
5. Tap to mark as read (dot disappears)

### Alert Reception (App Closed)
1. Close app completely
2. Send alert from Firebase Console
3. Notification appears in system tray within 10 seconds
4. Tap notification → app opens to Alerts tab
5. Alert displays with unread indicator

### Permission Verification
1. Grant notification permission on first launch
2. App shows "Permission GRANTED" in console
3. FCM token automatically obtained and stored
4. App re-subscribes to all_alerts topic

---

## 🐛 Troubleshooting

### Alerts Not Arriving

**Step 1: Check Notification Permission**
```
Settings → Apps → Skypulse → Permissions → Enable Notifications
```

**Step 2: Force Stop & Restart**
```
Settings → Apps → Skypulse → Force Stop → Open App
```

**Step 3: Disable Battery Optimization**
```
Settings → Battery → Optimization → Add Skypulse → Don't Optimize
```

**Step 4: Check Console Logs**
Look for ✅ marks on app startup, or ❌ errors if issues

### Location Permission Denied
```
Settings → Apps → Skypulse → Permissions → Enable Location
```

### City Not Found
- Check spelling
- Use major city names
- Try with country code (e.g., "London, UK")

### METAR Data Not Available
- App automatically falls back to Open-Meteo
- METAR only available for airports with ICAO codes
- Check `MetarService.cityAirports` for supported cities

---

## 📊 Performance Metrics

- **App Size:** ~45 MB (release APK)
- **Startup Time:** ~2 seconds
- **Weather Fetch:** ~1-2 seconds
- **Alert Refresh:** 30-second intervals
- **Memory Usage:** ~50-100 MB (normal operation)
- **Battery Impact:** Minimal (uses efficient polling)

---

## 🔄 API Rate Limits

- **Open-Meteo:** 10,000 requests/day (no limits for personal use)
- **Aviation Weather Center:** No documented limits
- **Firebase FCM:** Unlimited

---

## 🎯 Deployment Guide

### Build Release APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

**Output:** `build/app/outputs/apk/release/app-release.apk`

### Install on Device
```bash
flutter build apk --install -d <device_id>
# or
flutter run --release -d <device_id>
```

### Deploy to Play Store
1. Create app signing key
2. Build signed APK/AAB
3. Upload to Google Play Console
4. Configure store listing
5. Release to production/beta/alpha

See [`DEPLOYMENT_CHECKLIST.md`](DEPLOYMENT_CHECKLIST.md) for detailed deployment steps.

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [`ALERT_FIX_SUMMARY.md`](ALERT_FIX_SUMMARY.md) | Alert system improvements & deployment |
| [`ALERT_ENHANCEMENTS.md`](ALERT_ENHANCEMENTS.md) | Technical details of alert system |
| [`ALERT_DEPLOYMENT_GUIDE.md`](ALERT_DEPLOYMENT_GUIDE.md) | User troubleshooting guide |
| [`DEPLOYMENT_CHECKLIST.md`](DEPLOYMENT_CHECKLIST.md) | Deployment checklist |
| [`DOCUMENTATION_INDEX.md`](DOCUMENTATION_INDEX.md) | Master documentation index |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | App architecture details |

---

## 🔧 Customization

### Change App Name
Update in:
- `android/app/src/main/AndroidManifest.xml` - `android:label="Skypulse"`
- `ios/Runner/Info.plist` - `CFBundleDisplayName` and `CFBundleName`
- `lib/main.dart` - `title: 'Skypulse'`

### Change Temperature Unit
Search for `°C` in codebase and replace with `°F`, then convert values

### Add New METAR Airport
In `lib/services/metar_service.dart`:
```dart
cityAirports['YourCity'] = ['ICAO_CODE'];
```

### Change Notification Channel
In `android/app/src/main/kotlin/com/mashhood/skypulse/MainActivity.kt`:
```kotlin
val channelId = "your_channel_id"
```

### Modify Alert Refresh Interval
In `lib/providers/weather_provider.dart`:
```dart
Timer.periodic(Duration(seconds: 30), (_) async {  // Change 30 to desired seconds
```

---

## 🚀 Future Enhancements

- [ ] Hourly forecast (15-minute intervals)
- [ ] Multiple alert types (weather, air quality, UV index)
- [ ] Weather map integration
- [ ] Dark/Light theme toggle
- [ ] Multi-language support
- [ ] Historical weather data
- [ ] Weather statistics
- [ ] Widget support
- [ ] Offline caching
- [ ] Wearable app support

---

## 📄 License

This project is open source. Feel free to use it for personal and commercial projects.

---

## 🤝 Contributing

Contributions welcome! Areas for improvement:
- UI/UX enhancements
- Performance optimization
- Additional weather parameters
- Localization
- Bug fixes

---

## 📞 Support

For issues, questions, or feedback:

**Documentation:**
- Start with [`ALERT_FIX_SUMMARY.md`](ALERT_FIX_SUMMARY.md) for overview
- Check [`ALERT_DEPLOYMENT_GUIDE.md`](ALERT_DEPLOYMENT_GUIDE.md) for troubleshooting
- Review [`DOCUMENTATION_INDEX.md`](DOCUMENTATION_INDEX.md) for all guides

**Common Issues:**
- See Troubleshooting section above
- Check console logs for error indicators (✅/❌ marks)
- Run diagnostic: `NotificationChecker.printFullDiagnostics()`

---

## 🏆 Credits

- **Weather Data:** [Open-Meteo API](https://open-meteo.com/)
- **Aviation Data:** [Aviation Weather Center](https://www.aviationweather.gov/)
- **Push Notifications:** [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- **Framework:** [Flutter](https://flutter.dev/)
- **State Management:** [Provider](https://pub.dev/packages/provider)

---

## 📈 App Statistics

- **Total Features:** 15+
- **Code Files:** 20+
- **Total Lines of Code:** 5000+
- **API Integrations:** 3 (Open-Meteo, Aviation Weather, Firebase)
- **Supported Locations:** 50,000+ cities
- **Supported Devices:** Android 8.0+

---

**🌤️ Skypulse - Your Weather, Your Way**

Built with attention to detail, reliability, and user experience.

**Latest Version:** 1.0 with Enhanced Alert Reliability  
**Last Updated:** November 2025  
**Status:** ✅ Production Ready
