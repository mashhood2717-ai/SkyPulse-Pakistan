import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/weather_model.dart';
import '../providers/settings_provider.dart';
import '../providers/weather_provider.dart';
import '../utils/theme_utils.dart';

class WeatherDetails extends StatelessWidget {
  final CurrentWeather current;

  const WeatherDetails({
    Key? key,
    required this.current,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final provider = Provider.of<WeatherProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context);
    final windDirection = provider.usingCompanyStation
        ? current.windDirection.toDouble()
        : provider.metarData?.windDirection?.toDouble() ??
            current.windDirection.toDouble();
    final tiles = _buildTiles(
      p: p,
      settings: settings,
      windDirection: windDirection,
      showStationRain: provider.usingCompanyStation,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Current Conditions',
            style: TextStyle(
              color: p.text,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tiles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 116,
          ),
          itemBuilder: (context, index) => tiles[index],
        ),
      ],
    );
  }

  List<Widget> _buildTiles({
    required AppPalette p,
    required SettingsProvider settings,
    required double windDirection,
    required bool showStationRain,
  }) {
    return [
      _buildWindTile(p, windDirection, settings),
      _buildDetailTile(
        p: p,
        icon: Icons.water_drop_rounded,
        iconColor: const Color(0xFF4FC3F7),
        label: 'Humidity',
        value: '${current.humidity}%',
        backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.thermostat_rounded,
        iconColor: const Color(0xFF81C784),
        label: 'Dew Point',
        value: settings.getTempString(current.dewPoint),
        backgroundColor: const Color(0xFF81C784).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.air_rounded,
        iconColor: const Color(0xFF64B5F6),
        label: 'Wind Gust',
        value: settings.getWindSpeedString(current.windGust),
        backgroundColor: const Color(0xFF64B5F6).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.wb_sunny_rounded,
        iconColor: _getUVColor(current.uvIndex),
        label: 'UV Index',
        value: '${current.uvIndex.round()}',
        subValue: current.uvIndexCategory,
        backgroundColor: _getUVColor(current.uvIndex).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.visibility_rounded,
        iconColor: const Color(0xFF9C27B0),
        label: 'Visibility',
        value: current.visibility > 0
            ? '${current.visibility.toStringAsFixed(1)} km'
            : '--',
        backgroundColor: const Color(0xFF9C27B0).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.compress_rounded,
        iconColor: const Color(0xFFFF7043),
        label: 'Pressure',
        value: '${current.pressure.round()}',
        subValue: 'hPa',
        backgroundColor: const Color(0xFFFF7043).withOpacity(0.1),
      ),
      _buildDetailTile(
        p: p,
        icon: Icons.cloud_rounded,
        iconColor: const Color(0xFF78909C),
        label: 'Cloud Cover',
        value: '${current.cloudCover}%',
        backgroundColor: const Color(0xFF78909C).withOpacity(0.1),
      ),
      if (showStationRain) ...[
        _buildDetailTile(
          p: p,
          icon: Icons.grain_rounded,
          iconColor: const Color(0xFF42A5F5),
          label: 'Rain Rate',
          value: current.rainRate > 0
              ? current.rainRate.toStringAsFixed(1)
              : '0.0',
          subValue: 'mm/h',
          backgroundColor: const Color(0xFF42A5F5).withOpacity(0.1),
        ),
        _buildDetailTile(
          p: p,
          icon: Icons.water_rounded,
          iconColor: const Color(0xFF29B6F6),
          label: 'Daily Rain',
          value: current.dailyRain != null
              ? current.dailyRain!.toStringAsFixed(1)
              : '--',
          subValue: 'mm today',
          backgroundColor: const Color(0xFF29B6F6).withOpacity(0.1),
        ),
      ],
    ];
  }

  Widget _buildWindTile(
      AppPalette p, double windDirection, SettingsProvider settings) {
    final directionLabel = _getWindDirectionLabel(windDirection);
    final directionValue =
        windDirection > 0 ? '${windDirection.round()} deg' : '';

    return _buildDetailTile(
      p: p,
      icon: Icons.explore_rounded,
      iconColor: const Color(0xFF66BB6A),
      label: 'Wind',
      value: directionLabel,
      subValue: directionValue.isNotEmpty
          ? '$directionValue - ${settings.getWindSpeedString(current.windSpeed)}'
          : settings.getWindSpeedString(current.windSpeed),
      backgroundColor: const Color(0xFF66BB6A).withOpacity(0.1),
      isPrimary: true,
    );
  }

  Widget _buildDetailTile({
    required AppPalette p,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color backgroundColor,
    String? subValue,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor.withOpacity(isPrimary ? 0.42 : 0.3),
            backgroundColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? iconColor.withOpacity(0.38)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: p.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subValue != null && subValue.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subValue,
              style: TextStyle(
                color: p.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _getWindDirectionLabel(double degrees) {
    if (degrees <= 0) return 'Calm';
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  Color _getUVColor(double uvIndex) {
    if (uvIndex <= 2) return const Color(0xFF66BB6A);
    if (uvIndex <= 5) return const Color(0xFFFDD835);
    if (uvIndex <= 7) return const Color(0xFFFF9800);
    if (uvIndex <= 10) return const Color(0xFFF44336);
    return const Color(0xFF9C27B0);
  }
}
