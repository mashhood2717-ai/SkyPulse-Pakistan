import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/weather_provider.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/alerts_screen.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Initializing Skypulse...');

  // Initialize Firebase FIRST (before push notifications)
  print('🔥 Initializing Firebase...');
  final firebaseInit = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(
    const Duration(seconds: 15),
  );

  // Request notification permissions (Android 13+) - with timeout
  print('📱 Requesting notification permissions...');
  final permissionRequest = Permission.notification.request().timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      print('⚠️ Permission request timeout');
      return PermissionStatus.denied;
    },
  ).then((status) {
    print('📱 Permission status: ${status.isDenied ? "DENIED" : status.isGranted ? "GRANTED" : "OTHER"}');
    if (status.isDenied) {
      print('⚠️ Notification permission denied! Alerts may not work.');
    } else if (status.isGranted) {
      print('✅ Notification permission granted!');
    } else if (status.isPermanentlyDenied) {
      print('⚠️ Notification permission permanently denied! User must enable in settings.');
    }
  });

  // Wait for Firebase to initialize first
  try {
    await firebaseInit;
    print('✅ Firebase initialized successfully!');
  } catch (e) {
    print('❌ Firebase initialization failed (continuing anyway): $e');
  }

  // Now initialize push notifications - NO TIMEOUT (let it complete fully)
  print('🔔 Initializing push notifications...');
  final pushInit = PushNotificationService.initializePushNotifications();

  // Wait for both permission and push notifications in parallel
  try {
    await Future.wait([
      permissionRequest,
      pushInit,
    ]);
    print('✅ All initializations complete!');
  } catch (e) {
    print('⚠️ Some initializations had issues (app will continue): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
      ],
      child: MaterialApp(
        title: 'Skypulse',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Color(0xFF0A0E27),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF1A1F3A),
            elevation: 0,
          ),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFF667EEA),
            secondary: Color(0xFF764BA2),
            surface: Color(0xFF1A1F3A),
            background: Color(0xFF0A0E27),
          ),
        ),
        home: const HomePage(),
        routes: {
          '/favorites': (context) => const FavoritesScreen(),
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
    // Fetch weather on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WeatherProvider>(context, listen: false)
          .fetchWeatherByLocation();
    });
  }

  void switchToWeatherTab() {
    setState(() {
      _selectedIndex = 1;
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
            onFavoriteSelected: switchToWeatherTab,
          ), // Index 2 - Favorites
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1A1F3A).withOpacity(0.7), // Transparent
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
              currentIndex: _selectedIndex,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Color(0xFF667EEA),
              unselectedItemColor: Colors.white54,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
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
                            decoration: BoxDecoration(
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
  final VoidCallback onFavoriteSelected;

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
