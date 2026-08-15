import 'package:flutter/material.dart';

/// Colours for the weather surfaces.
///
/// Two independent axes, which is why every method takes both:
///
///   * `isDay`   — the *weather* being shown (sunrise/sunset at the location).
///   * `isLight` — the *app theme* the user picked in Settings.
///
/// The app used to hardcode a dark palette in every screen while still offering
/// a light-mode switch, so turning it on produced white text on a white ground.
/// Callers now read `isLight` from `Theme.of(context).brightness`.
class WeatherTheme {
  // ----------------------------------------------------------- backgrounds

  static const List<Color> _dayGradientDark = [
    Color(0xFF16325A),
    Color(0xFF1F4BA0),
    Color(0xFF16325A),
  ];

  static const List<Color> _nightGradientDark = [
    Color(0xFF0F0C29),
    Color(0xFF302B63),
    Color(0xFF24243E),
  ];

  static const List<Color> _dayGradientLight = [
    Color(0xFF7FB4EC),
    Color(0xFFA9CDF3),
    Color(0xFFDCEAF9),
  ];

  static const List<Color> _nightGradientLight = [
    Color(0xFF6E7BB5),
    Color(0xFF97A2CE),
    Color(0xFFD5DAEC),
  ];

  static List<Color> getGradient(bool isDay, {bool isLight = false}) {
    if (isLight) return isDay ? _dayGradientLight : _nightGradientLight;
    return isDay ? _dayGradientDark : _nightGradientDark;
  }

  static LinearGradient getBackgroundGradient(
    bool isDay, {
    bool isLight = false,
  }) {
    final colors = getGradient(isDay, isLight: isLight);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colors[0], colors[1], colors[2]],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  /// True when the surfaces should be drawn for a light background.
  static bool isLightMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // ------------------------------------------------------------------ text

  /// Primary text. Near-black on the light gradient, white on the dark one.
  static Color getTextColor(bool isLight) =>
      isLight ? const Color(0xFF10233A) : Colors.white;

  static Color getSecondaryTextColor(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.68)
      : Colors.white.withOpacity(0.86);

  static Color getMutedTextColor(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.5)
      : Colors.white.withOpacity(0.6);

  static Color getIconColor(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.85)
      : Colors.white.withOpacity(0.94);

  // ---------------------------------------------------------------- glass

  /// Tint used for the frosted panels. Light mode frosts *white over colour*,
  /// dark mode frosts *white over dark*, so the alpha differs.
  static Color getGlassFill(bool isLight, {double strength = 1.0}) => isLight
      ? Colors.white.withOpacity(0.55 * strength)
      : Colors.white.withOpacity(0.14 * strength);

  static LinearGradient getCardGradient(bool isDay, {bool isLight = false}) {
    if (isLight) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.72),
          Colors.white.withOpacity(0.52),
        ],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(isDay ? 0.18 : 0.14),
        Colors.white.withOpacity(isDay ? 0.12 : 0.08),
      ],
    );
  }

  static Color getBorderColor(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.14)
      : Colors.white.withOpacity(0.26);

  static Color getDividerColor(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.09)
      : Colors.white.withOpacity(0.1);

  // --------------------------------------------------------------- accents

  static const Color accent = Color(0xFF667EEA);

  static Color getSurfaceColor(bool isLight) =>
      isLight ? Colors.white : const Color(0xFF1A1F3A);

  static Color getScrimColor(bool isLight) => isLight
      ? Colors.white.withOpacity(0.6)
      : Colors.black.withOpacity(0.5);

  static Color getRefreshIndicatorBg(bool isLight) =>
      isLight ? Colors.white : const Color(0xFF1E3C72);

  static Color getShimmerBase(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.09)
      : Colors.white.withOpacity(0.1);

  static Color getShimmerHighlight(bool isLight) => isLight
      ? const Color(0xFF10233A).withOpacity(0.16)
      : Colors.white.withOpacity(0.2);
}

/// Per-build view of [WeatherTheme], so widgets read `p.text` rather than
/// repeating `WeatherTheme.getTextColor(isLight)` at every call site.
class AppPalette {
  final bool isLight;

  const AppPalette(this.isLight);

  factory AppPalette.of(BuildContext context) =>
      AppPalette(Theme.of(context).brightness == Brightness.light);

  Color get text => WeatherTheme.getTextColor(isLight);
  Color get textSecondary => WeatherTheme.getSecondaryTextColor(isLight);
  Color get textMuted => WeatherTheme.getMutedTextColor(isLight);
  Color get icon => WeatherTheme.getIconColor(isLight);
  Color get border => WeatherTheme.getBorderColor(isLight);
  Color get divider => WeatherTheme.getDividerColor(isLight);
  Color get surface => WeatherTheme.getSurfaceColor(isLight);
  Color get scrim => WeatherTheme.getScrimColor(isLight);
  Color get shimmerBase => WeatherTheme.getShimmerBase(isLight);
  Color get shimmerHighlight => WeatherTheme.getShimmerHighlight(isLight);
  Color get refreshBackground => WeatherTheme.getRefreshIndicatorBg(isLight);

  /// Frosted panel fill. `strength` scales the tint for nested surfaces.
  Color glass([double strength = 1.0]) =>
      WeatherTheme.getGlassFill(isLight, strength: strength);

  LinearGradient card(bool isDay) =>
      WeatherTheme.getCardGradient(isDay, isLight: isLight);

  LinearGradient background(bool isDay) =>
      WeatherTheme.getBackgroundGradient(isDay, isLight: isLight);

  /// Tint a semantic colour (severity, AQI band) so it stays legible on the
  /// current ground — the same red needs more weight on a pale background.
  Color accentOn(Color color) =>
      isLight ? Color.alphaBlend(color.withOpacity(0.9), Colors.black12) : color;
}
