import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const List<String> tempUnits = ['Celsius', 'Fahrenheit'];
  static const List<String> windUnits = ['km/h', 'mph', 'm/s'];

  /// Default refresh interval is 30 minutes
  static const Duration refreshInterval = Duration(minutes: 30);

  SharedPreferences? _prefs;

  /// Completes once preferences have loaded. Setters await this instead of
  /// touching a `late` field that may not be assigned yet — flipping a switch
  /// during the first frames used to throw LateInitializationError.
  late final Future<void> _ready = _initPreferences();

  bool _isAutoRefreshEnabled = true;
  String _tempUnit = 'Celsius';
  String _windUnit = 'km/h';

  SettingsProvider() {
    // Kick off loading; _ready is what everything else waits on.
    _ready;
  }

  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;
  String get tempUnit => _tempUnit;
  String get windUnit => _windUnit;

  Future<void> _initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _isAutoRefreshEnabled = prefs.getBool('isAutoRefreshEnabled') ?? true;

    final loadedTemp = prefs.getString('tempUnit') ?? 'Celsius';
    _tempUnit = tempUnits.contains(loadedTemp) ? loadedTemp : 'Celsius';

    final loadedWind = prefs.getString('windUnit') ?? 'km/h';
    _windUnit = windUnits.contains(loadedWind) ? loadedWind : 'km/h';

    notifyListeners();
  }

  Future<void> toggleAutoRefresh(bool value) async {
    if (_isAutoRefreshEnabled == value) return;
    _isAutoRefreshEnabled = value;
    notifyListeners();

    await _ready;
    await _prefs?.setBool('isAutoRefreshEnabled', value);
  }

  // --- Temperature Unit ---

  Future<void> setTempUnit(String value) async {
    if (_tempUnit == value || !tempUnits.contains(value)) return;
    _tempUnit = value;
    notifyListeners();

    await _ready;
    await _prefs?.setString('tempUnit', value);
  }

  String getTempString(double celsius) {
    if (_tempUnit == 'Fahrenheit') {
      final f = (celsius * 9 / 5) + 32;
      return '${f.round()}°F';
    }
    return '${celsius.round()}°C';
  }

  // --- Wind Speed Unit ---

  Future<void> setWindUnit(String value) async {
    if (_windUnit == value || !windUnits.contains(value)) return;
    _windUnit = value;
    notifyListeners();

    await _ready;
    await _prefs?.setString('windUnit', value);
  }

  String getWindSpeedString(double kmh) {
    if (_windUnit == 'mph') {
      final mph = kmh * 0.621371;
      return '${mph.round()} mph';
    } else if (_windUnit == 'm/s') {
      final ms = kmh / 3.6;
      return '${ms.toStringAsFixed(1)} m/s';
    }
    return '${kmh.round()} km/h';
  }
}
