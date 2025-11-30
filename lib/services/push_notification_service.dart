import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background message handler - MUST be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 [Background] Message received: ${message.notification?.title}');
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final List<RemoteMessage> _messages = [];
  static bool _initialized = false;
  static Function(List<Map<String, dynamic>>)? _onAlertsReceived;

  /// Initialize push notifications
  static Future<void> initializePushNotifications() async {
    if (_initialized) {
      print('⚠️ [PushNotifications] Already initialized');
      return;
    }

    try {
      print('✅ [PushNotifications] Starting initialization...');

      // Set background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
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

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 [Foreground] ${message.notification?.title}');
        _messages.add(message);
        _notifyListeners(message);
      });

      // Token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('🔄 [PushNotifications] Token refreshed');
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('fcm_token', newToken);
        });
      });

      // Notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📩 [Tapped] ${message.notification?.title}');
        _notifyListeners(message);
      });

      // App launched from notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _notifyListeners(initialMessage);
      }

      _initialized = true;
      print('✅ [PushNotifications] Initialization complete!');
    } catch (e) {
      print('❌ [PushNotifications] Error: $e');
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

  /// Notify listeners
  static void _notifyListeners(RemoteMessage message) {
    if (_onAlertsReceived != null) {
      final alert = {
        'title': message.notification?.title ?? 'Weather Alert',
        'message': message.notification?.body ?? '',
        'severity': message.data['severity'] ?? 'medium',
        'timestamp': DateTime.now(),
      };
      _onAlertsReceived!([alert]);
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
    final topic = cityName.toLowerCase().replaceAll(' ', '_') + '_alerts';
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

  /// Set callback
  static void setOnAlertsReceived(Function(List<Map<String, dynamic>>) callback) {
    _onAlertsReceived = callback;
  }

  /// Reinitialize
  static Future<void> reinitialize() async {
    _initialized = false;
    await initializePushNotifications();
  }
}