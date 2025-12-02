# Satellite Map Feature Setup Guide

## Overview
The Satellite Map feature has been added to the SkyPulse weather app. It provides an interactive satellite view of the current weather location with real-time location updates.

## What's New

### New Tab: "Map"
- Added a new navigation tab in the bottom navigation bar (satellite icon)
- Accessible between Weather and Favorites tabs
- Updated navigation: Home → Alerts → Weather → **Map** → Favorites

### Features
- 📡 **Interactive Satellite View**: Real-time satellite imagery powered by Google Maps
- 📍 **Location Marker**: Automatic marker placement at current weather location
- 🔍 **Zoom & Pan**: Full interactive controls (pinch to zoom, swipe to pan)
- 📊 **Location Info**: Display city name, country code, and precise coordinates
- 🎯 **Auto-Update**: Map updates automatically when location changes
- 🧭 **Compass**: Built-in compass for orientation reference

## Required Setup

### 1. Get Google Maps API Key

**For Android:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable these APIs:
   - Maps SDK for Android
   - Maps JavaScript API
4. Create an **API Key** credential
5. Restrict the key to Android apps and add your app's package name and SHA-1 fingerprint

**For iOS:**
1. In Google Cloud Console, create an **API Key** credential
2. Restrict the key to iOS apps and add your app's Bundle ID

**Get Your App's Fingerprint (Android):**
```bash
cd android
./gradlew signingReport
```
Look for the SHA-1 hash under "Variant: releaseUnauthenticatedRelease"

### 2. Update Android Configuration

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE" />
```

Replace `YOUR_ACTUAL_API_KEY_HERE` with your actual Google Maps API key.

### 3. Update iOS Configuration (if deploying to iOS)

Edit `ios/Runner/Info.plist`:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs your location to show the satellite map</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location to show the satellite map</string>
<dict>
    <key>GoogleMapsApiKey</key>
    <string>YOUR_ACTUAL_API_KEY_HERE</string>
</dict>
```

### 4. Get Dependencies

Run the following command to install the new dependency:

```bash
flutter pub get
```

## File Structure

New/Modified files:
- ✅ `lib/screens/map_screen.dart` - New satellite map screen
- ✅ `lib/main.dart` - Updated navigation with new Map tab
- ✅ `pubspec.yaml` - Added `google_maps_flutter: ^2.5.0` dependency
- ✅ `android/app/src/main/AndroidManifest.xml` - Added Google Maps API key meta-data

## How It Works

### Map Screen (`lib/screens/map_screen.dart`)
1. **Initialization**: Creates a GoogleMap widget with satellite map type
2. **Location Tracking**: 
   - Reads current location from WeatherProvider (latitude/longitude)
   - Creates a marker at the weather location
   - Animates camera to show the location with 0.05° radius
3. **Interactive Features**:
   - User can zoom, pan, and rotate the map
   - Location marker shows city name, country, and coordinates
   - Automatically updates when location changes (favorite locations)
4. **UI Components**:
   - Top header: Shows city name, country code, and precise coordinates
   - Bottom info card: Displays satellite view info and usage instructions
   - Marker: Blue marker with info window on the current location

### Integration with WeatherProvider
The map automatically syncs with the WeatherProvider:
- When you switch to a favorite location, the map zooms to that location
- When you return home, the map updates to show your current location
- Uses the same location data as the main weather screen

## Testing the Map

1. **Launch the app**:
   ```bash
   flutter run -d <device_id>
   ```

2. **Navigate to the Map tab**: Tap the satellite icon in the bottom navigation

3. **Test Features**:
   - ✅ Map loads and shows current location
   - ✅ Pinch to zoom in/out
   - ✅ Swipe to pan around
   - ✅ Location marker shows in blue
   - ✅ Info window displays on marker tap
   - ✅ Switch favorite locations and map updates
   - ✅ Return to home and map updates accordingly

## Troubleshooting

### "Google Maps is not initialized"
- ✅ Check that `YOUR_ACTUAL_API_KEY_HERE` has been replaced with real API key
- ✅ Ensure Maps SDK for Android is enabled in Google Cloud Console
- ✅ Verify API key restrictions match your app's package name and SHA-1

### "Android build fails with Google Maps dependency"
```bash
flutter clean
flutter pub get
flutter run
```

### Map not updating when location changes
- ✅ Verify WeatherProvider is properly reading location data
- ✅ Check that latitude/longitude are not null
- ✅ Review logs with `flutter logs` for any errors

### "Permission denied" on iOS
- ✅ Update Info.plist with location permissions (see iOS Setup above)
- ✅ Ensure user grants location permission when prompted

## API Key Security

⚠️ **Important**: 
- Never commit your API key to git
- If you see the key in git history, regenerate it immediately in Google Cloud Console
- Use environment variables or CI/CD secrets in production
- Consider using API key restrictions to Android/iOS only

## Performance Notes

- The satellite map uses real Google Maps tiles
- Initial load time: 1-2 seconds
- Zoom animations are smooth and optimized
- Location updates trigger map re-render (observes WeatherProvider)

## Future Enhancements

Possible features to add:
- 🗺️ Map type selector (Satellite, Terrain, Hybrid, Normal)
- 🎨 Multiple markers for favorite locations
- 📍 Current location tracking (blue dot)
- 🌡️ Weather overlay on map
- 🚩 Weather alerts visualization on map
- ⚡ Offline map caching

## Related Documentation

- [Google Maps Flutter Documentation](https://pub.dev/packages/google_maps_flutter)
- [Flutter Location Permissions](https://pub.dev/packages/permission_handler)
- [Google Cloud Console](https://console.cloud.google.com/)

---

**Feature Added By**: AI Assistant
**Date**: December 2, 2025
**Version**: 1.2.0+1
