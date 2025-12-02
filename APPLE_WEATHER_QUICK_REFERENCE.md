# Apple Weather Design - Quick Reference

## File Location
```
lib/screens/home_screen_new.dart
```

## Class Name
```dart
class HomeScreenNew extends StatelessWidget
```

## How to Use

### Option 1: Use as Alternative Route
In `lib/main.dart`, add a route:

```dart
routes: {
  '/': (context) => const HomeScreen(),
  '/weather-new': (context) => const HomeScreenNew(),
  // ... other routes
}
```

Then navigate from settings or elsewhere:
```dart
Navigator.pushNamed(context, '/weather-new');
```

### Option 2: Replace HomeScreen
In `lib/main.dart`, replace:
```dart
home: const HomeScreen(),
```

With:
```dart
home: const HomeScreenNew(),
```

### Option 3: Use with PageView (Multiple Views)
```dart
PageView(
  children: [
    HomeScreen(),
    HomeScreenNew(),
    // Add more screen variations
  ],
)
```

## Data Access

The screen automatically fetches data from `WeatherProvider`:

```dart
final weather = weatherProvider.weatherData;  // WeatherData object

// Current weather
weather.current.temperature    // double
weather.current.humidity       // int
weather.current.windSpeed      // double
weather.current.windGust       // double
weather.current.dewPoint       // double
weather.current.weatherCode    // int
weather.current.pressure       // double
weather.current.visibility     // double
weather.current.uvIndex        // double
weather.current.cloudCover     // int

// Daily forecast
weather.forecast              // List<DailyForecast>
weather.forecast[0].dayName   // String ("Today", "Tomorrow", etc.)
weather.forecast[0].maxTemp   // double
weather.forecast[0].minTemp   // double
weather.forecast[0].weatherCode // int
weather.forecast[0].weatherIcon // String (emoji)
weather.forecast[0].date      // DateTime

// Hourly forecast
weather.hourlyTemperatures    // List<double>
weather.hourlyWeatherCodes    // List<int>
weather.hourlyTimes           // List<String> ("2025-12-02T14:00", etc.)
weather.hourlyPrecipitation   // List<int>

// AQI
weather.aqiIndex              // int?
```

## Theme Management

The screen respects the current theme:

```dart
final isDark = context.watch<ThemeProvider>().isDarkMode;

// Toggle theme
context.read<ThemeProvider>().toggleTheme();
```

Dark/Light colors are automatically applied to:
- Text colors
- Card backgrounds (glassmorphism with opacity)
- Border colors
- Icon colors

## Weather Icons

Weather codes are mapped to emojis:

```
0    -> ☀️  (Clear sky)
1    -> 🌤️  (Mainly clear)
2    -> ⛅  (Partly cloudy)
3    -> ☁️  (Overcast)
45/48 -> 🌫️ (Fog)
51-55 -> 🌦️ (Drizzle)
61-65 -> 🌧️ (Rain)
71-75 -> ❄️  (Snow)
77    -> 🌨️ (Snow grains)
80-82 -> 🌧️ (Rain showers)
85-86 -> 🌨️ (Snow showers)
95/96/99 -> ⛈️ (Thunderstorm)
```

## Color Scheme

### Dark Mode
- Background: Transparent with dark overlay
- Cards: `Colors.white.withOpacity(0.1)`
- Borders: `Colors.white.withOpacity(0.2)`
- Text: `Colors.white` / `Colors.white70` / `Colors.white54`

### Light Mode
- Background: Transparent with light overlay
- Cards: `Colors.white.withOpacity(0.2)`
- Borders: `Colors.white.withOpacity(0.3)`
- Text: `Colors.black` / `Colors.black54` / `Colors.black45`

### Temperature Bar Colors
- ≤0°C → Blue
- 0-15°C → Cyan
- 15-25°C → Green
- 25-35°C → Orange
- >35°C → Red

## Customization

### Change Large Temperature Font Size
Line 119 in `home_screen_new.dart`:
```dart
fontSize: 80,  // Change this value
```

### Change Grid Layout (Currently 2 Columns)
Line 296:
```dart
crossAxisCount: 2,  // Change to 3 for 3 columns, etc.
```

### Change Number of Hourly Forecasts
Line 191:
```dart
weather.hourlyTemperatures.length < 12  // Change 12 to desired number
    ? weather.hourlyTemperatures.length 
    : 12,
```

### Change Number of Daily Forecasts
Line 252:
```dart
weather.forecast.length < 10  // Change 10 to desired number
    ? weather.forecast.length 
    : 10,
```

### Adjust Spacing
All spacing is controlled by `SizedBox` widgets:
```dart
SizedBox(height: 32),  // Adjust these values
SizedBox(height: 16),  // for different spacing
```

### Change Weather Details Displayed
Edit the Grid children (lines 300-330) to add/remove details.

## Performance Tips

1. **Data is cached**: WeatherProvider caches data, so multiple views don't cause extra API calls
2. **Animations are optimized**: Background animation uses GPU acceleration
3. **Rebuilds are minimized**: Only affected widgets rebuild when theme changes
4. **Lazy loading**: Daily/hourly forecasts only shown if data exists

## Error Handling

If data is missing, the screen shows:
```dart
if (weatherProvider.isLoading) {
  // Loading state
}

if (weatherProvider.weatherData == null) {
  // No data available
}
```

## Testing Checklist

Before deploying to production:

- [ ] Theme toggle works (dark ↔ light)
- [ ] All weather data displays correctly
- [ ] Hourly forecast scrolls smoothly
- [ ] Daily forecast displays all 10 days
- [ ] Detail grid shows all 6 metrics
- [ ] Background animation appears (matches weather)
- [ ] No stuttering or lag
- [ ] Text is readable in both themes
- [ ] Icons render correctly
- [ ] Location name displays
- [ ] Temperature range shows properly
- [ ] Works on landscape orientation
- [ ] Works on different screen sizes

## Dependencies

Uses existing dependencies (no new packages added):
- flutter
- provider
- Material Design

## File Size
- Compiled: 50.3MB (APK)
- Source: 380 lines of Dart code

## Build Command

```bash
flutter build apk --release
```

Or install and run:

```bash
flutter run -d <device_id> --release
```

## Troubleshooting

### No data showing?
- Check WeatherProvider is properly initialized
- Ensure location permission is granted
- Check internet connection

### Theme not updating?
- Restart the app
- Check SharedPreferences is working
- Verify ThemeProvider is in app's provider list

### Animation is laggy?
- Check device performance
- Reduce particle count in WeatherBackgroundAnimation
- Disable animations if running on low-end device

---

**Last Updated**: December 2, 2025  
**Commit**: 6eaf65c
