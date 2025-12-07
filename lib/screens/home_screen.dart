import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../models/weather_model.dart';
import '../widgets/weather_card.dart';
import '../widgets/forecast_card.dart';
import '../widgets/sun_arc_widget.dart';
import '../widgets/weather_details.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/skeleton_loader.dart';
import '../services/favorites_service.dart';
import '../services/weather_service.dart';
import '../services/push_notification_service.dart';
import '../utils/theme_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  static _HomeScreenState? _instance;

  static void goToHome() {
    _instance?._goToFirstPage();
  }

  /// Navigate to a specific favorite by city name
  static void goToFavorite(String cityName) {
    _instance?._navigateToFavoriteCard(cityName);
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  final WeatherService _weatherService = WeatherService();

  bool _isFavorite = false;
  List<Map<String, dynamic>> _favorites = [];
  int _currentPage = 0;
  String? _initialLocationCity;
  String? _initialLocationCountry;
  WeatherData? _cachedInitialWeather;
  bool _isAnimatingToPage =
      false; // Flag to prevent intermediate fetches during animation
  bool _isLocationGPSBased =
      true; // True if current location is from GPS, false if searched
  bool _checkingFavorite = false; // Prevent duplicate _checkFavorite calls

  // Search autocomplete
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  // Location refresh timer - refreshes every 30 seconds when on main card
  Timer? _locationRefreshTimer;

  // Easter egg: tap counter to show FCM token
  int _appNameTapCount = 0;
  Timer? _tapResetTimer;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    HomeScreen._instance = this;

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<WeatherProvider>()
          .fetchWeatherByLocation()
          .timeout(const Duration(seconds: 15))
          .then((_) {
        if (mounted) {
          final provider = context.read<WeatherProvider>();
          setState(() {
            _initialLocationCity = provider.cityName;
            _initialLocationCountry = provider.countryCode;
            _cachedInitialWeather = provider.weatherData;
          });
          _fadeController.forward();
          _slideController.forward();
        }
      }).catchError((e) {
        print('⚠️ Error fetching location: $e');
        if (mounted) {
          final provider = context.read<WeatherProvider>();
          setState(() {
            _initialLocationCity = provider.cityName;
            _initialLocationCountry = provider.countryCode;
            _cachedInitialWeather = provider.weatherData;
          });
          _fadeController.forward();
          _slideController.forward();
        }
      });
    });

    // Start 30-second location refresh timer
    _startLocationRefreshTimer();
  }

  /// Start timer to refresh location every 30 seconds when on main card (index 0)
  void _startLocationRefreshTimer() {
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) {
      // Only refresh if on the main card AND location is GPS-based (not searched)
      if (_currentPage == 0 && mounted && _isLocationGPSBased) {
        print('🔄 [30s Timer] Refreshing current location...');
        final provider = context.read<WeatherProvider>();
        provider.fetchWeatherByLocation().then((_) {
          if (mounted) {
            setState(() {
              _initialLocationCity = provider.cityName;
              _initialLocationCountry = provider.countryCode;
              _cachedInitialWeather = provider.weatherData;
            });
          }
        }).catchError((e) {
          print('⚠️ [30s Timer] Refresh failed: $e');
        });
      }
    });
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _tapResetTimer?.cancel();
    _searchController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.length < 2) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await _weatherService.getPlaceSuggestions(query);
      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    });
  }

  void _onSuggestionTap(Map<String, dynamic> suggestion) async {
    final placeId = suggestion['placeId'] as String? ?? '';
    final mainText = suggestion['mainText'] as String? ?? '';

    // Close dropdown immediately and clear state
    setState(() {
      _showSuggestions = false;
      _searchSuggestions = [];
    });

    // Unfocus keyboard first
    FocusScope.of(context).unfocus();

    // Clear search text
    _searchController.clear();
    _isLocationGPSBased = false;

    // Navigate back to main card (index 0) when searching
    if (_currentPage != 0 && _pageController.hasClients) {
      setState(() => _currentPage = 0);
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Capture provider before async gap to avoid BuildContext warning
    final provider = context.read<WeatherProvider>();

    // Use place_id to get accurate coordinates for specific locations
    // This ensures "Model Town Lahore" gets precise coordinates, not just "Lahore"
    if (placeId.isNotEmpty) {
      final placeDetails = await _weatherService.getPlaceDetails(placeId);
      if (!mounted) return;
      if (placeDetails != null) {
        print('📍 [Search] Using precise coordinates for: $mainText');
        provider.fetchWeatherByCoordinates(
          placeDetails['latitude'],
          placeDetails['longitude'],
          cityName: mainText,
          countryCode: placeDetails['country'] ?? '',
        );
        return;
      }
    }

    // Fallback to city name search if place details fail
    provider.fetchWeatherByCity(mainText);
  }

  Future<void> _loadFavorites() async {
    final favoritesService = context.read<FavoritesService>();
    final favorites = await favoritesService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favorites;
      });
    }
  }

  void _searchCity() {
    if (_searchController.text.isNotEmpty) {
      // Mark as searched location, not GPS-based (disables auto-refresh)
      _isLocationGPSBased = false;

      // Navigate back to main card (index 0) when searching
      if (_currentPage != 0 && _pageController.hasClients) {
        setState(() => _currentPage = 0);
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      context
          .read<WeatherProvider>()
          .fetchWeatherByCity(_searchController.text);
      FocusScope.of(context).unfocus();
    }
  }

  /// Easter egg: Tap app name 5 times to show FCM token
  void _onAppNameTap() {
    _tapResetTimer?.cancel();
    _appNameTapCount++;

    // Reset counter after 2 seconds of no taps
    _tapResetTimer = Timer(const Duration(seconds: 2), () {
      _appNameTapCount = 0;
    });

    // Show FCM token after 5 taps
    if (_appNameTapCount >= 5) {
      _appNameTapCount = 0;
      _showFCMTokenDialog();
    }
  }

  /// Show FCM token in a dialog with copy option
  Future<void> _showFCMTokenDialog() async {
    final token = await PushNotificationService.getStoredFCMToken();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key, color: Color(0xFF667EEA)),
            SizedBox(width: 8),
            Text(
              'FCM Token',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                token ?? 'No token found',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          if (token != null)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('FCM Token copied to clipboard'),
                    backgroundColor: const Color(0xFF667EEA),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: const Text('Copy',
                  style: TextStyle(color: Color(0xFF667EEA))),
            ),
        ],
      ),
    );
  }

  void _toggleFavorite() {
    final provider = context.read<WeatherProvider>();
    final favoritesService = context.read<FavoritesService>();

    // 🚀 Update UI immediately (optimistic update)
    setState(() => _isFavorite = !_isFavorite);

    // 🔔 Save to storage in background (non-blocking)
    if (_isFavorite) {
      favoritesService.addFavorite(provider.cityName, provider.countryCode);
      print('✅ [HomeScreen] Added favorite: ${provider.cityName}');
    } else {
      favoritesService.removeFavorite(provider.cityName, provider.countryCode);
      print('❌ [HomeScreen] Removed favorite: ${provider.cityName}');
    }

    // 🔄 Reload favorites list to keep in sync
    _loadFavorites();
  }

  /// Check if two city names likely refer to the same area
  /// Handles neighborhoods within major cities (e.g., Samanabad in Lahore)
  bool _isSameCityArea(String providerCity, String cardCity) {
    // Pakistan major cities and their neighborhoods/areas
    const cityAreas = {
      'lahore': [
        'samanabad',
        'model town',
        'gulberg',
        'dha',
        'johar town',
        'iqbal town',
        'allama iqbal town',
        'garden town',
        'faisal town',
        'township',
        'cantt',
        'cantonment',
        'bahria',
        'wapda town',
        'valencia',
        'raiwind'
      ],
      'karachi': [
        'dha',
        'clifton',
        'gulshan',
        'nazimabad',
        'north nazimabad',
        'korangi',
        'malir',
        'saddar',
        'bahria',
        'pechs',
        'tariq road'
      ],
      'islamabad': [
        'f-6',
        'f-7',
        'f-8',
        'f-10',
        'f-11',
        'g-6',
        'g-7',
        'g-8',
        'g-9',
        'g-10',
        'g-11',
        'i-8',
        'i-9',
        'i-10',
        'e-7',
        'e-11',
        'dha',
        'bahria',
        'blue area'
      ],
      'rawalpindi': [
        'saddar',
        'cantt',
        'cantonment',
        'chaklala',
        'satellite town',
        'bahria',
        'commercial market'
      ],
      'faisalabad': [
        'dha',
        'peoples colony',
        'madina town',
        'ghulam muhammad abad'
      ],
      'multan': ['dha', 'cantt', 'cantonment', 'bosan road'],
      'peshawar': ['hayatabad', 'university town', 'cantt', 'cantonment'],
    };

    // Find which major city each location belongs to
    String? providerMajorCity;
    String? cardMajorCity;

    for (final entry in cityAreas.entries) {
      final majorCity = entry.key;
      final areas = entry.value;

      // Check if providerCity is this major city or one of its areas
      if (providerCity.contains(majorCity)) {
        providerMajorCity = majorCity;
      } else {
        for (final area in areas) {
          if (providerCity.contains(area)) {
            providerMajorCity = majorCity;
            break;
          }
        }
      }

      // Check if cardCity is this major city or one of its areas
      if (cardCity.contains(majorCity)) {
        cardMajorCity = majorCity;
      } else {
        for (final area in areas) {
          if (cardCity.contains(area)) {
            cardMajorCity = majorCity;
            break;
          }
        }
      }
    }

    // If both belong to the same major city, they're in the same area
    if (providerMajorCity != null && cardMajorCity != null) {
      return providerMajorCity == cardMajorCity;
    }

    return false;
  }

  Future<void> _checkFavorite() async {
    // Prevent duplicate checks
    if (_checkingFavorite) return;
    _checkingFavorite = true;

    final provider = context.read<WeatherProvider>();
    final favoritesService = context.read<FavoritesService>();
    final isFav = await favoritesService.isFavorite(
        provider.cityName, provider.countryCode);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
    _checkingFavorite = false;
  }

  Future<void> _navigateToLocationAsync(String cityName) async {
    // 💾 Get context references before async gap
    final provider = context.read<WeatherProvider>();

    // Always fetch fresh data when swiping to a favorite
    await provider.fetchWeatherByCity(cityName);
  }

  void _restoreInitialLocation(WeatherProvider provider) {
    if (_cachedInitialWeather != null && _initialLocationCity != null) {
      provider.restoreCachedWeather(
        _cachedInitialWeather!,
        _initialLocationCity!,
        _initialLocationCountry ?? '',
      );
    }
  }

  /// Go to the first page (current location)
  void _goToFirstPage() {
    final provider = context.read<WeatherProvider>();

    // Clear search field and suggestions
    _searchController.clear();
    setState(() {
      _showSuggestions = false;
      _searchSuggestions = [];
      // Update _currentPage immediately so card shows at full opacity
      _currentPage = 0;
    });

    // Mark as GPS-based location (enables auto-refresh)
    _isLocationGPSBased = true;

    // Immediately restore cached data for instant UI response
    _restoreInitialLocation(provider);

    // Animate to page 0
    if (_pageController.hasClients && _pageController.page != 0) {
      // Set flag to prevent intermediate page fetches
      _isAnimatingToPage = true;

      _pageController
          .animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _isAnimatingToPage = false;
      });
    }

    // Fetch fresh data in background (includes AQI)
    _fetchFreshCurrentLocation(provider);
  }

  /// Fetch fresh data for current location
  Future<void> _fetchFreshCurrentLocation(WeatherProvider provider) async {
    if (_initialLocationCity != null) {
      print(
          '🔄 [HomeScreen] Fetching fresh data for current location: $_initialLocationCity');
      await provider.fetchWeatherByCity(_initialLocationCity!);

      // Update cached data with fresh data
      if (mounted && provider.weatherData != null) {
        setState(() {
          _cachedInitialWeather = provider.weatherData;
        });
      }
    }
  }

  /// Navigate to a specific favorite card by city name
  void _navigateToFavoriteCard(String cityName) {
    // Find the index of this favorite
    int favoriteIndex = -1;
    for (int i = 0; i < _favorites.length; i++) {
      if ((_favorites[i]['city'] as String).toLowerCase() ==
          cityName.toLowerCase()) {
        favoriteIndex = i;
        break;
      }
    }

    if (favoriteIndex >= 0 && _pageController.hasClients) {
      final targetPage = favoriteIndex + 1;
      print(
          '🎯 [HomeScreen] Navigating to favorite card: $cityName at index $targetPage');

      // Set flag to prevent onPageChanged from fetching during animation
      _isAnimatingToPage = true;

      // Update current page BEFORE animation to prevent duplicate fetches
      setState(() => _currentPage = targetPage);

      // Animate to the favorite card (index + 1 because 0 is current location)
      _pageController
          .animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      )
          .then((_) {
        // Clear flag after animation completes
        _isAnimatingToPage = false;
      });
    } else {
      print(
          '⚠️ [HomeScreen] Could not find favorite: $cityName in $_favorites');
    }
  }

  /// Navigate to a favorite location and auto-swipe to its card
  Future<void> navigateToFavorite(String cityName) async {
    final provider = context.read<WeatherProvider>();

    // Find the index of this favorite in the list
    int favoriteIndex = -1;
    for (int i = 0; i < _favorites.length; i++) {
      if ((_favorites[i]['city'] as String).toLowerCase() ==
          cityName.toLowerCase()) {
        favoriteIndex = i;
        break;
      }
    }

    if (favoriteIndex >= 0) {
      // Always fetch fresh weather data
      print('🔄 [HomeScreen] Fetching fresh data for $cityName');
      await provider.fetchWeatherByCity(cityName);

      // Auto-swipe to the favorite card (index + 1 because index 0 is current location)
      if (mounted) {
        print(
            '📱 [HomeScreen] Auto-swiping to favorite at index ${favoriteIndex + 1}');
        await _pageController.animateToPage(
          favoriteIndex + 1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get isDay from provider for dynamic theme
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final isDay = weatherProvider.weatherData?.current.isDay ?? true;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: WeatherTheme.getBackgroundGradient(isDay),
        ),
        child: SafeArea(
          child: Consumer2<WeatherProvider, FavoritesService>(
            builder: (context, provider, favoritesService, child) {
              // Update favorites from the service whenever it changes
              if (favoritesService.favorites.length != _favorites.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _favorites = favoritesService.favorites;
                    });
                  }
                });
              }

              // Auto-swipe to favorite if it was selected from FavoritesScreen
              // Use addPostFrameCallback to avoid setState during build
              if (provider.weatherData != null && !provider.isLoading) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _checkFavorite();
                });
              }

              if (provider.isLoading && provider.weatherData == null) {
                return _buildLoadingState();
              }

              if (provider.error != null) {
                return _buildErrorState(provider);
              }

              if (provider.weatherData == null) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 80),
                        const WeatherSkeletonCard(),
                        const SizedBox(height: 24),
                        SkeletonLoader(
                          height: 100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(height: 24),
                        SkeletonLoader(
                          height: 200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final weather = provider.weatherData!;
              final current = weather.current;

              // Check if we're loading a favorite location (showing stale data while fetching)
              final isLoadingFavorite = provider.isLoading && _currentPage > 0;

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Stack(
                    children: [
                      // Fade out content when loading a new favorite
                      Opacity(
                        opacity: isLoadingFavorite ? 0.4 : 1.0,
                        child: RefreshIndicator(
                          onRefresh: () async {
                            if (_currentPage == 0) {
                              await provider.fetchWeatherByLocation();
                              if (mounted) {
                                setState(() {
                                  _initialLocationCity = provider.cityName;
                                  _initialLocationCountry =
                                      provider.countryCode;
                                  _cachedInitialWeather = provider.weatherData;
                                });
                              }
                            } else {
                              await provider.refresh();
                            }
                          },
                          color: Colors.white,
                          backgroundColor: const Color(0xFF1e3c72),
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              _buildGlassAppBar(provider),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 16),
                                      _buildGlassSearchBar(),
                                      const SizedBox(height: 24),
                                      _buildWeatherCardsSection(
                                          provider, current, weather),
                                      const SizedBox(height: 24),
                                      if (provider.usingMetar) ...[
                                        _buildGlassMetarBadge(provider),
                                        const SizedBox(height: 24),
                                      ],
                                      if (weather.aqiIndex != null)
                                        _buildAQICard(weather.aqiIndex!),
                                      const SizedBox(height: 24),
                                      HourlyForecast(
                                        weatherData: weather,
                                      ),
                                      const SizedBox(height: 24),
                                      if (weather.forecast.isNotEmpty)
                                        SunArcWidget(
                                          sunrise: weather.forecast[0].sunrise,
                                          sunset: weather.forecast[0].sunset,
                                        ),
                                      const SizedBox(height: 24),
                                      WeatherDetails(current: current),
                                      const SizedBox(height: 24),
                                      ...weather.forecast
                                          .map((day) => Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 12),
                                                child:
                                                    ForecastCard(forecast: day),
                                              ))
                                          .toList(),
                                      const SizedBox(height: 40),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Show loading overlay when fetching favorite location data
                      if (isLoadingFavorite)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Padding(
                            padding: EdgeInsets.all(20),
                            child: WeatherSkeletonCard(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    // Use skeleton loader instead of spinner
    return const Padding(
      padding: EdgeInsets.all(20),
      child: WeatherSkeletonCard(),
    );
  }

  Widget _buildErrorState(WeatherProvider provider) {
    // Show actual error message instead of misleading "Retrying..."
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Error icon
          Icon(
            Icons.location_off_rounded,
            size: 60,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Unable to find location',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.error ?? 'Please check the spelling and try again',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 32),
          // Try again button
          ElevatedButton.icon(
            onPressed: () {
              // Clear search field to reset UI
              _searchController.clear();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Another City'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAppBar(WeatherProvider provider) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: _onAppNameTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF667EEA),
                  Color(0xFF64B5F6),
                  Color(0xFF81D4FA)
                ],
              ).createShader(bounds),
              child: const Text(
                'Sky',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFF6B6B),
                  Color(0xFFFF8E53),
                  Color(0xFFFECE47)
                ],
              ).createShader(bounds),
              child: const Text(
                'Pulse',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Favorite button with animation
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _isFavorite ? 1.2 : 1.0),
          duration: const Duration(milliseconds: 200),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.redAccent : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.my_location, color: Colors.white),
          onPressed: () => provider.fetchWeatherByLocation(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildGlassSearchBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search city...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    onPressed: _searchCity,
                  ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) {
                  setState(() => _showSuggestions = false);
                  _searchCity();
                },
              ),
            ),
          ),
        ),
        if (_showSuggestions && _searchSuggestions.isNotEmpty)
          _buildSuggestionsDropdown(),
      ],
    );
  }

  Widget _buildSuggestionsDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _searchSuggestions.take(5).map((suggestion) {
              return InkWell(
                onTap: () => _onSuggestionTap(suggestion),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion['mainText'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if ((suggestion['secondaryText'] ?? '').isNotEmpty)
                              Text(
                                suggestion['secondaryText'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCardsSection(WeatherProvider provider,
      CurrentWeather currentWeather, WeatherData weather) {
    if (_favorites.isEmpty) {
      return WeatherCard(
        cityName: provider.cityName,
        countryCode: provider.countryCode,
        current: currentWeather,
      );
    }

    return SizedBox(
      height: 130,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) async {
              // Skip if already on this page (happens when programmatically navigating)
              if (index == _currentPage) return;

              // Skip fetching during programmatic animation (intermediate pages)
              if (_isAnimatingToPage) return;

              final previousPage = _currentPage;
              setState(() => _currentPage = index);

              // Only fetch data when SWIPING to a favorite card (index > 0)
              // This handles manual swipe gestures
              if (index > 0 && index - 1 < _favorites.length) {
                final favorite = _favorites[index - 1];
                final cityName = favorite['city'] as String;

                // Flexible city name matching (first word comparison)
                final providerCity = provider.cityName.toLowerCase().trim();
                final cardCity = cityName.toLowerCase().trim();
                final providerFirstWord =
                    providerCity.split(RegExp(r'[\s,.]+')).first;
                final cardFirstWord = cardCity.split(RegExp(r'[\s,.]+')).first;

                final isSameCity = providerCity == cardCity ||
                    providerCity.contains(cardCity) ||
                    cardCity.contains(providerCity) ||
                    providerFirstWord == cardFirstWord ||
                    _isSameCityArea(providerCity, cardCity);

                // Only fetch if we're not already showing this city's data
                if (!isSameCity) {
                  await _navigateToLocationAsync(cityName);
                }
              } else if (index == 0 && previousPage > 0) {
                // Swiped back to current location (index 0)
                _restoreInitialLocation(provider);
                // Fetch fresh data in background
                _fetchFreshCurrentLocation(provider);
              }
            },
            itemCount: _favorites.length + 1,
            itemBuilder: (context, index) {
              final isActive = index == _currentPage;

              return AnimatedPadding(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: isActive ? 8.0 : 24.0,
                  vertical: isActive ? 0.0 : 12.0,
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isActive ? 1.0 : 0.6,
                  child: index == 0
                      ? // Current location card
                      WeatherCard(
                          cityName: provider.cityName,
                          countryCode: provider.countryCode,
                          current: currentWeather,
                        )
                      : // Favorite location cards
                      _buildGlassFavoriteCard(
                          _favorites[index - 1]['city'] as String,
                          _favorites[index - 1]['country'] as String,
                          isActive: isActive,
                        ),
                ),
              );
            },
          ),
          if (_favorites.isNotEmpty)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: _buildPageIndicators(_favorites.length + 1),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassFavoriteCard(String cityName, String countryCode,
      {bool isActive = false}) {
    // When active, wrap with Consumer to listen for updates
    if (isActive) {
      return Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          // ACTIVE CARD: Show whatever data is available
          // The fetch was already triggered when navigating to this card
          // No need for strict city matching - just show the data!
          final current = provider.weatherData?.current;

          if (current != null && !provider.isLoading) {
            // Show data-loaded state with FULL weather info
            // Use the card's cityName for display, provider's data for weather
            return _buildFavoriteCachedCard(cityName, countryCode, current);
          }
          // Show loading state if still loading
          return _buildFavoriteLoadingCard(cityName, countryCode);
        },
      );
    }

    // When inactive, just show glass card with skeleton shimmer
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.withOpacity(0.3),
                Colors.purple.withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Skeleton shimmer instead of spinner
              SkeletonLoader(
                width: 28,
                height: 28,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 6),
              Text(
                cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (countryCode.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  countryCode,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24.0 : 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildGlassMetarBadge(WeatherProvider provider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4CAF50).withOpacity(0.3),
                const Color(0xFF2E7D32).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Airport Weather (METAR)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.metarData?.icaoCode ?? 'Airport Data',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build AQI (Air Quality Index) card
  Widget _buildAQICard(int aqi) {
    Color aqiColor;
    String aqiStatus;

    if (aqi <= 50) {
      aqiColor = const Color(0xFF4CAF50); // Good
      aqiStatus = 'Good';
    } else if (aqi <= 100) {
      aqiColor = const Color(0xFFFFC107); // Moderate
      aqiStatus = 'Moderate';
    } else if (aqi <= 150) {
      aqiColor = const Color(0xFFFF9800); // Unhealthy for Sensitive Groups
      aqiStatus = 'Unhealthy for Sensitive';
    } else if (aqi <= 200) {
      aqiColor = const Color(0xFFF44336); // Unhealthy
      aqiStatus = 'Unhealthy';
    } else if (aqi <= 300) {
      aqiColor = const Color(0xFF9C27B0); // Very Unhealthy
      aqiStatus = 'Very Unhealthy';
    } else {
      aqiColor = const Color(0xFF8B0000); // Hazardous
      aqiStatus = 'Hazardous';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            aqiColor.withOpacity(0.3),
            aqiColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: aqiColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Air Quality Index',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                aqiStatus,
                style: TextStyle(
                  color: aqiColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aqiColor.withOpacity(0.2),
              border: Border.all(
                color: aqiColor,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                aqi.toString(),
                style: TextStyle(
                  color: aqiColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a favorite card showing full weather data (icon, temp, description, humidity, wind, pressure)
  Widget _buildFavoriteCachedCard(
      String cityName, String countryCode, CurrentWeather current) {
    // Calculate feels like temperature
    final feelsLike = current.temperature -
        ((current.windSpeed / 10) * 2) -
        ((100 - current.humidity) / 20);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Weather icon
              Text(
                current.weatherIcon,
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(width: 12),

              // Center: City, Temp & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // City name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cityName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (countryCode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              countryCode,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Temp & Description
                    Text(
                      '${current.temperature.round()}° • ${current.weatherDescription}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Feels like
                    Text(
                      'Feels ${feelsLike.round()}°C',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right: Quick stats (humidity, wind, pressure)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.opacity,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.humidity.round()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.air, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.windSpeed.round()} km/h',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.compress,
                          size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.pressure.round()}hPa',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a favorite card showing loading spinner
  Widget _buildFavoriteLoadingCard(String cityName, String countryCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Loading weather icon placeholder - pulsing animation
              _buildPulsingLoader(size: 36),
              const SizedBox(width: 12),

              // Center: City info + loading placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // City name (always visible)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cityName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (countryCode.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              countryCode,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Loading text
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Loading weather...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right side: Loading indicator dots
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShimmerBar(width: 40, height: 10),
                  const SizedBox(height: 4),
                  _buildShimmerBar(width: 50, height: 10),
                  const SizedBox(height: 4),
                  _buildShimmerBar(width: 45, height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingLoader({required double size}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15 * value),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.cloud_outlined,
              color: Colors.white.withOpacity(0.4 * value),
              size: size * 0.6,
            ),
          ),
        );
      },
      onEnd: () {
        // Re-trigger animation would need stateful widget
      },
    );
  }

  Widget _buildShimmerBar({required double width, required double height}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.2, end: 0.5),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(value),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
