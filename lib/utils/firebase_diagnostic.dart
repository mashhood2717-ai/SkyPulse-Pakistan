import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseDiagnostic {
  static Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      // 1. Check Firebase Messaging instance
      FirebaseMessaging.instance;
      diagnostics['firebaseInitialized'] = true;
    } catch (e) {
      diagnostics['firebaseInitialized'] = false;
      diagnostics['firebaseError'] = e.toString();
      return diagnostics;
    }

    try {
      // 2. Check notification permission status
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      diagnostics['notificationPermissionStatus'] =
          settings.authorizationStatus.toString();
      diagnostics['alertPermission'] = settings.alert.toString();
      diagnostics['soundPermission'] = settings.sound.toString();
      diagnostics['badgePermission'] = settings.badge.toString();
    } catch (e) {
      diagnostics['permissionCheckError'] = e.toString();
    }

    try {
      // 3. Check FCM Token
      final token = await FirebaseMessaging.instance.getToken();
      diagnostics['fcmToken'] = token;
      diagnostics['fcmTokenExists'] = token != null && token.isNotEmpty;
    } catch (e) {
      diagnostics['fcmTokenError'] = e.toString();
    }

    try {
      // 4. Check if token is stored in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');
      diagnostics['storedFcmToken'] = storedToken;
      diagnostics['storedTokenExists'] =
          storedToken != null && storedToken.isNotEmpty;
    } catch (e) {
      diagnostics['storedTokenError'] = e.toString();
    }

    return diagnostics;
  }

  static Future<String> getDiagnosticsText() async {
    final diag = await getDiagnostics();
    final buffer = StringBuffer();

    buffer.writeln('=== FIREBASE DIAGNOSTICS ===');
    buffer.writeln('');
    buffer.writeln(
        'Firebase Initialized: ${diag['firebaseInitialized'] ?? 'unknown'}');
    if (diag['firebaseError'] != null) {
      buffer.writeln('Firebase Error: ${diag['firebaseError']}');
    }
    buffer.writeln('');

    buffer.writeln('--- NOTIFICATIONS PERMISSIONS ---');
    buffer.writeln(
        'Auth Status: ${diag['notificationPermissionStatus'] ?? 'unknown'}');
    buffer.writeln('Alert: ${diag['alertPermission'] ?? 'unknown'}');
    buffer.writeln('Sound: ${diag['soundPermission'] ?? 'unknown'}');
    buffer.writeln('Badge: ${diag['badgePermission'] ?? 'unknown'}');
    if (diag['permissionCheckError'] != null) {
      buffer.writeln('Error: ${diag['permissionCheckError']}');
    }
    buffer.writeln('');

    buffer.writeln('--- FCM TOKEN ---');
    buffer.writeln('FCM Token Exists: ${diag['fcmTokenExists'] ?? false}');
    if (diag['fcmToken'] != null) {
      final token = diag['fcmToken'] as String;
      if (token.length > 50) {
        buffer.writeln('Token: ${token.substring(0, 50)}...');
      } else {
        buffer.writeln('Token: $token');
      }
    }
    if (diag['fcmTokenError'] != null) {
      buffer.writeln('Token Error: ${diag['fcmTokenError']}');
    }
    buffer.writeln('');

    buffer.writeln('--- STORED TOKEN (SharedPreferences) ---');
    buffer
        .writeln('Stored Token Exists: ${diag['storedTokenExists'] ?? false}');
    if (diag['storedFcmToken'] != null) {
      final token = diag['storedFcmToken'] as String;
      if (token.length > 50) {
        buffer.writeln('Token: ${token.substring(0, 50)}...');
      } else {
        buffer.writeln('Token: $token');
      }
    }
    if (diag['storedTokenError'] != null) {
      buffer.writeln('Error: ${diag['storedTokenError']}');
    }

    return buffer.toString();
  }
}
