import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

// Background message handler - MUST be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [Background] Message received: ${message.notification?.title}');
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final List<RemoteMessage> _messages = [];
  static bool _initialized = false;

  /// Initialize push notifications
  static Future<void> initializePushNotifications() async {
    if (_initialized) {
      print('⚠️ [PushNotifications] Already initialized');
      return;
    }

    try {
      print('✅ [PushNotifications] Starting initialization...');

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Request permission
      NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('❌ [PushNotifications] Permission denied');
        _initialized = true;
        return;
      }
      print('✅ [PushNotifications] Permission granted');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✅ [PushNotifications] FCM Token obtained');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }

      // Subscribe to topics
      await _subscribeToAllTopics();

      // Foreground messages - OPTIMIZED: Only log, don't notify UI
      // Firebase notifications are handled natively
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [Foreground] ${message.notification?.title}');
        _messages.add(message);
        // Removed: _notifyListeners(message); - causes extra UI refreshes
      });

      // Token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [PushNotifications] Token refreshed');
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('fcm_token', newToken);
        });
      });

      // Notification tap - Navigate to alerts tab
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📩 [Tapped] ${message.notification?.title}');
        // Navigate to alerts tab when notification is tapped
        _navigateToAlerts();
      });

      // App launched from notification - navigate to alerts
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        print(
            '📩 [App Opened from Notification] ${initialMessage.notification?.title}');
        // Navigate to alerts tab after a short delay (wait for app to build)
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToAlerts();
        });
      }

      _initialized = true;
      print('✅ [PushNotifications] Initialization complete!');
    } catch (e) {
      print('❌ [PushNotifications] Error: $e');
    }
  }

  /// Navigate to alerts tab (called when notification is tapped)
  static void _navigateToAlerts() {
    try {
      AppNavigation.navigateToAlerts();
      print('📩 [PushNotifications] Navigating to Alerts tab');
    } catch (e) {
      print('⚠️ [PushNotifications] Could not navigate to alerts: $e');
    }
  }

  /// Subscribe to all alert topics
  static Future<void> _subscribeToAllTopics() async {
    final topics = [
      'all_alerts',
      'islamabad_alerts',
      'lahore_alerts',
      'karachi_alerts',
      'peshawar_alerts',
      'quetta_alerts',
      'multan_alerts',
      'faisalabad_alerts',
      'rawalpindi_alerts',
      'hazro_alerts',
      'mailsi_city_alerts',
    ];

    print('📢 [PushNotifications] Subscribing to ${topics.length} topics...');

    for (String topic in topics) {
      try {
        await _firebaseMessaging.subscribeToTopic(topic);
        print('   ✅ $topic');
      } catch (e) {
        print('   ⚠️ Failed: $topic');
      }
    }
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to: $topic');
    } catch (e) {
      print('❌ Error subscribing to $topic: $e');
    }
  }

  /// Subscribe to city alerts
  static Future<void> subscribeToCityAlerts(String cityName) async {
    final topic = '${cityName.toLowerCase().replaceAll(' ', '_')}_alerts';
    await subscribeToTopic(topic);
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from: $topic');
    } catch (e) {
      print('❌ Error unsubscribing: $e');
    }
  }

  /// Get FCM token
  static Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Get stored token
  static Future<String?> getStoredFCMToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Get messages
  static List<RemoteMessage> getMessages() => _messages;

  /// Get message count
  static int getMessageCount() => _messages.length;

  /// Clear messages
  static void clearMessages() => _messages.clear();

  /// Reinitialize
  static Future<void> reinitialize() async {
    _initialized = false;
    await initializePushNotifications();
  }
}
