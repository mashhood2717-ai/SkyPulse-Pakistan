# Flutter Weather App - Architecture

## 📐 App Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      USER INTERFACE                     │
│                     (home_screen.dart)                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                   STATE MANAGEMENT                      │
│                  (weather_provider.dart)                │
│  ┌──────────────────────────────────────────────────┐  │
│  │  • Manages weather data state                    │  │
│  │  • Handles loading and error states              │  │
│  │  • Notifies UI of changes                        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    SERVICE LAYER                        │
│                 (weather_service.dart)                  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  • Fetches data from Open-Meteo API             │  │
│  │  • Geocoding (city → coordinates)               │  │
│  │  • Weather data (coordinates → weather)         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    DATA MODELS                          │
│                  (weather_model.dart)                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │  • WeatherData                                   │  │
│  │  • CurrentWeather                                │  │
│  │  • DailyForecast                                 │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

```
User Action (Search/Location)
        │
        ▼
WeatherProvider.fetchWeather()
        │
        ▼
WeatherService.getWeatherByCity()
        │
        ├─► Geocoding API → Get Coordinates
        │
        └─► Weather API → Get Weather Data
                │
                ▼
        Parse JSON → WeatherModel
                │
                ▼
        Update Provider State
                │
                ▼
        UI Auto-Updates (Provider Pattern)
```

## 📦 Component Breakdown

### 1. Screens
```
home_screen.dart
├── Status Bar (AppBar)
├── Search Bar
├── Current Weather Card
├── Sun Arc Widget
├── Weather Details Grid
└── 7-Day Forecast List
```

### 2. Widgets
```
weather_card.dart
├── Location Name
├── Weather Icon
├── Temperature
├── Description
└── Feels Like

forecast_card.dart
├── Day Name
├── Weather Icon
├── Precipitation %
└── Min/Max Temp

sun_arc_widget.dart
├── Arc Path (SVG)
├── Animated Sun Position
├── Sunrise Time
└── Sunset Time

weather_details.dart
├── Wind Speed
├── Humidity
├── Pressure
└── Cloud Cover
```

## 🌐 API Integration

### Open-Meteo API Structure
```
GET https://api.open-meteo.com/v1/forecast

Parameters:
├── latitude: double
├── longitude: double
├── current: string (comma-separated)
│   ├── temperature_2m
│   ├── relative_humidity_2m
│   ├── weather_code
│   ├── wind_speed_10m
│   └── pressure_msl
├── daily: string (comma-separated)
│   ├── temperature_2m_max
│   ├── temperature_2m_min
│   ├── sunrise
│   ├── sunset
│   └── weather_code
└── timezone: auto

Response:
├── current: { }
└── daily: {
    ├── time: []
    ├── temperature_2m_max: []
    ├── temperature_2m_min: []
    └── ...
}
```

## 🎯 Feature Implementation

### Status Bar Weather
```dart
SliverAppBar
├── Weather Icon (from weather_code)
├── Temperature (rounded)
└── Location Name (from geocoding)
```

### Circular Sun Animation
```dart
CustomPainter (SunArcPainter)
├── Calculate Progress (current time / daylight hours)
├── Draw Background Arc
├── Draw Progress Arc
├── Calculate Sun Position (trigonometry)
│   ├── angle = π + (π × progress)
│   ├── x = center.x + radius × cos(angle)
│   └── y = center.y + radius × sin(angle)
└── Draw Sun at Position
```

### Weather Icons Mapping
```
WMO Weather Codes → Emoji Icons
├── 0: Clear sky → ☀️
├── 1-3: Cloudy → 🌤️⛅☁️
├── 45-48: Fog → 🌫️
├── 51-55: Drizzle → 🌦️
├── 61-65: Rain → 🌧️
├── 71-77: Snow → ❄️🌨️
├── 80-82: Showers → 🌧️
└── 95-99: Thunderstorm → ⛈️
```

## 🔐 Permissions Flow

```
App Launch
    │
    ▼
Check Location Permission
    │
    ├─► Granted ──────────┐
    │                     │
    └─► Denied            │
         │                │
         ▼                │
    Request Permission    │
         │                │
         ├─► Granted ─────┤
         │                ▼
         └─► Denied    Get Current Location
              │            │
              ▼            ▼
         Show Error    Fetch Weather
         │
         └─► Use Manual Search
```

## 📱 State Management (Provider Pattern)

```dart
ChangeNotifierProvider<WeatherProvider>
    │
    ├── Listen to changes
    │   └── Consumer<WeatherProvider>
    │       └── Rebuild UI automatically
    │
    ├── State Properties
    │   ├── weatherData: WeatherData?
    │   ├── isLoading: bool
    │   ├── error: String?
    │   ├── cityName: String
    │   └── countryCode: String
    │
    └── Methods
        ├── fetchWeatherByLocation()
        ├── fetchWeatherByCity(String)
        └── refresh()
```

## 🎨 UI Component Tree

```
MaterialApp
└── HomeScreen
    └── Scaffold
        └── Container (Gradient Background)
            └── SafeArea
                └── CustomScrollView
                    ├── SliverAppBar (Status Bar)
                    └── SliverToBoxAdapter
                        └── Column
                            ├── Search Bar
                            ├── WeatherCard
                            ├── SunArcWidget
                            ├── WeatherDetails
                            └── List<ForecastCard>
```

## 🔄 Refresh Mechanism

```
Pull-to-Refresh
    │
    ▼
RefreshIndicator triggers
    │
    ▼
provider.refresh()
    │
    ├─► Has City Name? ──► fetchWeatherByCity()
    │
    └─► No City Name? ───► fetchWeatherByLocation()
    │
    ▼
UI updates automatically
```

## 📊 Performance Considerations

1. **Lazy Loading**: Forecasts load on scroll
2. **Caching**: Last weather data cached in provider
3. **Minimal Rebuilds**: Only affected widgets rebuild
4. **Optimized Painting**: CustomPainter for sun arc
5. **Async Operations**: All API calls are async

## 🛠️ Error Handling

```
Try-Catch Blocks
    │
    ├── Network Errors
    │   └── Show: "Check internet connection"
    │
    ├── Location Errors
    │   └── Show: "Enable location permission"
    │
    ├── API Errors
    │   └── Show: "Weather service unavailable"
    │
    └── Parsing Errors
        └── Show: "Invalid data format"
```

---

**This architecture ensures:**
- ✅ Clean separation of concerns
- ✅ Easy testing and maintenance
- ✅ Scalable for future features
- ✅ Efficient state management
- ✅ Responsive UI updates
