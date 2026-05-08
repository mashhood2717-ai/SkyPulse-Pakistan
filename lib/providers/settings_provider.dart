import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _isAutoRefreshEnabled = true;
  late SharedPreferences _prefs;

  // Default refresh interval is 30 minutes
  static const Duration refreshInterval = Duration(minutes: 30);

  bool get isAutoRefreshEnabled => _isAutoRefreshEnabled;

  SettingsProvider() {
    _initPreferences();
  }

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _isAutoRefreshEnabled = _prefs.getBool('isAutoRefreshEnabled') ?? true;
    
    // Validate Temp Unit
    String loadedTemp = _prefs.getString('tempUnit') ?? 'Celsius';
    if (!['Celsius', 'Fahrenheit'].contains(loadedTemp)) {
      loadedTemp = 'Celsius';
    }
    _tempUnit = loadedTemp;

    // Validate Wind Unit
    String loadedWind = _prefs.getString('windUnit') ?? 'km/h';
    if (!['km/h', 'mph', 'm/s'].contains(loadedWind)) {
      loadedWind = 'km/h';
    }
    _windUnit = loadedWind;

    notifyListeners();
  }

  Future<void> toggleAutoRefresh(bool value) async {
    _isAutoRefreshEnabled = value;
    await _prefs.setBool('isAutoRefreshEnabled', value);
    notifyListeners();
  }

  // --- Temperature Unit ---
  String _tempUnit = 'Celsius'; // Celsius, Fahrenheit
  String get tempUnit => _tempUnit;

  Future<void> setTempUnit(String value) async {
    if (_tempUnit != value) {
      _tempUnit = value;
      await _prefs.setString('tempUnit', value);
      notifyListeners();
    }
  }

  String getTempString(double celsius) {
    if (_tempUnit == 'Fahrenheit') {
      final f = (celsius * 9 / 5) + 32;
      return '${f.round()}°F';
    }
    return '${celsius.round()}°C';
  }

  // --- Wind Speed Unit ---
  String _windUnit = 'km/h'; // km/h, mph, m/s
  String get windUnit => _windUnit;

  Future<void> setWindUnit(String value) async {
    if (_windUnit != value) {
      _windUnit = value;
      await _prefs.setString('windUnit', value);
      notifyListeners();
    }
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
