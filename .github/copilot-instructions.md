<!-- Copilot / AI agent instructions for the SkyPulse_Pakistan Flutter app -->
# Copilot instructions — SkyPulse_Pakistan

Purpose: provide focused, actionable knowledge so an AI coding agent can be immediately productive in this repository.

- Quick start
  - Run: `flutter pub get` (dependencies are in `pubspec.yaml`).
  - Launch app: `flutter run -d <device>` from repository root.
  - Android build (if needed): open `android/` and run `./gradlew assembleDebug`.

- High-level architecture (one-paragraph)
  - This is a Flutter app using `provider` for state management. `WeatherProvider` (in `lib/providers/weather_provider.dart`) is the single source of truth: it orchestrates data fetching, METAR fallback logic, alert polling, and notifies UI screens. The provider delegates heavy lifting to `lib/services/*` (WeatherService, MetarService, AlertService) and consumes models in `lib/models/*`.

- Core components & boundaries (files to inspect first)
  - App entry + DI: `lib/main.dart` — registers `WeatherProvider` with `ChangeNotifierProvider`.
  - State orchestration: `lib/providers/weather_provider.dart` — central flows: `fetchWeatherByLocation`, `fetchWeatherByCity`, `refresh`, and `_fetchWeatherWithMetarAttempt` (METAR-first strategy).
  - Weather API: `lib/services/weather_service.dart` — uses Open-Meteo APIs (no API key). Methods: `getWeatherByCoordinates`, `getCoordinatesFromCity`.
  - METAR support: `lib/services/metar_service.dart` — looks up nearby airports (hard-coded lists + coordinate lookup) and uses Aviation Weather Center endpoints. Extend `cityAirports` or airport coordinates to add support.
  - Alerts: `lib/services/alert_service.dart` — calls a Cloudflare Worker endpoint (`_alertApiBase`) to check alerts. Alerts are optional and errors return empty lists.
  - Models: `lib/models/weather_model.dart`, `lib/models/metar_model.dart` — note conversions: METAR -> `CurrentWeather` uses sunrise/sunset from the API to compute `isDay` correctly.
  - UI surfaces: `lib/screens/*` and `lib/widgets/*` — these consume `WeatherProvider` and the model objects directly.

- Important patterns & repo-specific conventions
  - METAR-first: code attempts to obtain METAR for a location and, if present, composes an enhanced current weather by combining METAR (for accurate immediate observations) with API-derived forecast/UV info. See `_fetchWeatherWithMetarAttempt` in `WeatherProvider`.
  - Units & conversions: METAR wind speed is in knots and converted to km/h in `MetarData.toCurrentWeather`. Visibility in METAR may be miles/meters — the models convert to km. Watch for unit conversions when adding features.
  - Airport support: add cities to `MetarService.cityAirports` (key = city display name, value = ICAO list) OR extend `_findNearbyAirportICAOs` airport coordinates to broaden nearby searches.
  - Alerts are polled: `WeatherProvider` starts a Timer in `_startAlertRefreshTimer` that refreshes every 30s. Changes to this behavior must update provider and UI expectations.
  - Error handling style: services typically catch exceptions, log with `print`, and return safe defaults (e.g., empty alert arrays). Avoid assuming network calls always return data.

- External integrations & secrets
  - Open-Meteo (forecast + geocoding): no API key required (`weather_service.dart`).
  - Aviation Weather Center (METAR): no API key required (`metar_service.dart`).
  - Alerts endpoint: `lib/services/alert_service.dart` uses a Cloudflare Worker URL; update `_alertApiBase` if deploying your own alert backend.
  - Firebase: `lib/firebase_options.dart` exists and `firebase_messaging` is listed in `pubspec.yaml`. If running push notifications locally, follow Firebase project setup and ensure `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) are present.

- Developer workflows & commands
  - Install deps: `flutter pub get`.
  - Run app: `flutter run -d <device>`.
  - To reproduce network issues locally: enable verbose prints — the code already emits many `print(...)` debug logs.
  - If adding new native (Firebase) configuration, update files under `android/app/` and `ios/Runner/` accordingly.

- How to extend common features (examples)
  - Add METAR airport for a city: edit `MetarService.cityAirports`, e.g.
    - `cityAirports['MyCity'] = ['XXXX'];`
  - Add a new nearby airport coordinate for discovery: add `{ 'XXXX': {'lat': xx.x, 'lon': yy.y} }` inside `_findNearbyAirportICAOs`.
  - Change alert API URL: update `_alertApiBase` in `lib/services/alert_service.dart`.

- Quick file references (first places to look when changing behavior)
  - `pubspec.yaml` — dependencies and SDK constraints
  - `lib/main.dart` — app boot and provider registration
  - `lib/providers/weather_provider.dart` — main orchestration and polling logic
  - `lib/services/*.dart` — integrations and network logic
  - `lib/models/*.dart` — parsing/formatting and unit conversions
  - `lib/screens/*` and `lib/widgets/*` — UI usage of models/provider

- Tests & CI
  - There are no tests in the repository. When adding tests, prefer unit tests for `WeatherService`, `MetarService` (parsing), and `MetarData.toCurrentWeather` conversions.

If any section is unclear or you'd like more examples (for example: exact code snippets to add a new METAR airport, or a checklist to configure Firebase locally), tell me which area to expand and I'll iterate.
