import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService {
  static const String _favoritesKey = 'favorite_locations';

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
      await prefs.setString(_favoritesKey, json.encode(favorites));
    }
  }

  // Remove a favorite location
  Future<void> removeFavorite(String cityName, String countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();

    favorites.removeWhere(
        (fav) => fav['city'] == cityName && fav['country'] == countryCode);

    await prefs.setString(_favoritesKey, json.encode(favorites));
  }

  // Get all favorites
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getString(_favoritesKey);

    if (favoritesJson == null || favoritesJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(favoritesJson);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Error loading favorites: $e');
      return [];
    }
  }

  // Check if a location is favorited
  Future<bool> isFavorite(String cityName, String countryCode) async {
    final favorites = await getFavorites();
    return favorites
        .any((fav) => fav['city'] == cityName && fav['country'] == countryCode);
  }

  // Reorder favorites (save new order)
  Future<void> reorderFavorites(List<Map<String, dynamic>> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesKey, json.encode(favorites));
  }

  // Clear all favorites
  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }
}
