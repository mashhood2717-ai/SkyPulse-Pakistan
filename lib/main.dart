import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/weather_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/favorites_service.dart';
import 'services/favorites_cache_service.dart' show FavoritesCacheService;
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/alerts_screen.dart';
import 'services/push_notification_service.dart';
import 'services/home_widget_service.dart';
import 'services/widget_refresh_service.dart';
import 'utils/log.dart';
import 'utils/theme_utils.dart';

/// Global navigation helper for external access (e.g., from push notifications)
class AppNavigation {
  static void Function()? _navigateToAlerts;

  /// Register the callback to navigate to alerts
  static void registerNavigateToAlerts(void Function() callback) {
    _navigateToAlerts = callback;
  }

  /// Navigate to alerts tab (called from push notification service)
  static void navigateToAlerts() {
    _navigateToAlerts?.call();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  logDebug('🚀 Initializing Skypulse...');

  // Initialize Firebase FIRST (before push notifications)
  logDebug('🔥 Initializing Firebase...');
  final firebaseInit = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(
    const Duration(seconds: 10),
  );

  // Initialize home screen widget
  logDebug('📱 Initializing home widget...');
  if (!kIsWeb) {
    await HomeWidgetService.initialize();
    // Keeps the home-screen widget current while the app is closed.
    await WidgetRefreshService.initialize();
  }

  // Wait for Firebase first (critical)
  try {
    await firebaseInit;
    logDebug('✅ Firebase initialized successfully!');
  } catch (e) {
    logDebug('⚠️ Firebase init issue (app will continue)');
  }

  // Permission prompts and push registration deliberately happen *after* the
  // first frame (see _HomePageState.initState). Awaiting them here meant the
  // user stared at a blank window through up to three system dialogs.
  logDebug('✅ Starting app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider(create: (_) => FavoritesCacheService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Skypulse',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getTheme(),
            home: const HomePage(),
            routes: {
              '/favorites': (context) => const FavoritesScreen(),
            },
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _alertsTab = 0;
  static const int _weatherTab = 1;
  static const int _favoritesTab = 2;

  int _selectedIndex = _weatherTab; // Start with Weather (home screen)

  /// Tabs the user has actually opened. IndexedStack builds every child
  /// eagerly, which used to run FavoritesScreen's per-city geocode + forecast
  /// fan-out at launch, before anything was on screen.
  final Set<int> _builtTabs = {_weatherTab};

  @override
  void initState() {
    super.initState();

    // Register navigation callback for push notifications
    AppNavigation.registerNavigateToAlerts(_goToAlertsTab);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Single owner of the launch fetch. It already schedules alerts and topic
      // subscription itself via _doBackgroundTasks, so nothing else needs to
      // trigger a refresh here. Geolocator raises the location prompt from
      // inside this call, so permission_handler is not asked separately.
      Provider.of<WeatherProvider>(context, listen: false)
          .fetchWeatherByLocation();

      if (!kIsWeb) {
        // FirebaseMessaging.requestPermission() covers POST_NOTIFICATIONS on
        // Android 13+. ACCESS_BACKGROUND_LOCATION is deliberately never
        // requested: it is not declared in the manifest, so the old
        // Permission.locationAlways call could only ever fail, and asking for
        // it at all triggers a Play policy review the app does not need.
        PushNotificationService.initializePushNotifications();
      }
    });
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _builtTabs.add(index);
    });
  }

  void _goToAlertsTab() {
    _selectTab(_alertsTab);
  }

  void switchToWeatherTabWithFavorite(String cityName) {
    _selectTab(_weatherTab);
    // Call after frame to ensure HomeScreen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeScreen.goToFavorite(cityName);
    });
  }

  Widget _buildTab(int index) {
    if (!_builtTabs.contains(index)) return const SizedBox.shrink();

    switch (index) {
      case _alertsTab:
        return const AlertsScreen();
      case _favoritesTab:
        return _FavoritesScreenWrapper(
          onFavoriteSelected: switchToWeatherTabWithFavorite,
        );
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(3, _buildTab),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surface.withOpacity(p.isLight ? 0.92 : 0.7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(p.isLight ? 0.08 : 0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Consumer<WeatherProvider>(
          builder: (context, weatherProvider, _) {
            final unreadCount = weatherProvider.unreadAlertCount;

            // One item per IndexedStack child. The bar used to carry a fourth
            // "Home" item that mapped onto the Weather screen, so Home could
            // never render as selected; "back to my location" now lives on the
            // Weather screen's app bar, next to search. `type` is pinned to
            // fixed because BottomNavigationBar silently switches to shifting
            // at four or more items, which hides the unselected labels.
            return BottomNavigationBar(
              currentIndex: _selectedIndex,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: WeatherTheme.accent,
              unselectedItemColor: p.textMuted,
              onTap: (index) {
                FocusManager.instance.primaryFocus?.unfocus();
                _selectTab(index);
              },
              items: [
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_active),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  label: 'Alerts',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.cloud),
                  label: 'Weather',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.favorite),
                  label: 'Favorites',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FavoritesScreenWrapper extends StatelessWidget {
  final Function(String) onFavoriteSelected;

  const _FavoritesScreenWrapper({
    required this.onFavoriteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FavoritesScreen(
      onLocationSelected: onFavoriteSelected,
    );
  }
}
