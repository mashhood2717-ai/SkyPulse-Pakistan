import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/weather_provider.dart';
import 'services/favorites_service.dart';
import 'services/favorites_cache_service.dart' show FavoritesCacheService;
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/alerts_screen.dart';
import 'services/push_notification_service.dart';
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

  print('🚀 Initializing Skypulse...');

  // Initialize Firebase FIRST (before push notifications)
  print('🔥 Initializing Firebase...');
  final firebaseInit = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(
    const Duration(seconds: 10),
  );

  // Request notification permissions (Android 13+) - with timeout
  print('📱 Requesting notification permissions...');
  final permissionRequest = Permission.notification.request().timeout(
    const Duration(seconds: 5),
    onTimeout: () {
      print('⚠️ Permission request timeout');
      return PermissionStatus.denied;
    },
  ).then((status) {
    if (status.isGranted) {
      print('✅ Notification permission granted!');
    } else {
      print(
          '⚠️ Notification permission: ${status.isDenied ? "DENIED" : status.isPermanentlyDenied ? "PERMANENTLY DENIED" : "OTHER"}');
    }
  }).catchError((e) {
    print('⚠️ Permission error: $e');
  });

  // Initialize push notifications in parallel (NO TIMEOUT)
  print('🔔 Initializing push notifications...');
  final pushInit = PushNotificationService.initializePushNotifications();

  // Wait for Firebase first (critical)
  try {
    await firebaseInit;
    print('✅ Firebase initialized successfully!');
  } catch (e) {
    print('⚠️ Firebase init issue (app will continue)');
  }

  // Then run UI (don't wait for permissions or push init to complete)
  // These will complete in background while app is loading
  print('✅ Starting app...');
  runApp(const MyApp());

  // Let permissions and push init happen in background without blocking UI
  Future.wait([permissionRequest, pushInit]).then((_) {
    print('✅ All background initializations complete!');
  }).catchError((e) {
    print('⚠️ Background init issue: $e');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesService()),
        ChangeNotifierProvider(create: (_) => FavoritesCacheService()),
      ],
      child: Consumer<WeatherProvider>(
        builder: (context, weatherProvider, child) {
          final isDay = weatherProvider.weatherData?.current.isDay ?? true;
          // Debug: Log theme decision
          print(
              '🎨 [Theme] isDay = $isDay, city = ${weatherProvider.cityName}');
          return MaterialApp(
            title: 'Skypulse',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: isDay ? Brightness.light : Brightness.dark,
              scaffoldBackgroundColor: WeatherTheme.getPrimaryColor(isDay),
              appBarTheme: AppBarTheme(
                backgroundColor: WeatherTheme.getAccentColor(isDay),
                elevation: 0,
              ),
              colorScheme: isDay
                  ? const ColorScheme.light(
                      primary: WeatherTheme.dayPrimary,
                      secondary: WeatherTheme.dayAccent,
                      surface: WeatherTheme.dayPrimary,
                    )
                  : const ColorScheme.dark(
                      primary: WeatherTheme.nightPrimary,
                      secondary: WeatherTheme.nightAccent,
                      surface: WeatherTheme.nightPrimary,
                    ),
            ),
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
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 1; // Start with Weather (home screen)

  @override
  void initState() {
    super.initState();

    // Register navigation callback for push notifications
    AppNavigation.registerNavigateToAlerts(_goToAlertsTab);

    // Fetch weather on app start (urgent, high priority)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WeatherProvider>(context, listen: false);
      // Fetch weather ONLY - will show loading spinner
      provider.fetchWeatherByLocation();

      // Then do background tasks after weather is loaded
      provider.weatherData != null
          ? _startBackgroundTasks(provider)
          : Future.delayed(const Duration(milliseconds: 500), () {
              if (provider.weatherData != null) {
                _startBackgroundTasks(provider);
              }
            });
    });
  }

  /// Start background tasks after weather is loaded
  void _startBackgroundTasks(WeatherProvider provider) {
    // Fetch alerts in background
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        // This will update alerts without blocking UI
        await provider.refresh();
      } catch (e) {
        print('Background task error: $e');
      }
    });
  }

  void _goToAlertsTab() {
    setState(() {
      _selectedIndex = 0; // Alerts tab
    });
  }

  void switchToWeatherTab() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  void switchToWeatherTabWithFavorite(String cityName) {
    setState(() {
      _selectedIndex = 1;
    });
    // Call after frame to ensure HomeScreen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeScreen.goToFavorite(cityName);
    });
  }

  void goToHome() {
    // Navigate to weather tab and trigger going to first page
    setState(() {
      _selectedIndex = 1;
    });
    // Call after frame to ensure HomeScreen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeScreen.goToHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const AlertsScreen(), // Index 0 - Alerts
          const HomeScreen(), // Index 1 - Weather/Home
          _FavoritesScreenWrapper(
            onFavoriteSelected: switchToWeatherTabWithFavorite,
          ), // Index 2 - Favorites
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F3A).withOpacity(0.7), // Transparent
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Consumer<WeatherProvider>(
          builder: (context, weatherProvider, _) {
            final unreadCount = weatherProvider.unreadAlertCount;

            return BottomNavigationBar(
              currentIndex:
                  _selectedIndex + 1, // Adjust for Home button (add 1)
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF667EEA),
              unselectedItemColor: Colors.white54,
              onTap: (index) {
                if (index == 0) {
                  // Home button - navigate to home and go to first page
                  goToHome();
                } else {
                  // Adjust tab index: remove Home (0) and map to IndexedStack
                  setState(() {
                    _selectedIndex = index - 1;
                  });
                }
              },
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
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
