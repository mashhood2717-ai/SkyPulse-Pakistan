// Minimal, clean WeatherOnWayTab implementation (clean copy)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/navigation_service.dart';
import '../services/route_service.dart';
import '../services/weather_service.dart';
import '../providers/weather_provider.dart';
import '../utils/theme_utils.dart';

class WeatherOnWayTab extends StatefulWidget {
  const WeatherOnWayTab({Key? key}) : super(key: key);

  @override
  State<WeatherOnWayTab> createState() => _WeatherOnWayTabState();
}

class _WeatherOnWayTabState extends State<WeatherOnWayTab> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final WeatherService _weatherService = WeatherService();

  bool _useCurrentLocation = true;
  bool _trackM2 = true;
  bool _journeyStarted = false;

  double? _fromLat;
  double? _fromLon;
  double? _toLat;
  double? _toLon;

  List<Map<String, dynamic>> _fromSuggestions = [];
  List<Map<String, dynamic>> _toSuggestions = [];
  bool _showFromSuggestions = false;
  bool _showToSuggestions = false;

  Timer? _fromDebounce;
  Timer? _toDebounce;

  GoogleMapController? _mapController;
  StreamSubscription<Position>? _posSub;
  List<LatLng> _routePolyline = [];
  Map<String, dynamic>? _currentNext;
  String? _currentNextWeatherText;

  // (was _fetchWeatherForNext) removed since not referenced

  void _onFromChanged(String query) {
    _fromDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _fromSuggestions = [];
        _showFromSuggestions = false;
      });
      return;
    }
    _fromDebounce = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await _weatherService.getPlaceSuggestions(query);
      if (!mounted) return;
      setState(() {
        _fromSuggestions = suggestions;
        _showFromSuggestions = suggestions.isNotEmpty;
      });
    });
  }

  void _onToChanged(String query) {
    _toDebounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _toSuggestions = [];
        _showToSuggestions = false;
      });
      return;
    }
    _toDebounce = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await _weatherService.getPlaceSuggestions(query);
      if (!mounted) return;
      setState(() {
        _toSuggestions = suggestions;
        _showToSuggestions = suggestions.isNotEmpty;
      });
    });
  }

  Future<void> _selectFromSuggestion(Map<String, dynamic> suggestion) async {
    setState(() {
      _showFromSuggestions = false;
      _fromSuggestions = [];
      _fromController.text = suggestion['description'] ?? suggestion['mainText'] ?? '';
    });
    final details = await _weatherService.getPlaceDetails(suggestion['placeId']);
    if (details != null && mounted) {
      setState(() {
        _fromLat = details['latitude'] as double?;
        _fromLon = details['longitude'] as double?;
      });
      if (_mapController != null && _fromLat != null && _fromLon != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_fromLat!, _fromLon!)));
      }
    }
  }

  void _stopJourney() {
    _posSub?.cancel();
    _posSub = null;
    if (!mounted) return;
    setState(() {
      _journeyStarted = false;
      _currentNext = null;
      _routePolyline = [];
      _currentNextWeatherText = null;
    });
  }
 

  Future<void> _selectToSuggestion(Map<String, dynamic> suggestion) async {
    setState(() {
      _showToSuggestions = false;
      _toSuggestions = [];
      _toController.text = suggestion['description'] ?? suggestion['mainText'] ?? '';
    });
    final details = await _weatherService.getPlaceDetails(suggestion['placeId']);
    if (details != null && mounted) {
      setState(() {
        _toLat = details['latitude'] as double?;
        _toLon = details['longitude'] as double?;
      });
      if (_mapController != null && _toLat != null && _toLon != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(_toLat!, _toLon!)));
      }
    }
  }

  Future<void> _startJourney() async {
    if (_journeyStarted) return;
    if (_toLat == null || _toLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination before starting')));
      return;
    }

    setState(() {
      _journeyStarted = true;
      _routePolyline = [];
      _currentNext = null;
      _currentNextWeatherText = null;
    });

    final destLat = _toLat!;
    final destLon = _toLon!;

    // Pre-fetch route polyline (origin = current or from field)
    double originLat = _fromLat ?? 0.0;
    double originLon = _fromLon ?? 0.0;
    if (_useCurrentLocation) {
      try {
        final p = await Geolocator.getCurrentPosition();
        originLat = p.latitude;
        originLon = p.longitude;
      } catch (_) {}
    }

    if (originLat != 0.0 && originLon != 0.0) {
      final route = await RouteService.getRoutePolyline(originLat, originLon, destLat, destLon);
      if (!mounted) return;
      setState(() {
        _routePolyline = route;
      });
    }

    _posSub = Geolocator.getPositionStream(locationSettings: const LocationSettings(distanceFilter: 10)).listen((pos) async {
      try {
        final latlng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _routePolyline = List.from(_routePolyline)..add(latlng);
        });

        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(latlng));
        }

        if (_trackM2) {
          final updatedNext = RouteService.getNextInterchange('M2', pos.latitude, pos.longitude, destLat: destLat, destLon: destLon);
          if (updatedNext != null && (_currentNext == null || updatedNext['index'] != _currentNext!['index'])) {
            if (!mounted) return;
            setState(() => _currentNext = updatedNext);
            try {
              final wd = await _weatherService.getWeatherByCoordinates(updatedNext['lat'], updatedNext['lon']);
              if (!mounted) return;
              setState(() {
                _currentNextWeatherText = 'Next: ${updatedNext['name']} • ${wd.current.temperature.round()}°C';
              });
            } catch (_) {}
          }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _fromDebounce?.cancel();
    _toDebounce?.cancel();
    _posSub?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDay = Provider.of<WeatherProvider>(context).weatherData?.current.isDay ?? true;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weather On The Way', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: WeatherTheme.getTextColor(isDay))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: SwitchListTile.adaptive(
                    title: Text('Use current location as start', style: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay))),
                    value: _useCurrentLocation,
                    onChanged: (v) => setState(() => _useCurrentLocation = v),
                  )),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _fromController,
                  decoration: InputDecoration(
                    labelText: 'From (optional)',
                    labelStyle: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay)),
                    filled: true,
                    fillColor: isDay ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.04),
                  ),
                  style: TextStyle(color: WeatherTheme.getTextColor(isDay)),
                  onChanged: _onFromChanged,
                ),
                if (_showFromSuggestions && _fromSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _fromSuggestions.length,
                        itemBuilder: (context, i) {
                          final s = _fromSuggestions[i];
                          final title = s['description'] ?? s['mainText'] ?? '';
                          final subtitle = s['secondaryText'] ?? '';
                          return ListTile(
                            title: Text(title, style: TextStyle(color: WeatherTheme.getTextColor(isDay))),
                            subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay))) : null,
                            onTap: () => _selectFromSuggestion(s),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _toController,
                  decoration: InputDecoration(
                    labelText: 'To (required)',
                    labelStyle: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay)),
                    filled: true,
                    fillColor: isDay ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.04),
                  ),
                  style: TextStyle(color: WeatherTheme.getTextColor(isDay)),
                  onChanged: _onToChanged,
                ),
                if (_showToSuggestions && _toSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _toSuggestions.length,
                        itemBuilder: (context, i) {
                          final s = _toSuggestions[i];
                          final title = s['description'] ?? s['mainText'] ?? '';
                          final subtitle = s['secondaryText'] ?? '';
                          return ListTile(
                            title: Text(title, style: TextStyle(color: WeatherTheme.getTextColor(isDay))),
                            subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay))) : null,
                            onTap: () => _selectToSuggestion(s),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: Text('Track M2 interchanges during journey', style: TextStyle(color: WeatherTheme.getSecondaryTextColor(isDay))),
                  value: _trackM2,
                  onChanged: (v) => setState(() => _trackM2 = v),
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(target: LatLng(33.6844, 73.0479), zoom: 7),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (c) => _mapController = c,
                  markers: {
                    if (_fromLat != null && _fromLon != null) Marker(markerId: const MarkerId('from'), position: LatLng(_fromLat!, _fromLon!)),
                    if (_toLat != null && _toLon != null) Marker(markerId: const MarkerId('to'), position: LatLng(_toLat!, _toLon!)),
                    if (_currentNext != null) Marker(markerId: const MarkerId('next'), position: LatLng(_currentNext!['lat'], _currentNext!['lon']))
                  },
                  polylines: {
                    if (_routePolyline.isNotEmpty)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _routePolyline,
                        color: WeatherTheme.getAccentColor(isDay),
                        width: 7,
                        geodesic: true,
                        zIndex: 2,
                      )
                  },
                ),

                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_journeyStarted ? 'On Journey' : 'Ready to navigate', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                if (_currentNextWeatherText != null)
                                                    Text(_currentNextWeatherText!, style: TextStyle(fontSize: 12, color: WeatherTheme.getSecondaryTextColor(isDay))),
                                                  if (_currentNextWeatherText == null)
                                                    Text(_currentNext != null ? 'Next: ${_currentNext!['name']}' : 'No next interchange', style: TextStyle(fontSize: 12, color: WeatherTheme.getSecondaryTextColor(isDay))),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          icon: Icon(_journeyStarted ? Icons.stop : Icons.navigation, color: Colors.white),
                                                          label: Text(_journeyStarted ? 'Stop' : 'Start', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: _journeyStarted ? Colors.red : WeatherTheme.getAccentColor(isDay),
                                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                                          ),
                                                          onPressed: _journeyStarted ? _stopJourney : _startJourney,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(Icons.map, color: WeatherTheme.getTextColor(isDay)),
                                                        onPressed: () async {
                                                          if (_toLat != null && _toLon != null) {
                                                            await NavigationService.openGoogleMapsNavigation(_toLat!, _toLon!);
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_journeyStarted)
                            IconButton(
                              icon: const Icon(Icons.map_outlined),
                              onPressed: () async {
                                // Offer to open external maps as fallback
                                if (_toLat != null && _toLon != null) {
                                  await NavigationService.openGoogleMapsNavigation(_toLat!, _toLon!);
                                }
                              },
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: _journeyStarted ? Colors.red : WeatherTheme.getAccentColor(isDay)),
                            onPressed: _journeyStarted ? _stopJourney : _startJourney,
                            child: Text(_journeyStarted ? 'Stop' : 'Start'),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
