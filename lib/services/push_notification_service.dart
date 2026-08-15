import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'alert_store.dart';
import '../utils/log.dart';

// Flutter Local Notifications plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler - MUST be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  logDebug('🔔 [Background] Message received: ${message.notification?.title}');

  // Record it so the Alerts tab matches the notification tray on next launch.
  await AlertStore.addPendingPush(_alertFromMessage(message));

  // A message carrying a `notification` block is drawn by the system itself
  // while the app is backgrounded. Posting our own copy here is what produced
  // two identical entries in the shade; only data-only messages need us to
  // render them.
  if (message.notification == null) {
    await _showLocalNotification(message);
  }
}

/// Flatten an FCM message into the shape the Alerts tab renders.
Map<String, dynamic> _alertFromMessage(RemoteMessage message) {
  final data = message.data;
  return {
    'messageId': message.messageId ?? data['messageId'] ?? '',
    'title': message.notification?.title ?? data['title'] ?? 'Weather Alert',
    'message': message.notification?.body ?? data['message'] ?? '',
    'description': data['description'] ?? message.notification?.body ?? '',
    'severity': data['severity'] ?? 'medium',
    'timestamp': data['timestamp'] ??
        (message.sentTime ?? DateTime.now()).toIso8601String(),
  };
}

/// Show local notification (top-level for background access)
Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  // Android notification details
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'weather_alerts', // Channel ID - must match AndroidManifest
    'Weather Alerts', // Channel name
    channelDescription: 'Weather alerts and notifications from SkyPulse',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    icon: '@mipmap/ic_launcher',
    enableVibration: true,
    playSound: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    notification.hashCode, // Unique ID
    notification.title ?? 'Weather Alert',
    notification.body ?? '',
    notificationDetails,
    payload: message.data['route'] ?? 'alerts',
  );
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final List<RemoteMessage> _messages = [];
  static bool _initialized = false;

  /// Initialize push notifications
  static Future<void> initializePushNotifications() async {
    if (_initialized) {
      logDebug('⚠️ [PushNotifications] Already initialized');
      return;
    }

    try {
      logDebug('✅ [PushNotifications] Starting initialization...');

      // Initialize local notifications FIRST
      await _initializeLocalNotifications();

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
        logDebug('❌ [PushNotifications] Permission denied');
        _initialized = true;
        return;
      }
      logDebug('✅ [PushNotifications] Permission granted');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        logDebug('✅ [PushNotifications] FCM Token obtained');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
      }

      // Global topic only. The city topic is managed by WeatherProvider once a
      // location is known, so the device holds at most two subscriptions.
      await subscribeToTopic('all_alerts');
      await _clearLegacyBroadcastTopics();

      // Foreground messages - Show local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        logDebug('📨 [Foreground] ${message.notification?.title}');
        _messages.add(message);
        AlertStore.addPendingPush(_alertFromMessage(message));
        // The system does NOT auto-display while the app is foregrounded, so
        // this is the only copy the user sees.
        _showLocalNotification(message);
      });

      // Token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        logDebug('🔄 [PushNotifications] Token refreshed');
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('fcm_token', newToken);
        });
      });

      // Notification tap - Navigate to alerts tab
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        logDebug('📩 [Tapped] ${message.notification?.title}');
        // Navigate to alerts tab when notification is tapped
        _navigateToAlerts();
      });

      // App launched from notification - navigate to alerts
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        logDebug(
            '📩 [App Opened from Notification] ${initialMessage.notification?.title}');
        // Navigate to alerts tab after a short delay (wait for app to build)
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToAlerts();
        });
      }

      _initialized = true;
      logDebug('✅ [PushNotifications] Initialization complete!');
    } catch (e) {
      logDebug('❌ [PushNotifications] Error: $e');
    }
  }

  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        logDebug('📩 [Local Notification Tapped] ${response.payload}');
        _navigateToAlerts();
      },
    );

    // Create notification channel for Android 8.0+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'weather_alerts', // ID - must match AndroidManifest
      'Weather Alerts', // Name
      description: 'Weather alerts and notifications from SkyPulse',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    logDebug('✅ [LocalNotifications] Initialized with channel: weather_alerts');
  }

  /// Navigate to alerts tab (called when notification is tapped)
  static void _navigateToAlerts() {
    try {
      AppNavigation.navigateToAlerts();
      logDebug('📩 [PushNotifications] Navigating to Alerts tab');
    } catch (e) {
      logDebug('⚠️ [PushNotifications] Could not navigate to alerts: $e');
    }
  }

  /// City topics every install used to be subscribed to unconditionally, which
  /// meant a Karachi-only warning was delivered nationwide. Kept here solely so
  /// existing devices can be unsubscribed once on upgrade.
  static const List<String> _legacyBroadcastTopics = [
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

  static const String _legacyClearedKey = 'legacy_city_topics_cleared';
  static const String _cityTopicKey = 'subscribed_city_topic';

  /// One-shot cleanup for devices upgrading from a build that subscribed to
  /// every city. Without this they stay subscribed on the FCM server forever.
  static Future<void> _clearLegacyBroadcastTopics() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_legacyClearedKey) ?? false) return;

    logDebug('🧹 [PushNotifications] Clearing legacy city-wide subscriptions...');
    for (final topic in _legacyBroadcastTopics) {
      try {
        await _firebaseMessaging.unsubscribeFromTopic(topic);
      } catch (e) {
        // A failure here is retried on the next launch: the flag is only set
        // once the whole sweep has completed.
        logDebug('   ⚠️ Could not unsubscribe $topic: $e');
        return;
      }
    }
    await prefs.setBool(_legacyClearedKey, true);
    logDebug('   ✅ Legacy topics cleared');
  }

  /// The city topic this device is currently subscribed to, if any.
  static Future<String?> getSubscribedCityTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityTopicKey);
  }

  static Future<void> setSubscribedCityTopic(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityTopicKey, topic);
  }

  /// Subscribe to topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      logDebug('✅ Subscribed to: $topic');
    } catch (e) {
      logDebug('❌ Error subscribing to $topic: $e');
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
      logDebug('✅ Unsubscribed from: $topic');
    } catch (e) {
      logDebug('❌ Error unsubscribing: $e');
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
