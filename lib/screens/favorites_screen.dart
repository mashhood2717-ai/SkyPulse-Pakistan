import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/favorites_service.dart';
import '../providers/weather_provider.dart';
import '../services/weather_service.dart';
import '../models/weather_model.dart';

class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onLocationSelected;

  const FavoritesScreen({
    Key? key,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _filteredFavorites = [];
  Map<String, CurrentWeather?> _weatherCache = {};
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFavoritesWithWeather();
    _searchController.addListener(_filterFavorites);
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final favorites = await _favoritesService.getFavorites();
    setState(() {
      _favorites = favorites;
      _filteredFavorites = List.from(favorites);
      _isLoading = false;
    });

    // Load weather for each favorite in background
    for (var favorite in favorites) {
      _loadWeatherForCity(favorite['city'] as String);
    }
  }

  Future<void> _loadWeatherForCity(String cityName) async {
    try {
      final weatherData = await _weatherService.getWeatherByCity(cityName);
      if (mounted) {
        setState(() {
          _weatherCache[cityName] = weatherData.current;
        });
      }
    } catch (e) {
      print('Error loading weather for $cityName: $e');
    }
  }

  Future<void> _removeFavorite(String city, String country) async {
    await _favoritesService.removeFavorite(city, country);
    _weatherCache.remove(city);
    _loadFavoritesWithWeather();
  }

  Future<void> _reorderFavorites(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _filteredFavorites.removeAt(oldIndex);
      _filteredFavorites.insert(newIndex, item);

      // Update the main list if not searching
      if (_searchController.text.isEmpty) {
        _favorites = List.from(_filteredFavorites);
      }
    });

    // Save the new order
    await _favoritesService.reorderFavorites(_favorites);
  }

  void _selectLocation(String city) {
    final provider = context.read<WeatherProvider>();

    // Immediately switch to weather tab
    widget.onLocationSelected?.call();

    // Fetch weather in background without waiting
    provider.fetchWeatherByCity(city);
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
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            // Switch back to Weather tab when back is pressed
                            widget.onLocationSelected?.call();
                          },
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Favorite Locations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(_isSearching ? Icons.close : Icons.search,
                              color: Colors.white),
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
                    if (_isSearching) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search cities...',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.white.withOpacity(0.6)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Favorites List
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _favorites.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.favorite_border,
                                  size: 80,
                                  color: Colors.white70,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No favorites yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add cities to your favorites\nfrom the home screen',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredFavorites.length,
                            onReorder: _reorderFavorites,
                            itemBuilder: (context, index) {
                              final favorite = _filteredFavorites[index];
                              final cityName = favorite['city'] as String;
                              final countryCode = favorite['country'] as String;
                              final weather = _weatherCache[cityName];

                              return Padding(
                                key: Key(
                                    cityName), // Required for ReorderableListView
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildFavoriteCard(
                                  cityName,
                                  countryCode,
                                  weather,
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(
      String cityName, String countryCode, CurrentWeather? weather) {
    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectLocation(cityName),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Drag handle
                Icon(Icons.drag_handle,
                    color: Colors.white.withOpacity(0.5), size: 24),
                const SizedBox(width: 12),

                // Left side - City info and weather
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // City name
                      Text(
                        cityName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Country code
                      if (countryCode.isNotEmpty)
                        Text(
                          countryCode,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),

                      // Weather info (if loaded)
                      if (weather != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Weather icon
                            Text(
                              weather.weatherIcon,
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(width: 12),

                            // Temperature and condition
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${weather.temperature.round()}°C',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  weather.weatherDescription,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Loading weather...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Right side - Delete button
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white70,
                    size: 24,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Remove Favorite'),
                        content: Text('Remove $cityName from favorites?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      _removeFavorite(cityName, countryCode);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
