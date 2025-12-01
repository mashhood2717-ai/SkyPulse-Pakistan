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
import '../services/favorites_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
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
    await context.read<WeatherProvider>().fetchWeatherByCity(cityName);
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
                return const Center(
                    child: Text('No weather data available',
                        style: TextStyle(color: Colors.white, fontSize: 18)));
              }

              final weather = provider.weatherData!;
              final current = weather.current;

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (_currentPage == 0) {
                        await provider.fetchWeatherByLocation();
                        if (mounted) {
                          setState(() {
                            _initialLocationCity = provider.cityName;
                            _initialLocationCountry = provider.countryCode;
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
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                _buildGlassSearchBar(),
                                const SizedBox(height: 24),
                                _buildWeatherCardsSection(provider, current),
                                const SizedBox(height: 24),
                                if (provider.usingMetar) ...[
                                  _buildGlassMetarBadge(provider),
                                  const SizedBox(height: 24),
                                ],
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
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: ForecastCard(forecast: day),
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

  Widget _buildWeatherCardsSection(
      WeatherProvider provider, CurrentWeather currentWeather) {
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

              if (index > 0 && index - 1 < _favorites.length) {
                final favorite = _favorites[index - 1];
                await _navigateToLocationAsync(favorite['city'] as String);
              } else if (index == 0 && previousPage > 0) {
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
                      ? WeatherCard(
                          cityName: provider.cityName,
                          countryCode: provider.countryCode,
                          current: currentWeather,
                        )
                      : isActive
                          ? WeatherCard(
                              cityName: provider.cityName,
                              countryCode: provider.countryCode,
                              current: currentWeather,
                            )
                          : _buildGlassFavoriteCard(
                              _favorites[index - 1]['city'] as String,
                              _favorites[index - 1]['country'] as String,
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

  Widget _buildGlassFavoriteCard(String cityName, String countryCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
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
              Icon(
                Icons.location_city_rounded,
                color: Colors.white.withOpacity(0.8),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (countryCode.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  countryCode,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
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
}
