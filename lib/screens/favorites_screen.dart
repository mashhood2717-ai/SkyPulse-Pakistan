import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';
import '../services/favorites_cache_service.dart';
import '../providers/weather_provider.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(String)? onLocationSelected;

  const FavoritesScreen({
    Key? key,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _filteredFavorites = [];
  final Map<String, CurrentWeather?> _weatherCache = {};
  bool _isLoading = true;
  bool _isSearching = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _loadFavoritesWithWeather();
    _searchController.addListener(_filterFavorites);

    // 🔔 Listen for favorites changes from FavoritesService
    final favoritesService = context.read<FavoritesService>();
    favoritesService.addListener(_onFavoritesChanged);
  }

  /// Called when FavoritesService notifies changes
  void _onFavoritesChanged() {
    if (mounted) {
      print('🔔 [FavoritesScreen] Favorites changed, reloading...');
      _loadFavoritesWithWeather();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    final favoritesService = context.read<FavoritesService>();
    favoritesService.removeListener(_onFavoritesChanged); // 🔌 Remove listener
    super.dispose();
  }

  void _filterFavorites() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFavorites = List.from(_favorites);
      } else {
        _filteredFavorites = _favorites.where((fav) {
          final city = (fav['city'] as String).toLowerCase();
          final country = (fav['country'] as String).toLowerCase();
          return city.contains(query) || country.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadFavoritesWithWeather() async {
    setState(() => _isLoading = true);
    final favoritesService = context.read<FavoritesService>();
    final favorites = await favoritesService.getFavorites();
    setState(() {
      _favorites = favorites;
      _filteredFavorites = List.from(favorites);
      _isLoading = false;
    });

    _animationController.forward();

    // Load weather for each favorite in background (non-blocking)
    for (var favorite in favorites) {
      Future.microtask(() => _loadWeatherForCity(favorite['city'] as String));
    }
  }

  Future<void> _loadWeatherForCity(String cityName) async {
    try {
      final weatherData = await _weatherService.getWeatherByCity(cityName);
      if (mounted) {
        setState(() {
          _weatherCache[cityName] = weatherData.current;
        });

        // 💾 Also cache to the global favorites cache for instant access later
        final cacheService = context.read<FavoritesCacheService>();
        cacheService.cacheWeather(
          cityName,
          weatherData,
          country: cityName,
          countryCode: '',
        );
      }
    } catch (e) {
      print('Error loading weather for $cityName: $e');
    }
  }

  Future<void> _removeFavorite(String city, String country) async {
    // Immediately update UI
    setState(() {
      _favorites.removeWhere(
          (fav) => fav['city'] == city && fav['country'] == country);
      _filteredFavorites.removeWhere(
          (fav) => fav['city'] == city && fav['country'] == country);
      _weatherCache.remove(city);
    });

    // Then persist to storage
    final favoritesService = context.read<FavoritesService>();
    await favoritesService.removeFavorite(city, country);

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$city removed from favorites'),
          backgroundColor: Colors.redAccent.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              final favoritesService = context.read<FavoritesService>();
              await favoritesService.addFavorite(city, country);
              await _loadFavoritesWithWeather();
            },
          ),
        ),
      );
    }
  }

  Future<void> _reorderFavorites(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _filteredFavorites.removeAt(oldIndex);
      _filteredFavorites.insert(newIndex, item);

      if (_searchController.text.isEmpty) {
        _favorites = List.from(_filteredFavorites);
      }
    });

    final favoritesService = context.read<FavoritesService>();
    await favoritesService.reorderFavorites(_favorites);
  }

  Future<void> _selectLocation(String city) async {
    final provider = context.read<WeatherProvider>();
    final cacheService = context.read<FavoritesCacheService>();

    // 💾 Check if we have cached weather for this favorite
    if (cacheService.hasCachedWeather(city)) {
      final cachedWeather = cacheService.getWeatherForCity(city);
      if (cachedWeather != null) {
        // Use cached data - instant load!
        print('📱 [FavoritesScreen] Loading $city from cache (instant)');
        provider.restoreCachedWeather(
          cachedWeather,
          city,
          cacheService.getMetadata(city)?['countryCode'] as String? ?? '',
        );
      }
    } else {
      // Fetch fresh data if not cached - AWAIT to ensure data is loaded
      print('📱 [FavoritesScreen] Fetching $city data (network)');
      await provider.fetchWeatherByCity(city);
    }

    // Navigate to favorite card AFTER data is loaded
    widget.onLocationSelected?.call(city);
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
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFF667eea).withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Glass Header
              _buildGlassHeader(),

              // Favorites List
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : _favorites.isEmpty
                        ? _buildEmptyState()
                        : FadeTransition(
                            opacity: _fadeAnimation,
                            child: _buildFavoritesList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // No back button - use bottom navigation to switch tabs
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Favorite Locations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_favorites.isNotEmpty)
                          Text(
                            '${_favorites.length} saved location${_favorites.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildGlassIconButton(
                    icon: _isSearching
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
              // Animated search bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                height: _isSearching ? 60 : 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isSearching ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _buildGlassSearchBar(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: Colors.white.withOpacity(0.15),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search favorites...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading favorites...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 60,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No favorites yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add cities to your favorites\nfrom the home screen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _filteredFavorites.length,
      onReorder: _reorderFavorites,
      proxyDecorator: (child, index, animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 1.0, end: 1.03).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final favorite = _filteredFavorites[index];
        final cityName = favorite['city'] as String;
        final countryCode = favorite['country'] as String;
        final weather = _weatherCache[cityName];

        return Padding(
          key: Key(cityName),
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGlassFavoriteCard(
            cityName,
            countryCode,
            weather,
            index,
          ),
        );
      },
    );
  }

  Widget _buildGlassFavoriteCard(
    String cityName,
    String countryCode,
    CurrentWeather? weather,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _selectLocation(cityName),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Drag handle
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // City info and weather
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cityName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (countryCode.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                countryCode,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _buildWeatherInfo(weather),
                          ],
                        ),
                      ),

                      // Delete button
                      _buildDeleteButton(cityName, countryCode),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfo(CurrentWeather? weather) {
    if (weather != null) {
      return Row(
        children: [
          Text(
            weather.weatherIcon,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${weather.temperature.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                weather.weatherDescription,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Loading...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(String cityName, String countryCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Material(
          color: Colors.red.withOpacity(0.2),
          child: InkWell(
            onTap: () => _showDeleteConfirmation(cityName, countryCode),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String cityName, String countryCode) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF2a2a4a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Remove Favorite',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Remove $cityName from favorites?',
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeFavorite(cityName, countryCode);
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
