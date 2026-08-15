import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';

/// Durable state for weather alerts.
///
/// The alert list itself is re-fetched from the API, so anything the *user*
/// did to it has to be stored separately or the next refresh undoes it:
/// dismissing an alert or tapping "Clear All" used to last only until the
/// following poll, and read state reset on every cold start.
///
/// Also holds alerts that arrived by push while the app was closed, so the
/// Alerts tab and the notification tray agree.
class AlertStore {
  static const String _dismissedKey = 'alert_dismissed_ids';
  static const String _readKey = 'alert_read_ids';
  static const String _pendingKey = 'alert_pending_pushes';

  /// How long a dismissal is remembered. Long enough to outlive any alert's
  /// natural life, short enough that the keys cannot grow without bound.
  static const Duration retention = Duration(days: 7);

  /// Stable identity for an alert across refreshes.
  ///
  /// The API does not always send a messageId, so fall back to a hash of the
  /// fields that actually identify the event.
  static String idFor(Map<String, dynamic> alert) {
    final explicit = (alert['messageId'] ?? alert['id'])?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final title = (alert['title'] ?? '').toString();
    final message = (alert['message'] ?? '').toString();
    final timestamp = (alert['timestamp'] ?? '').toString();
    return '${title}_${message}_$timestamp'.hashCode.toRadixString(16);
  }

  // ------------------------------------------------------------- id sets

  /// Stored as id -> epoch millis of when it was marked, so entries can expire.
  static Future<Map<String, int>> _loadStamped(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final cutoff =
          DateTime.now().subtract(retention).millisecondsSinceEpoch;
      return {
        for (final entry in decoded.entries)
          if (entry.value is int && entry.value as int >= cutoff)
            entry.key: entry.value as int,
      };
    } catch (e) {
      logDebug('[AlertStore] Could not read $key: $e');
      return {};
    }
  }

  static Future<void> _saveStamped(String key, Map<String, int> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, json.encode(value));
  }

  static Future<Set<String>> dismissedIds() async =>
      (await _loadStamped(_dismissedKey)).keys.toSet();

  static Future<Set<String>> readIds() async =>
      (await _loadStamped(_readKey)).keys.toSet();

  static Future<void> markDismissed(Iterable<String> ids) async {
    final current = await _loadStamped(_dismissedKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      current[id] = now;
    }
    await _saveStamped(_dismissedKey, current);
  }

  static Future<void> markRead(String id) async {
    final current = await _loadStamped(_readKey);
    current[id] = DateTime.now().millisecondsSinceEpoch;
    await _saveStamped(_readKey, current);
  }

  // ------------------------------------------------- pushes while closed

  /// Called from the FCM background isolate, so it must not touch app state.
  static Future<void> addPendingPush(Map<String, dynamic> alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingKey) ?? <String>[];

      final id = idFor(alert);
      final alreadyQueued = existing.any((raw) {
        try {
          return idFor(json.decode(raw) as Map<String, dynamic>) == id;
        } catch (_) {
          return false;
        }
      });
      if (alreadyQueued) return;

      existing.add(json.encode(alert));
      // Keep the queue bounded; the API list is the source of truth for older
      // alerts anyway.
      if (existing.length > 50) {
        existing.removeRange(0, existing.length - 50);
      }
      await prefs.setStringList(_pendingKey, existing);
    } catch (e) {
      logDebug('[AlertStore] Could not queue push: $e');
    }
  }

  /// Drains alerts delivered while the app was not running.
  static Future<List<Map<String, dynamic>>> takePendingPushes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? <String>[];
    if (raw.isEmpty) return [];

    await prefs.remove(_pendingKey);

    final alerts = <Map<String, dynamic>>[];
    for (final entry in raw) {
      try {
        alerts.add(Map<String, dynamic>.from(json.decode(entry) as Map));
      } catch (_) {
        // Skip anything that did not survive the round trip.
      }
    }
    return alerts;
  }
}
