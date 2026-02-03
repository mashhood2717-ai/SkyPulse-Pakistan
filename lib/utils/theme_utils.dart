import 'package:flutter/material.dart';

/// Theme utility class for day/night mode based on sunrise/sunset
class WeatherTheme {
  /// Day mode gradient colors (current blue theme)
  static const List<Color> dayGradient = [
    Color(0xFF16325A),
    Color(0xFF1F4BA0),
    Color(0xFF16325A),
  ];

  /// Night mode gradient colors (dark purple/navy theme)
  static const List<Color> nightGradient = [
    Color(0xFF0f0c29),
    Color(0xFF302b63),
    Color(0xFF24243e),
  ];

  /// Day mode primary color
  static const Color dayPrimary = Color(0xFF10283F);

  /// Night mode primary color
  static const Color nightPrimary = Color(0xFF0f0c29);

  /// Day mode accent color
  static const Color dayAccent = Color(0xFF2160C1);

  /// Night mode accent color
  static const Color nightAccent = Color(0xFF302b63);

  /// Get gradient based on isDay
  static List<Color> getGradient(bool isDay) {
    return isDay ? dayGradient : nightGradient;
  }

  /// Get gradient with stops for main background
  static LinearGradient getBackgroundGradient(bool isDay) {
    final colors = getGradient(isDay);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors[0],
        colors[1],
        colors[2].withOpacity(0.9),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// Get primary color based on isDay
  static Color getPrimaryColor(bool isDay) {
    return isDay ? dayPrimary : nightPrimary;
  }

  /// Get accent color based on isDay
  static Color getAccentColor(bool isDay) {
    return isDay ? dayAccent : nightAccent;
  }

  /// Get card gradient for glass effect
  static LinearGradient getCardGradient(bool isDay) {
    if (isDay) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.18),
          Colors.white.withOpacity(0.12),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.14),
          Colors.white.withOpacity(0.08),
        ],
      );
    }
  }

  /// Get favorite card gradient
  static LinearGradient getFavoriteCardGradient(bool isDay) {
    if (isDay) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue.withOpacity(0.5),
          Colors.purple.withOpacity(0.35),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.indigo.withOpacity(0.45),
          Colors.deepPurple.withOpacity(0.45),
        ],
      );
    }
  }

  /// Get refresh indicator background color
  static Color getRefreshIndicatorBg(bool isDay) {
    return isDay ? const Color(0xFF1e3c72) : const Color(0xFF0f0c29);
  }

  /// Get shimmer base color for skeleton loaders
  static Color getShimmerBase(bool isDay) {
    return isDay ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.08);
  }

  /// Get shimmer highlight color for skeleton loaders
  static Color getShimmerHighlight(bool isDay) {
    return isDay ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.18);
  }

  /// Get text color (always white for both modes)
  static Color getTextColor(bool isDay) {
    // Use stronger contrast: near-white for dark backgrounds, dark text when backgrounds are light
    return isDay ? Colors.white : Colors.white;
  }

  /// Get secondary text color
  static Color getSecondaryTextColor(bool isDay) {
    return isDay ? Colors.white.withOpacity(0.92) : Colors.white.withOpacity(0.86);
  }

  /// Get border color for cards
  static Color getBorderColor(bool isDay) {
    return isDay ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.22);
  }

  /// Get icon color
  static Color getIconColor(bool isDay) {
    return isDay ? Colors.white.withOpacity(0.98) : Colors.white.withOpacity(0.92);
  }
}
