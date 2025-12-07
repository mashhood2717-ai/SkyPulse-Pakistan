# Copilot Instructions — SkyPulse Pakistan

## Quick Start
```bash
flutter pub get           # Install dependencies
flutter run -d <device>   # Launch app (use -d chrome for web, -d emulator-5554 for Android)
```
No API keys required for weather/METAR. Firebase requires `android/app/google-services.json`.

## Architecture Overview
Flutter app using **Provider** for state management with a 3-tab UI (Alerts | Weather | Favorites).

**Data Flow:** UI screens → `WeatherProvider` → Services → External APIs → Models → UI

| Layer | Key Files | Responsibility |
|-------|-----------|----------------|
| Entry | `lib/main.dart` | Firebase init, MultiProvider registration, theme based on `isDay` |
| State | `lib/providers/weather_provider.dart` | Single source of truth: fetches, caching, alert polling |
| Services | `lib/services/*.dart` | Network calls (Open-Meteo, METAR, Alerts, FCM) |
| Models | `lib/models/*.dart` | Parsing & unit conversions |
| UI | `lib/screens/*`, `lib/widgets/*` | Consume provider via `Consumer<WeatherProvider>` |

## Critical Patterns

### METAR-First with API Fallback
`WeatherProvider._fetchWeatherWithMetarAttempt()` fetches Open-Meteo first (shows immediately), then enhances with METAR in background:
```dart
// Pattern: Show API data instantly, enhance with METAR async
_weatherData = apiData;
notifyListeners();  // UI updates immediately
_fetchMetarInBackground(cityName, lat, lon, apiData);  // Enhances later
```

### Caching Strategy
Provider maintains `_cachedWeatherData` for instant refresh and offline fallback. Always update cache after successful fetch:
```dart
_cachedWeatherData = _weatherData;
_cachedCityName = _cityName;
```

### Background Tasks Pattern
Non-blocking operations use `_doBackgroundTasks()` with `Future.microtask()` — alerts, FCM topics run after UI updates.

### Unit Conversions (METAR ↔ API)
- Wind: METAR uses **knots** → convert to **km/h** (`wspd * 1.852`)
- Visibility: METAR uses **statute miles** → convert to **km** (`visib * 1.60934`)
- See `MetarData.fromJson()` and `MetarData.toCurrentWeather()` in `lib/models/metar_model.dart`

### Error Handling
Services catch exceptions, log with `print()`, return safe defaults (empty lists, null). Never assume network success:
```dart
} catch (e) {
  print('❌ [AlertService] Error: $e');
  return [];  // Alerts are optional
}
```

## Extending the App

### Add METAR Support for a City
Edit `lib/services/metar_service.dart`:
```dart
static const Map<String, List<String>> cityAirports = {
  'MyCity': ['ICAO'],  // Add here - key is display name, value is ICAO code list
  // ...
};
```

### Add Alert Backend
Update `lib/services/alert_service.dart`:
```dart
static const String _alertApiBase = 'https://your-worker.workers.dev';
```

### Add New Theme Colors
Edit `lib/utils/theme_utils.dart` — `WeatherTheme` provides day/night gradients. Theme is auto-switched based on `weatherData.current.isDay`.

## External Dependencies

| Service | Endpoint | Auth | File |
|---------|----------|------|------|
| Open-Meteo | `api.open-meteo.com` | None | `weather_service.dart` |
| METAR | `aviationweather.gov` | None | `metar_service.dart` |
| Alerts | Cloudflare Worker | None | `alert_service.dart` |
| Push | Firebase FCM | `google-services.json` | `push_notification_service.dart` |

## Key Files Quick Reference
- **State orchestration**: `lib/providers/weather_provider.dart` (all fetch logic, caching, alert polling)
- **Weather parsing**: `lib/models/weather_model.dart` (`WeatherData.fromJson`)
- **METAR parsing**: `lib/models/metar_model.dart` (`MetarData.fromJson`, unit conversions)
- **Day/Night theme**: `lib/utils/theme_utils.dart` + `lib/main.dart` Consumer
- **Firebase setup**: `lib/firebase_options.dart`, `lib/services/push_notification_service.dart`

## Debugging Tips
- Verbose logging via `print()` is already present throughout services
- Check FCM token: stored in SharedPreferences as `fcm_token`
- Alert polling runs every 30s via `_startAlertRefreshTimer()` in WeatherProvider
- METAR fallback: if no airport found, app silently uses API-only data

## Testing (No Tests Exist)
When adding tests, prioritize:
1. `MetarData.fromJson()` and `toCurrentWeather()` — unit conversion correctness
2. `WeatherData.fromJson()` — parsing hourly/daily forecasts
3. `WeatherProvider` — mock services to test caching/fallback logic
