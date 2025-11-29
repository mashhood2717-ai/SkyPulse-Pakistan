import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../models/weather_model.dart';
import '../widgets/weather_card.dart';
import '../widgets/forecast_card.dart';
import '../widgets/sun_arc_widget.dart';
import '../widgets/weather_details.dart';
import '../widgets/hourly_forecast.dart';
import '../widgets/alert_widgets.dart';
import 'favorites_screen.dart';
import '../services/favorites_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FavoritesService _favoritesService = FavoritesService();
  final PageController _pageController = PageController();

  bool _isFavorite = false;
  List<Map<String, dynamic>> _favorites = [];
  int _currentPage = 0;
  String? _initialLocationCity;
  String? _initialLocationCountry;
  WeatherData? _cachedInitialWeather;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<WeatherProvider>().fetchWeatherByLocation();
      if (mounted) {
        final provider = context.read<WeatherProvider>();
        setState(() {
          _initialLocationCity = provider.cityName;
          _initialLocationCountry = provider.countryCode;
          _cachedInitialWeather = provider.weatherData;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesService.getFavorites();
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

  void _toggleFavorite() async {
    final provider = context.read<WeatherProvider>();
    if (_isFavorite) {
      await _favoritesService.removeFavorite(
          provider.cityName, provider.countryCode);
    } else {
      await _favoritesService.addFavorite(
          provider.cityName, provider.countryCode);
    }
    setState(() => _isFavorite = !_isFavorite);
    await _loadFavorites();
  }

  Future<void> _checkFavorite() async {
    final provider = context.read<WeatherProvider>();
    final isFav = await _favoritesService.isFavorite(
        provider.cityName, provider.countryCode);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  void _navigateToLocation(String cityName) {
    context.read<WeatherProvider>().fetchWeatherByCity(cityName);
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

  void _goToHome() {
    if (_currentPage != 0) {
      _pageController.animateToPage(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
            colors: [Color(0xFF1e3c72), Color(0xFF2a5298)],
          ),
        ),
        child: SafeArea(
          child: Consumer<WeatherProvider>(
            builder: (context, provider, child) {
              if (provider.weatherData != null && !provider.isLoading) {
                _checkFavorite();
              }

              if (provider.isLoading && provider.weatherData == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Loading weather data...',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 60, color: Colors.white70),
                      const SizedBox(height: 16),
                      const Text('Error loading weather',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(provider.error!,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                          onPressed: () => provider.fetchWeatherByLocation(),
                          child: const Text('Retry')),
                    ],
                  ),
                );
              }

              if (provider.weatherData == null) {
                return const Center(
                    child: Text('No weather data available',
                        style: TextStyle(color: Colors.white, fontSize: 18)));
              }

              final weather = provider.weatherData!;
              final current = weather.current;

              return RefreshIndicator(
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
                  slivers: [
                    SliverAppBar(
                      floating: true,
                      backgroundColor: Colors.black26,
                      elevation: 0,
                      iconTheme: const IconThemeData(color: Colors.white),
                      actions: [
                        IconButton(
                            icon: Icon(_isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border),
                            onPressed: _toggleFavorite),
                        IconButton(
                            icon: const Icon(Icons.list),
                            onPressed: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const FavoritesScreen()));
                              await _loadFavorites();
                            }),
                        IconButton(
                            icon: const Icon(Icons.home),
                            tooltip: 'Go to Home',
                            onPressed: _goToHome),
                        IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: () => provider.fetchWeatherByLocation()),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              children: [
                                _buildSearchBar(),
                                const SizedBox(height: 12),
                                // 🚨 ALERTS
                                AlertList(alerts: provider.activeAlerts),
                                if (provider.usingMetar)
                                  const SizedBox(height: 12),
                                if (provider.usingMetar)
                                  _buildMetarBadge(provider),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 🎨 WEATHER CARD TILE
                          _buildWeatherCardsSection(provider, current),
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                HourlyForecast(weatherData: weather),
                                const SizedBox(height: 20),
                                WeatherDetails(current: current),
                                const SizedBox(height: 20),
                                if (weather.forecast.isNotEmpty)
                                  SunArcWidget(
                                      sunrise: weather.forecast[0].sunrise,
                                      sunset: weather.forecast[0].sunset),
                                const SizedBox(height: 20),
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        '${weather.forecast.length}-Day Forecast',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5))),
                                const SizedBox(height: 12),
                                ...weather.forecast
                                    .map((day) => ForecastCard(forecast: day))
                                    .toList(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCardsSection(
      WeatherProvider provider, CurrentWeather currentWeather) {
    if (_favorites.isEmpty) {
      // No favorites - just show single tile card
      return WeatherCard(
          cityName: provider.cityName,
          countryCode: provider.countryCode,
          current: currentWeather);
    }

    // With favorites - use PageView but with reduced height for tile
    return SizedBox(
      height: 130, // Reduced from 340 for tile card
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
              final horizontalPadding = isActive ? 20.0 : 40.0;
              final verticalPadding = isActive ? 0.0 : 15.0;

              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding, vertical: verticalPadding),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isActive ? 1.0 : 0.6,
                    child: WeatherCard(
                        cityName: provider.cityName,
                        countryCode: provider.countryCode,
                        current: currentWeather),
                  ),
                );
              } else {
                final favoriteIndex = index - 1;
                final favorite = _favorites[favoriteIndex];
                return Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding, vertical: verticalPadding),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isActive ? 1.0 : 0.6,
                    child: isActive
                        ? WeatherCard(
                            cityName: provider.cityName,
                            countryCode: provider.countryCode,
                            current: currentWeather)
                        : _buildFavoriteCard(favorite['city'] as String,
                            favorite['country'] as String),
                  ),
                );
              }
            },
          ),
          if (_favorites.isNotEmpty)
            Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: _buildPageIndicators(_favorites.length + 1)),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(String cityName, String countryCode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.08)
            ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_city, color: Colors.white70, size: 32),
          const SizedBox(height: 8),
          Text(cityName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          if (countryCode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(countryCode,
                style: const TextStyle(color: Colors.white70, fontSize: 11))
          ],
        ],
      ),
    );
  }

  Widget _buildPageIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
          count,
          (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 20.0 : 6.0,
              height: 6.0,
              decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3)))),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
      child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
              hintText: 'Search city...',
              hintStyle: const TextStyle(color: Colors.white60),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white70),
                  onPressed: _searchCity)),
          onSubmitted: (_) => _searchCity()),
    );
  }

  Widget _buildMetarBadge(WeatherProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF4CAF50).withOpacity(0.3),
            const Color(0xFF2E7D32).withOpacity(0.3)
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF4CAF50).withOpacity(0.5), width: 2)),
      child: Row(
        children: [
          const Icon(Icons.flight, color: Color(0xFF4CAF50), size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Live Airport Weather (METAR)',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(provider.metarData?.icaoCode ?? 'Airport Data',
                    style: const TextStyle(color: Colors.white70, fontSize: 12))
              ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('LIVE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5))),
        ],
      ),
    );
  }
}
