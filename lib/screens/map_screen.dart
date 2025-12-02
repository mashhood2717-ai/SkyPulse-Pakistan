import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import 'dart:async';
import 'dart:math';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Timer _satelliteRefreshTimer;
  int _currentSatelliteIndex = 0;
  
  // OpenWeatherMap API Key
  static const String _owmApiKey = '785e637a1ddc31df39e0e2f6858209c6';
  
  // Zoom level for tile mapping
  int _zoomLevel = 6;

  // OpenWeatherMap satellite imagery URLs with multiple layers
  late final List<Map<String, String>> _satelliteImages;

  @override
  void initState() {
    super.initState();
    
    // Initialize satellite images with OpenWeatherMap tiles
    // These will be updated with actual location coordinates
    _satelliteImages = [
      {
        'name': 'Clouds Layer',
        'url': 'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=$_owmApiKey',
      },
      {
        'name': 'Precipitation',
        'url': 'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=$_owmApiKey',
      },
      {
        'name': 'Sea Level Pressure',
        'url': 'https://tile.openweathermap.org/map/pressure_new/{z}/{x}/{y}.png?appid=$_owmApiKey',
      },
      {
        'name': 'Wind Speed',
        'url': 'https://tile.openweathermap.org/map/wind_new/{z}/{x}/{y}.png?appid=$_owmApiKey',
      },
      {
        'name': 'Temperature',
        'url': 'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid=$_owmApiKey',
      },
    ];
    
    // Refresh satellite image every 10 minutes
    _satelliteRefreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (_) {
        if (mounted) {
          setState(() {
            _currentSatelliteIndex =
                (_currentSatelliteIndex + 1) % _satelliteImages.length;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _satelliteRefreshTimer.cancel();
    super.dispose();
  }

  /// Convert latitude/longitude to tile coordinates
  Map<String, int> _latlngToTile(double lat, double lng, int zoom) {
    int x = ((lng + 180) / 360 * pow(2, zoom).toInt()).toInt();
    int y = ((1 -
            log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) /
        2 *
        pow(2, zoom).toInt())
        .toInt();
    return {'x': x, 'y': y};
  }

  /// Get the OpenWeatherMap tile URL for current location
  String _getSatelliteUrl(String baseUrl, double lat, double lng, int zoom) {
    final tile = _latlngToTile(lat, lng, zoom);
    return baseUrl
        .replaceAll('{z}', zoom.toString())
        .replaceAll('{x}', tile['x'].toString())
        .replaceAll('{y}', tile['y'].toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              // EUMETSAT Satellite Background Layer
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1a3a3a),
                        const Color(0xFF0d1f1f),
                        const Color(0xFF2a4a4a),
                      ],
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // OpenWeatherMap Satellite Tile Layer
                      Image.network(
                        _getSatelliteUrl(
                          _satelliteImages[_currentSatelliteIndex]['url']!,
                          provider.latitude,
                          provider.longitude,
                          _zoomLevel,
                        ),
                        fit: BoxFit.cover,
                        cacheHeight: 2000,
                        cacheWidth: 2000,
                        headers: {
                          'User-Agent':
                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print(
                              '🛰️ OpenWeatherMap satellite load failed: $error'); // Debug output
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1a3a3a),
                                  const Color(0xFF0d1f1f),
                                  const Color(0xFF2a4a4a),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.satellite_alt,
                                    size: 80,
                                    color: Colors.cyan.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'OpenWeatherMap Satellite',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_satelliteImages[_currentSatelliteIndex]['name']}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _currentSatelliteIndex =
                                            (_currentSatelliteIndex + 1) %
                                                _satelliteImages.length;
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Try Another'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1a3a3a),
                                  const Color(0xFF0d1f1f),
                                  const Color(0xFF2a4a4a),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.cyan.withOpacity(0.7),
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Loading ${_satelliteImages[_currentSatelliteIndex]['name']}...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Overlay for better readability
                      Container(
                        color: Colors.black.withOpacity(0.25),
                      ),
                    ],
                  ),
                ),
              ),
              // Location Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFF667EEA),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.cityName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    provider.countryCode,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Satellite Info Badge
              Positioned(
                top: MediaQuery.of(context).padding.top + 100,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withOpacity(0.6),
                        Colors.purple.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.satellite_alt,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _satelliteImages[_currentSatelliteIndex]['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Coordinates Display
              Positioned(
                top: MediaQuery.of(context).padding.top + 160,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF667EEA).withOpacity(0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Coordinates',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lat: ${provider.latitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lon: ${provider.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Colors.cyan,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Weather Info Card at Bottom
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.cloud,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Weather Overview',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (provider.weatherData != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud,
                                      color: Colors.lightBlue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cloud: ${provider.weatherData?.current.cloudCover ?? 0}%',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Vis: ${(provider.weatherData?.current.visibility ?? 10).toStringAsFixed(1)}km',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.wind_power,
                                      color: Colors.greenAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Wind: ${provider.weatherData?.current.windSpeed.toStringAsFixed(1)}km/h',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.water_drop,
                                      color: Colors.blue,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Humidity: ${provider.weatherData?.current.humidity ?? 0}%',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        Text(
                          'Loading weather data...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
