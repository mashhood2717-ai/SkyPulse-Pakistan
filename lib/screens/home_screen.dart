import 'dart:ui';
import 'dart:async';
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
import '../services/weather_service.dart';

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
  bool _isAnimatingToPage = false; // Flag to prevent intermediate fetches during animation

  // Search autocomplete
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  // Location refresh timer - refreshes every 30 seconds when on main card
  Timer? _locationRefreshTimer;

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
    _locationRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Only refresh if on the main card (current location, index 0)
      if (_currentPage == 0 && mounted) {
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

  void _onSuggestionTap(Map<String, dynamic> suggestion) {
    final mainText = suggestion['mainText'] as String? ?? '';
    _searchController.text = mainText;
    setState(() {
      _showSuggestions = false;
      _searchSuggestions = [];
    });
    _searchCity();
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

    // Always fetch fresh data when swiping to a favorite
    print('🔄 [HomeScreen] Fetching fresh data for $cityName');
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
    
    // Immediately restore cached data for instant UI response
    _restoreInitialLocation(provider);

    // Animate to page 0
    if (_currentPage != 0 && _pageController.hasClients) {
      // Set flag to prevent intermediate page fetches
      _isAnimatingToPage = true;
      
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
        _isAnimatingToPage = false;
      });
    }
    
    // Fetch fresh data in background (includes AQI)
    _fetchFreshCurrentLocation(provider);
  }
  
  /// Fetch fresh data for current location
  Future<void> _fetchFreshCurrentLocation(WeatherProvider provider) async {
    if (_initialLocationCity != null) {
      print('🔄 [HomeScreen] Fetching fresh data for current location: $_initialLocationCity');
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
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      ).then((_) {
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
                                        child: const CircularProgressIndicator(
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
              if (index == _currentPage) {
                print('📱 [HomeScreen] Already on page $index, skipping fetch');
                return;
              }
              
              // Skip fetching during programmatic animation (intermediate pages)
              if (_isAnimatingToPage) {
                print('📱 [HomeScreen] Skipping intermediate page $index during animation');
                return;
              }

              final previousPage = _currentPage;
              setState(() => _currentPage = index);

              // Only fetch data when SWIPING to a favorite card (index > 0)
              // This handles manual swipe gestures
              if (index > 0 && index - 1 < _favorites.length) {
                final favorite = _favorites[index - 1];
                final cityName = favorite['city'] as String;

                // Only fetch if we're not already showing this city's data
                if (provider.cityName.toLowerCase() != cityName.toLowerCase()) {
                  print('📱 [HomeScreen] Swiped to favorite: $cityName');
                  await _navigateToLocationAsync(cityName);
                } else {
                  print('📱 [HomeScreen] Already showing $cityName data');
                }
              } else if (index == 0 && previousPage > 0) {
                // Swiped back to current location (index 0)
                print('📱 [HomeScreen] Swiped back to current location');
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
          // Show full weather info ONLY if data loaded AND it matches this city
          final current = provider.weatherData?.current;
          final isCorrectCity = provider.cityName.toLowerCase() == cityName.toLowerCase();
          
          if (current != null && !provider.isLoading && isCorrectCity) {
            // Show data-loaded state with FULL weather info
            return _buildFavoriteCachedCard(cityName, countryCode, current);
          }
          // Show loading state if still loading or data is for wrong city
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
                      const Icon(Icons.opacity, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.humidity.round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.air, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.windSpeed.round()} km/h',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.compress, size: 11, color: Colors.white70),
                      const SizedBox(width: 3),
                      Text('${current.pressure.round()}hPa',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
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
