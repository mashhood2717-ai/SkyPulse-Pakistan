import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_locations';
  List<Map<String, dynamic>> _favorites = [];

  FavoritesService() {
    // Load favorites on init
    _loadFavoritesSync();
  }

  List<Map<String, dynamic>> get favorites => _favorites;

  // Load favorites synchronously from cache (fast access)
  void _loadFavoritesSync() {
    // This is called on init - will be populated by first async load
  }

  // Save a favorite location
  Future<void> addFavorite(String cityName, String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    final location = {
      'city': cityName,
      'country': countryCode,
    };

    // Check if already exists
    final exists = favorites
        .any((fav) => fav['city'] == cityName && fav['country'] == countryCode);

    if (!exists) {
      favorites.add(location);
      _favorites = favorites;
      await prefs.setString(_favoritesKey, json.encode(favorites));
      notifyListeners(); // 🔔 Notify all listeners immediately
    }
  }

  // Remove a favorite location
  Future<void> removeFavorite(String cityName, String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    favorites.removeWhere(
        (fav) => fav['city'] == cityName && fav['country'] == countryCode);

    _favorites = favorites;
    await prefs.setString(_favoritesKey, json.encode(favorites));
    notifyListeners(); // 🔔 Notify all listeners immediately
  }

  // Get all favorites (async from storage)
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);

    if (favoritesJson == null || favoritesJson.isEmpty) {
      _favorites = [];
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(favoritesJson);
      _favorites =
          decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      return _favorites;
    } catch (e) {
      print('Error loading favorites: $e');
      _favorites = [];
      return [];
    }
  }

  // Check if a location is favorited (sync version using cache)
  bool isFavoriteSync(String cityName, String countryCode) {
    return _favorites
        .any((fav) => fav['city'] == cityName && fav['country'] == countryCode);
  }

  // Check if a location is favorited (async version)
  Future<bool> isFavorite(String cityName, String countryCode) async {
    final favorites = await getFavorites();
    return favorites
        .any((fav) => fav['city'] == cityName && fav['country'] == countryCode);
  }

  // Reorder favorites (save new order)
  Future<void> reorderFavorites(List<Map<String, dynamic>> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = favorites;
    await prefs.setString(_favoritesKey, json.encode(favorites));
    notifyListeners(); // 🔔 Notify all listeners
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = [];
    await prefs.remove(_favoritesKey);
    notifyListeners(); // 🔔 Notify all listeners
  }
}
