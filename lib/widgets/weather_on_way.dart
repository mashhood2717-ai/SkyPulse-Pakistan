import 'package:flutter/material.dart';
import '../services/route_service.dart';
import '../services/weather_service.dart';
import '../services/navigation_service.dart';
import '../models/weather_model.dart';
import 'weather_card.dart';

/// Widget that shows the next interchange weather along a motorway
class WeatherOnWay extends StatefulWidget {
  final String motorway; // e.g., 'M2'
  final double currentLat;
  final double currentLon;

  const WeatherOnWay({
    Key? key,
    required this.motorway,
    required this.currentLat,
    required this.currentLon,
  }) : super(key: key);

  @override
  State<WeatherOnWay> createState() => _WeatherOnWayState();
}

class _WeatherOnWayState extends State<WeatherOnWay> {
  Map<String, dynamic>? _nextInterchange;
  WeatherData? _weatherData;
  bool _loading = false;
  final WeatherService _weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() => _loading = true);
    final next = RouteService.getNextInterchange(
        widget.motorway, widget.currentLat, widget.currentLon);
    if (next != null) {
      _nextInterchange = next;
      try {
        final data = await _weatherService.getWeatherByCoordinates(
            next['lat'], next['lon']);
        if (mounted) {
          setState(() {
            _weatherData = data;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_nextInterchange == null || _weatherData == null) {
      return const SizedBox.shrink();
    }

    final name = _nextInterchange!['name'] as String;
    final dist = (_nextInterchange!['distance_km'] as double).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Next: $name', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Text('$dist km', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.navigation, color: Colors.white, size: 20),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await NavigationService.openGoogleMapsNavigation(
                          _nextInterchange!['lat'], _nextInterchange!['lon'],
                          label: name);
                      if (!ok) {
                        if (!mounted) return;
                        messenger.showSnackBar(const SnackBar(content: Text('Could not open Maps')));
                      }
                    },
                  )
                ],
              ),
            ],
          ),
        ),
        WeatherCard(
          cityName: name,
          countryCode: '',
          current: _weatherData!.current,
        ),
      ],
    );
  }
}
