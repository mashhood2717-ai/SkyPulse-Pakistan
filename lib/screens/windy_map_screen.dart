import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/weather_provider.dart';

class WindyMapScreen extends StatefulWidget {
  const WindyMapScreen({Key? key}) : super(key: key);

  @override
  State<WindyMapScreen> createState() => _WindyMapScreenState();
}

class _WindyMapScreenState extends State<WindyMapScreen> {
  late WebViewController _webViewController;
  String _selectedLayer = 'wind';

  final List<Map<String, String>> _layers = [
    {'name': 'Wind', 'overlay': 'wind'},
    {'name': 'Clouds', 'overlay': 'clouds'},
    {'name': 'Rain', 'overlay': 'rain'},
    {'name': 'Pressure', 'overlay': 'pressure'},
    {'name': 'Temperature', 'overlay': 'temp'},
    {'name': 'Visibility', 'overlay': 'visibility'},
    {'name': 'Satellite', 'overlay': 'satellite'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(_buildWindyUrl(33.6584, 73.0532, _selectedLayer)));
  }

  String _buildWindyUrl(double lat, double lon, String overlay) {
    return 'https://embed.windy.com/embed2.html?'
        'lat=$lat&'
        'lon=$lon&'
        'detailLat=$lat&'
        'detailLon=$lon&'
        'zoom=6&'
        'overlay=$overlay&'
        'product=gfs&'
        'menu=&'
        'type=map&'
        'location=coordinates&'
        'geolocation=disabled&'
        'message=&'
        'marker=&'
        'forecast=12h&'
        'calendar=now&'
        'pressure&'
        'rains=';
  }

  void _changeLayer(String layer) {
    setState(() {
      _selectedLayer = layer;
    });
    _webViewController.loadRequest(Uri.parse(
      _buildWindyUrl(33.6584, 73.0532, layer),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              // Location header overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF667EEA),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.cityName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Lat: ${provider.latitude.toStringAsFixed(4)}, Lon: ${provider.longitude.toStringAsFixed(4)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Layer selection below the header
              Positioned(
                top: MediaQuery.of(context).padding.top + 110,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _layers
                          .map((layer) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FilterChip(
                                  label: Text(
                                    layer['name']!,
                                    style: TextStyle(
                                      color: _selectedLayer == layer['overlay']
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: _selectedLayer ==
                                              layer['overlay']
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  selected:
                                      _selectedLayer == layer['overlay'],
                                  onSelected: (selected) {
                                    if (selected) {
                                      _changeLayer(layer['overlay']!);
                                    }
                                  },
                                  backgroundColor: Colors.transparent,
                                  selectedColor: Color(0xFF667EEA)
                                      .withOpacity(0.7),
                                  side: BorderSide(
                                    color: _selectedLayer == layer['overlay']
                                        ? Color(0xFF667EEA)
                                        : Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
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
