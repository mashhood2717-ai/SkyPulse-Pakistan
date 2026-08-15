import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  SharedPreferences? _prefs;

  /// Completes once preferences have loaded; setters await it rather than
  /// writing to a `late` field that may not be assigned yet.
  late final Future<void> _ready = _initPreferences();

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _ready;
  }

  Future<void> _initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() => setDarkMode(!_isDarkMode);

  Future<void> setDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    _isDarkMode = isDark;
    notifyListeners();

    await _ready;
    await _prefs?.setBool('isDarkMode', _isDarkMode);
  }

  ThemeData getTheme() {
    if (_isDarkMode) {
      return _darkTheme();
    } else {
      return _lightTheme();
    }
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E27),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1F3A),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF667EEA),
        secondary: Color(0xFF764BA2),
        surface: Color(0xFF1A1F3A),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667EEA);
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667EEA).withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        elevation: 0,
      ),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF667EEA),
        secondary: Color(0xFF764BA2),
        surface: Color(0xFFFFFFFF),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667EEA);
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const Color(0xFF667EEA).withOpacity(0.3);
          }
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }
}
