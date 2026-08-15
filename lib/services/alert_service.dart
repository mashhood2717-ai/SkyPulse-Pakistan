import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/log.dart';

/// Raised when the alert service could not be reached.
///
/// Kept distinct from an empty result: "no alerts for your area" and "we
/// couldn't check" look identical to a user otherwise, and the second one
/// matters during severe weather.
class AlertServiceUnavailable implements Exception {
  final String reason;
  const AlertServiceUnavailable(this.reason);

  @override
  String toString() => 'AlertServiceUnavailable: $reason';
}

class AlertService {
  /// Override at build time once the worker sits behind a weatherwalay.com
  /// hostname:
  ///   flutter build appbundle --dart-define=ALERT_API_BASE=https://alerts.weatherwalay.com
  static const String _alertApiBase = String.fromEnvironment(
    'ALERT_API_BASE',
    defaultValue: 'https://skypulse-alerts.mashhood2717.workers.dev',
  );

  /// Check alerts for user's current location.
  ///
  /// Throws [AlertServiceUnavailable] if the service could not be reached.
  Future<List<Map<String, dynamic>>> checkAlertsForLocation(
    double latitude,
    double longitude,
  ) async {
    logDebug('🚨 [AlertService] Checking alerts for $latitude, $longitude');

    final url =
        Uri.parse('$_alertApiBase/alerts/check?lat=$latitude&lon=$longitude');

    late final http.Response response;
    try {
      response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const AlertServiceUnavailable('timeout'),
          );
    } on AlertServiceUnavailable {
      rethrow;
    } catch (e) {
      throw AlertServiceUnavailable(e.toString());
    }

    if (response.statusCode != 200) {
      throw AlertServiceUnavailable('HTTP ${response.statusCode}');
    }

    try {
      final data = jsonDecode(response.body);
      final alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);
      logDebug('✅ [AlertService] Found ${alerts.length} active alerts');
      return alerts;
    } catch (e) {
      throw AlertServiceUnavailable('malformed response: $e');
    }
  }

  /// Get alert history (last 24 hours)
  Future<List<Map<String, dynamic>>> getAlertHistory() async {
    try {
      logDebug('📋 [AlertService] Fetching alert history');

      final url = Uri.parse('$_alertApiBase/alerts/history');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Alert API timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);

        logDebug('✅ [AlertService] Got ${alerts.length} alerts from history');
        return alerts;
      } else {
        logDebug(
            '⚠️ [AlertService] Failed to fetch history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      logDebug('❌ [AlertService] Error: $e');
      return [];
    }
  }

  /// Format alert for display
  static String formatAlertMessage(Map<String, dynamic> alert) {
    final title = alert['title'] ?? 'Alert';
    final message = alert['message'] ?? '';
    final severity = alert['severity'] ?? 'medium';

    final icon = _getSeverityIcon(severity);
    return '$icon $title\n$message';
  }

  /// Get severity icon
  static String _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🚨';
      case 'high':
        return '⚠️';
      case 'medium':
        return '📍';
      case 'low':
        return 'ℹ️';
      default:
        return '📢';
    }
  }

  /// Get severity color (as hex string)
  static String getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '#FF5252'; // Red
      case 'high':
        return '#FF9800'; // Orange
      case 'medium':
        return '#FFC107'; // Yellow
      case 'low':
        return '#4CAF50'; // Green
      default:
        return '#2196F3'; // Blue
    }
  }

  /// Get severity as a readable string
  static String getSeverityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Critical';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'low':
        return 'Low';
      default:
        return 'Unknown';
    }
  }
}
