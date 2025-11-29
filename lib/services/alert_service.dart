import 'package:http/http.dart' as http;
import 'dart:convert';

class AlertService {
  // Your Cloudflare Worker endpoint
  static const String _alertApiBase =
      'https://skypulse-alerts.mashhood2717.workers.dev';

  /// Check alerts for user's current location
  Future<List<Map<String, dynamic>>> checkAlertsForLocation(
    double latitude,
    double longitude,
  ) async {
    try {
      print(
          '🚨 [AlertService] Checking alerts for Lat: $latitude, Lon: $longitude');

      final url =
          Uri.parse('$_alertApiBase/alerts/check?lat=$latitude&lon=$longitude');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Alert API timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);

        print('✅ [AlertService] Found ${alerts.length} active alerts');
        for (var alert in alerts) {
          print('   - ${alert['title']}: ${alert['message']}');
        }

        return alerts;
      } else {
        print(
            '⚠️ [AlertService] Failed to fetch alerts: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [AlertService] Error: $e');
      return []; // Return empty list on error - alerts are optional
    }
  }

  /// Get alert history (last 24 hours)
  Future<List<Map<String, dynamic>>> getAlertHistory() async {
    try {
      print('📋 [AlertService] Fetching alert history');

      final url = Uri.parse('$_alertApiBase/alerts/history');

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Alert API timeout'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? []);

        print('✅ [AlertService] Got ${alerts.length} alerts from history');
        return alerts;
      } else {
        print(
            '⚠️ [AlertService] Failed to fetch history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ [AlertService] Error: $e');
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
