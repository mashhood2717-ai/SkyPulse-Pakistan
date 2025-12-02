import 'dart:ui';
import 'package:flutter/material.dart';
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
import '../services/favorites_cache_service.dart' show FavoritesCacheService;

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

  bool _isFavorite = false;
  List<Map<String, dynamic>> _favorites = [];
  int _currentPage = 0;
  String? _initialLocationCity;
  String? _initialLocationCountry;
  WeatherData? _cachedInitialWeather;

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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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
      context
          .read<WeatherProvider>()
          .fetchWeatherByCity(_searchController.text);
      FocusScope.of(context).unfocus();
    }
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

  Future<void> _checkFavorite() async {
    final provider = context.read<WeatherProvider>();
    final favoritesService = context.read<FavoritesService>();
    final isFav = await favoritesService.isFavorite(
        provider.cityName, provider.countryCode);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _navigateToLocationAsync(String cityName) async {
    // 💾 Get context references before async gap
    final provider = context.read<WeatherProvider>();
    final cacheService = context.read<FavoritesCacheService>();

    // Check if we're already showing this city - if so, don't re-fetch
    if (provider.cityName.toLowerCase() == cityName.toLowerCase() &&
        !provider.isLoading) {
      print('✅ [HomeScreen] Already showing $cityName, skipping fetch');
      return;
    }

    // Try to load from cache first (faster, no network delay)
    bool shouldFetchFresh = true;
    if (cacheService.hasCachedWeather(cityName)) {
      final cachedWeather = cacheService.getWeatherForCity(cityName);
      if (cachedWeather != null) {
        print('📦 [HomeScreen] Restoring $cityName from cache');
        provider.restoreCachedWeather(
          cachedWeather,
          cityName,
          cacheService.getMetadata(cityName)?['countryCode'] as String? ?? '',
        );
        shouldFetchFresh = true; // Still fetch fresh data in background
      }
    }

    // Fetch fresh data (either no cache or to update stale cache)
    if (shouldFetchFresh) {
      await provider.fetchWeatherByCity(cityName);

      if (provider.weatherData != null) {
        cacheService.cacheWeather(
          cityName,
          provider.weatherData!,
          country: provider.cityName,
          countryCode: provider.countryCode,
        );
      }
    }
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
    if (_currentPage != 0 && _pageController.hasClients) {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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
      print(
          '🎯 [HomeScreen] Navigating to favorite card: $cityName at index ${favoriteIndex + 1}');
      // Animate to the favorite card (index + 1 because 0 is current location)
      _pageController.animateToPage(
        favoriteIndex + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Navigate to a favorite location and auto-swipe to its card
  Future<void> navigateToFavorite(String cityName) async {
    final provider = context.read<WeatherProvider>();
    final cacheService = context.read<FavoritesCacheService>();

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
      // Load the weather data
      if (cacheService.hasCachedWeather(cityName)) {
        final cachedWeather = cacheService.getWeatherForCity(cityName);
        if (cachedWeather != null) {
          print('📱 [HomeScreen] Loading $cityName from cache');
          provider.restoreCachedWeather(
            cachedWeather,
            cityName,
            cacheService.getMetadata(cityName)?['countryCode'] as String? ?? '',
          );
        }
      } else {
        await provider.fetchWeatherByCity(cityName);
      }

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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1e3c72),
              const Color(0xFF2a5298),
              const Color(0xFF1e3c72).withOpacity(0.9),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
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
              if (provider.weatherData != null && !provider.isLoading) {
                _checkFavorite();
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
                        WeatherSkeletonCard(),
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
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 1500),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: 0.8 + (value * 0.2),
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.3),
                                              Colors.blue.withOpacity(0.5),
                                            ],
                                          ),
                                        ),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading weather data...',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading indicator
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Loading weather data...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WeatherProvider provider) {
    // Instead of showing error screen, show a small rotating circle
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Small rotating circle
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              color: Colors.white.withOpacity(0.8),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Retrying...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w400,
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
    return ClipRRect(
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
            onSubmitted: (_) => _searchCity(),
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
              if (index == _currentPage) return;

              final previousPage = _currentPage;
              setState(() => _currentPage = index);

              // Only navigate to favorite if swiping to a favorite card (index > 0)
              if (index > 0 && index - 1 < _favorites.length) {
                final favorite = _favorites[index - 1];
                print(
                    '📱 [HomeScreen] Navigating to favorite: ${favorite['city']}');
                await _navigateToLocationAsync(favorite['city'] as String);
              } else if (index == 0 && previousPage > 0) {
                // Swiped back to current location (index 0)
                print('📱 [HomeScreen] Restoring initial location');
                _restoreInitialLocation(provider);
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
          // Show temp if data loaded and not currently loading
          final current = provider.weatherData?.current;
          if (current != null && !provider.isLoading) {
            final temp = current.temperature;
            // Show data-loaded state
            return _buildFavoriteCachedCard(
                cityName, countryCode, temp.toString());
          }
          // Show loading state
          return _buildFavoriteLoadingCard(cityName, countryCode);
        },
      );
    }

    // When inactive, just show glass card with city name
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
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
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

  /// Build a favorite card showing cached temperature data
  Widget _buildFavoriteCachedCard(
      String cityName, String countryCode, String temp) {
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
              Text(
                '$temp°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
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
              // Skeleton temperature placeholder with shimmer effect
              _buildSkeletonLoader(width: 32, height: 28),
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

  Widget _buildSkeletonLoader({required double width, required double height}) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.1),
          ],
          stops: const [0.0, 0.5, 1.0],
          transform: GradientRotation(
            DateTime.now().millisecondsSinceEpoch / 1000.0 * 2.0,
          ),
        ).createShader(bounds);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
