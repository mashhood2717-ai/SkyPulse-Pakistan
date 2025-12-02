# Dark Mode & Light Mode with Weather-Based Background Animations

## Features Implemented

### 1. **Theme Provider** (`lib/providers/theme_provider.dart`)
- Manages app-wide theme switching between dark and light modes
- Persists theme preference using SharedPreferences
- Provides Material3-based themes with custom color schemes

**Dark Theme:**
- Background: `#0A0E27` (very dark blue)
- AppBar: `#1A1F3A` (dark blue)
- Primary: `#667EEA` (purple-blue)
- Secondary: `#764BA2` (purple)

**Light Theme:**
- Background: `#F5F7FA` (light gray)
- AppBar: `#FFFFFF` (white)
- Primary: `#667EEA` (purple-blue)
- Secondary: `#764BA2` (purple)

### 2. **Weather Background Animation** (`lib/widgets/weather_background_animation.dart`)

Dynamic background animations based on current weather conditions:

**Sunny Conditions:**
- Warm gradient background
- Orbiting sun particle effects with glow
- Smooth rotation animations

**Cloudy Conditions:**
- Cool gray gradient background
- Floating cloud shapes
- Gentle horizontal bobbing motion

**Rain/Storm Conditions:**
- Dark purple-blue gradient background
- Falling raindrop animations
- Fade-out effect as raindrops fall

**Snow Conditions:**
- Icy blue gradient background
- Rotating snowflake particles
- Diagonal falling pattern with sine wave drift

**Dual Mode Support:**
- Dark mode: Darker gradients with reduced opacity particles
- Light mode: Bright gradients with visible particle effects

### 3. **Settings Screen** (`lib/screens/settings_screen.dart`)

Beautiful settings screen with:

**Theme Toggle:**
- Animated custom switch (moves left/right)
- Shows current mode (Dark/Light)
- Displays theme preview with icons
- Smooth 300ms transition animation

**Features:**
- Beautiful card-based layout
- About section with app version
- Responsive design that works in both themes

### 4. **HomeScreen Integration**

**Changes:**
- Added settings button to AppBar (⚙️ icon)
- Wrapped screen with `WeatherBackgroundAnimation`
- Dynamically selects animation based on weather code
- Made background transparent to show animations

**Weather Code Mapping:**
- 50-67: Rain/Drizzle → `rain`
- 70-86: Snow → `snow`
- 80-82: Rain showers → `rain`
- 1-48: Partial clouds → `cloudy`
- Others: `sunny`

### 5. **Main App Updates**

**Added:**
- ThemeProvider to MultiProvider
- Consumer<ThemeProvider> for theme switching
- Settings route (`/settings`)

**Theme Switching Flow:**
```
User toggles in SettingsScreen
    ↓
ThemeProvider.toggleTheme()
    ↓
Updates SharedPreferences
    ↓
notifyListeners()
    ↓
MaterialApp rebuilds with new theme
```

## How to Use

### Switching Theme
1. Open app
2. Tap ⚙️ (settings icon) in HomeScreen AppBar
3. Toggle the "Theme" switch
4. Watch smooth animation + theme transition
5. Setting persists across app restarts

### Animation Preview
- **At Home:** Open any location and watch the background animate based on weather
- **In Settings:** Preview theme colors before applying
- All animations are GPU-optimized with TickerProviderStateMixin

## Technical Details

**Animation Framework:**
- AnimationController with multiple controllers for particles
- CustomPaint painters for geometric shapes (raindrops, snowflakes, clouds)
- Sin/cos functions for circular motion and drift effects
- Positioned + Transform widgets for efficient positioning

**Performance:**
- Lazy animation initialization
- Particle count limited to 15 (configurable)
- TickerProviderStateMixin for frame-sync animations
- GPU-accelerated transforms

**Storage:**
- Theme preference saved in SharedPreferences key: `isDarkMode`
- Automatically loaded on app start
- Persists across sessions

## Files Modified/Created

```
Created:
  lib/providers/theme_provider.dart          (111 lines)
  lib/widgets/weather_background_animation.dart (444 lines)
  lib/screens/settings_screen.dart           (142 lines)

Modified:
  lib/main.dart                              (added ThemeProvider, updated routes)
  lib/screens/home_screen.dart               (integrated animations, added settings button)
```

## Commit
`fa7f25b` - "feat: add dark/light mode toggle and weather-based background animations"

## Future Enhancements

- [ ] Add auto mode (system dark/light)
- [ ] Add more animation varieties (aurora, lightning, fog)
- [ ] Custom color theme selection
- [ ] Animation intensity settings
- [ ] Accent color customization
