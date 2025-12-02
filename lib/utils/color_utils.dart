import 'package:flutter/material.dart';

/// Extension to convert withOpacity to withValues for better color handling
extension ColorOpacityExtension on Color {
  /// Returns a color with the opacity value using withValues (modern approach)
  /// Replaces deprecated withOpacity() for flutter 3.18.0+
  Color withModernOpacity(double opacity) {
    return withValues(alpha: opacity);
  }
}
