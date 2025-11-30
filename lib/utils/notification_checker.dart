import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive notification system health checker
class NotificationChecker {
  static Future<Map<String, dynamic>> checkNotificationHealth() async {
    print('\n🔍 Starting comprehensive notification health check...\n');

    final results = <String, dynamic>{};

    // 1. Check Firebase
    results['firebase'] = await _checkFirebase();

    // 2. Check Permissions
    results['permissions'] = await _checkPermissions();

    // 3. Check FCM Token
    results['fcmToken'] = await _checkFCMToken();

    // 4. Check Storage
    results['storage'] = await _checkStorage();

    // 5. Summary
    results['summary'] = _generateSummary(results);

    return results;
  }

  static Future<Map<String, dynamic>> _checkFirebase() async {
    print('📊 Checking Firebase...');
    final results = <String, dynamic>{};

    try {
      final messaging = FirebaseMessaging.instance;

      // Check if Firebase is initialized
      results['initialized'] = true;
      results['initialized_detail'] = 'Firebase is initialized';

      // Get notification settings
      final settings = await messaging.getNotificationSettings();
      results['authStatus'] = settings.authorizationStatus.toString();

      // Check app is foreground
      results['foreground_status'] = 'Unknown (requires runtime check)';
    } catch (e) {
      results['error'] = true;
      results['error_detail'] = e.toString();
    }

    print('   ✓ Firebase check complete\n');
    return results;
  }

  static Future<Map<String, dynamic>> _checkPermissions() async {
    print('🔐 Checking Permissions...');
    final results = <String, dynamic>{};

    try {
      final notificationStatus = await Permission.notification.status;

      results['notification_status'] = notificationStatus.toString();
      results['notification_granted'] = notificationStatus.isGranted;
      results['notification_denied'] = notificationStatus.isDenied;
      results['notification_permanently_denied'] =
          notificationStatus.isPermanentlyDenied;

      // Provide remediation for denied permissions
      if (notificationStatus.isDenied) {
        results['remediation'] =
            'User must grant notification permission in app settings';
      } else if (notificationStatus.isPermanentlyDenied) {
        results['remediation'] =
            'Permission permanently denied. User must enable in Android Settings > Apps > Skypulse > Notifications';
      } else if (notificationStatus.isGranted) {
        results['status'] = '✅ Permission Granted';
      }
    } catch (e) {
      results['error'] = true;
      results['error_detail'] = e.toString();
    }

    print('   ✓ Permission check complete\n');
    return results;
  }

  static Future<Map<String, dynamic>> _checkFCMToken() async {
    print('🔑 Checking FCM Token...');
    final results = <String, dynamic>{};

    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      results['has_token'] = token != null && token.isNotEmpty;
      results['token_length'] = token?.length ?? 0;
      results['token_preview'] = token != null
          ? '${token.substring(0, 20)}...${token.substring(token.length - 10)}'
          : 'NO TOKEN';

      if (token == null || token.isEmpty) {
        results['warning'] = 'No FCM token! Notifications will not work.';
        results['possible_causes'] = [
          'Firebase not initialized',
          'No internet connection',
          'Permission denied',
          'Google Play Services not available',
        ];
      } else {
        results['status'] = '✅ FCM Token Available';
      }
    } catch (e) {
      results['error'] = true;
      results['error_detail'] = e.toString();
    }

    print('   ✓ FCM Token check complete\n');
    return results;
  }

  static Future<Map<String, dynamic>> _checkStorage() async {
    print('💾 Checking Local Storage...');
    final results = <String, dynamic>{};

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('fcm_token');

      results['has_stored_token'] =
          storedToken != null && storedToken.isNotEmpty;
      results['stored_token_length'] = storedToken?.length ?? 0;
      results['stored_token_preview'] = storedToken != null
          ? '${storedToken.substring(0, 20)}...${storedToken.substring(storedToken.length - 10)}'
          : 'NO TOKEN';

      // Get all keys in storage for debugging
      final allKeys = prefs.getKeys();
      results['storage_keys'] = allKeys.toList();

      if (storedToken == null || storedToken.isEmpty) {
        results['warning'] = 'No stored token in SharedPreferences';
      } else {
        results['status'] = '✅ Token Stored';
      }
    } catch (e) {
      results['error'] = true;
      results['error_detail'] = e.toString();
    }

    print('   ✓ Storage check complete\n');
    return results;
  }

  static Map<String, dynamic> _generateSummary(Map<String, dynamic> results) {
    print('📋 Generating Summary...\n');

    final summary = <String, dynamic>{};

    // Overall health
    bool isHealthy = true;
    final issues = <String>[];

    // Check Firebase
    if (results['firebase']['error'] == true) {
      isHealthy = false;
      issues.add('❌ Firebase not initialized');
    }

    // Check Permissions
    if (results['permissions']['notification_denied'] == true) {
      isHealthy = false;
      issues.add('❌ Notification permission denied');
    }
    if (results['permissions']['notification_permanently_denied'] == true) {
      isHealthy = false;
      issues.add('❌ Notification permission permanently denied');
    }

    // Check FCM Token
    if (results['fcmToken']['has_token'] == false) {
      isHealthy = false;
      issues.add('❌ No FCM token available');
    }

    // Check Storage
    if (results['storage']['has_stored_token'] == false) {
      isHealthy = false;
      issues.add('⚠️ No stored token (token may be lost on app restart)');
    }

    summary['overall_health'] =
        isHealthy ? '✅ HEALTHY' : '❌ ISSUES FOUND';
    summary['issue_count'] = issues.length;
    summary['issues'] = issues;

    if (isHealthy) {
      summary['status_message'] =
          'Your notification system appears to be working correctly!';
      summary['next_steps'] = [
        'Send a test alert from your server',
        'Check that you\'re subscribed to the correct topics',
        'If still not receiving alerts, check your network connectivity',
      ];
    } else {
      summary['status_message'] =
          'Notification system has issues that need to be fixed.';
      summary['next_steps'] = [
        'Address the issues listed above',
        'Force stop the app: Settings > Apps > Skypulse > Force Stop',
        'Restart the app',
        'Verify permissions are granted',
        'Try sending a test alert',
      ];
    }

    // Print summary to console
    print('═══════════════════════════════════════════════════════');
    print('NOTIFICATION SYSTEM HEALTH CHECK SUMMARY');
    print('═══════════════════════════════════════════════════════\n');
    print('Status: ${summary['overall_health']}');
    print('Issues Found: ${summary['issue_count']}\n');

    if (issues.isNotEmpty) {
      print('Issues:');
      for (final issue in issues) {
        print('  $issue');
      }
      print('');
    }

    print('Next Steps:');
    int stepNum = 1;
    for (final step in summary['next_steps'] as List) {
      print('  $stepNum. $step');
      stepNum++;
    }
    print('');
    print('═══════════════════════════════════════════════════════\n');

    return summary;
  }

  /// Print full diagnostic report
  static Future<void> printFullDiagnostics() async {
    final results = await checkNotificationHealth();

    print('\n📊 FULL DIAGNOSTIC REPORT');
    print('═══════════════════════════════════════════════════════\n');

    // Firebase
    print('🔥 FIREBASE:');
    final firebase = results['firebase'] as Map<String, dynamic>;
    firebase.forEach((key, value) {
      print('   $key: $value');
    });
    print('');

    // Permissions
    print('🔐 PERMISSIONS:');
    final permissions = results['permissions'] as Map<String, dynamic>;
    permissions.forEach((key, value) {
      print('   $key: $value');
    });
    print('');

    // FCM Token
    print('🔑 FCM TOKEN:');
    final fcmToken = results['fcmToken'] as Map<String, dynamic>;
    fcmToken.forEach((key, value) {
      if (value is List) {
        print('   $key:');
        for (final item in value) {
          print('      - $item');
        }
      } else {
        print('   $key: $value');
      }
    });
    print('');

    // Storage
    print('💾 STORAGE:');
    final storage = results['storage'] as Map<String, dynamic>;
    storage.forEach((key, value) {
      if (value is List) {
        print('   $key: ${value.length} items');
        for (final item in value) {
          print('      - $item');
        }
      } else {
        print('   $key: $value');
      }
    });
    print('');

    // Summary
    print('📋 SUMMARY:');
    final summary = results['summary'] as Map<String, dynamic>;
    summary.forEach((key, value) {
      if (value is List) {
        print('   $key:');
        for (final item in value) {
          print('      $item');
        }
      } else {
        print('   $key: $value');
      }
    });

    print('\n═══════════════════════════════════════════════════════\n');
  }
}
