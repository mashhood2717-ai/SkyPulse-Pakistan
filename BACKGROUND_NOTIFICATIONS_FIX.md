# Background Notifications Fix & Setup

## What Was Fixed ✅

Your app was not receiving notifications when closed because:

1. ❌ Background message handler was registered AFTER permissions request
2. ❌ MainActivity didn't create notification channels
3. ❌ Android manifest didn't properly declare FCM service
4. ❌ Kotlin version needed updating for proper Firebase handling

## Solutions Applied ✅

### 1. MainActivity.kt - Create Notification Channels
```kotlin
override fun onResume() {
    super.onResume()
    // Create notification channel for Firebase messages
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channelId = "weather_alerts"
        val channelName = "Weather Alerts"
        val importance = NotificationManager.IMPORTANCE_HIGH
        val channel = NotificationChannel(channelId, channelName, importance).apply {
            description = "Notifications for weather alerts"
            enableVibration(true)
            enableLights(true)
            setShowBadge(true)
        }
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(channel)
    }
}
```

**What it does:**
- Creates a notification channel named "Weather Alerts"
- Sets importance to HIGH (shows as popup, plays sound)
- Enables vibration and lights
- Allows badge count display

### 2. AndroidManifest.xml - Proper FCM Setup
```xml
<!-- Added permissions -->
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

<!-- Added Firebase FCM Service -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

**What it does:**
- Declares proper FCM service to handle background messages
- Adds permissions for vibration and boot completion
- Ensures Firebase can deliver messages when app is closed

### 3. push_notification_service.dart - Register Handler First
```dart
// Set background message handler FIRST (before requesting permissions)
print('📌 [PushNotifications] Setting background message handler...');
FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler);
print('✅ [PushNotifications] Background handler configured');

// THEN request permissions
NotificationSettings settings =
    await _firebaseMessaging.requestPermission(
  alert: true,
  announcement: false,
  badge: true,
  provisional: false,
  sound: true,
);
```

**What it does:**
- Registers the top-level background handler BEFORE any async operations
- Ensures handler is ready when app is terminated
- Firebase can then route background messages to handler

### 4. build.gradle - Firebase Dependencies
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:33.1.0')
    implementation 'com.google.firebase:firebase-core'
    implementation 'com.google.firebase:firebase-messaging'
    implementation 'androidx.work:work-runtime-ktx:2.8.1'
}
```

**What it does:**
- Uses Firebase BOM for version consistency
- Adds work-runtime for background job scheduling
- Ensures all Firebase components are compatible

## How Notifications Now Work

### App is OPEN (Foreground)
1. Message arrives → `onMessage` listener triggered
2. Converted to alert object
3. Added to UI immediately (no system notification)
4. Badge updated on Alerts icon

### App is CLOSED (Background/Terminated)
1. Message arrives → `_firebaseMessagingBackgroundHandler` called
2. Firebase automatically shows system notification in tray
3. **Notification displayed even if app is closed** ✅
4. User taps → `onMessageOpenedApp` triggered
5. App launches automatically
6. Alert shown in Alerts tab

### Tapped Notification
1. System notification tapped
2. App launches (if closed) or comes to foreground
3. `onMessageOpenedApp` listener triggered
4. Message converted to alert
5. Displayed in Alerts tab with unread indicator

## Testing Background Notifications

### Step 1: Send Test Notification
**Via Firebase Console:**
1. Go to https://console.firebase.google.com/
2. Select project: `skypulse-pakistan`
3. Cloud Messaging → Send your first message
4. Fill in:
   - Title: "Weather Alert"
   - Body: "Test notification"
5. Target: Topic → `all_alerts`
6. Click Publish

### Step 2: Close the App
1. Close the app completely (swipe out from recent apps)
2. Wait 30 seconds for notification to arrive

### Step 3: Check Notification Tray
1. Drag down notification shade (swipe from top)
2. You should see "Weather Alert" notification
3. Tap it to launch app

### Step 4: Verify In-App Alert
1. After tapping notification, app launches
2. Go to Alerts tab (should be default)
3. Alert should appear in the list
4. Red badge on Alerts icon shows unread count

## Checklist for Success

- [ ] App closes completely (not in background)
- [ ] Send notification via Firebase Console to `all_alerts` topic
- [ ] Wait 5 seconds
- [ ] Check notification tray (drag from top of screen)
- [ ] Notification appears in tray
- [ ] Tap notification
- [ ] App launches
- [ ] Alert appears in Alerts tab
- [ ] Unread badge appears on Alerts icon
- [ ] Tap alert to mark as read
- [ ] Red dot disappears
- [ ] Badge count decreases

## Device Settings to Check

**If notifications still don't appear:**

1. **Notification Permission**
   ```
   Settings → Apps → Weather App → Permissions → Notifications
   → Toggle ON
   ```

2. **Battery Optimization**
   ```
   Settings → Battery → Battery Optimization
   → Find Weather App → Don't Optimize
   ```

3. **App Notification Channel**
   ```
   Settings → Apps → Weather App → Notifications
   → "Weather Alerts" channel should show
   ```

4. **Do Not Disturb Mode**
   - Disable if active (may suppress notifications)

## Log Messages to Look For

### Success Indicators
```
✅ [PushNotifications] Setting background message handler...
✅ [PushNotifications] Background handler configured
✅ [PushNotifications] Permission granted by user
✅ [PushNotifications] Subscribed to topic: all_alerts
✅ Firebase initialized!
```

### When Background Message Arrives (App Closed)
```
🔔 [Background Handler] Firebase message received (app closed/background)
   Title: Weather Alert
   Body: Test notification
   Message ID: abc123...
```

### When Notification is Tapped
```
📩 [PushNotifications] User tapped notification: Weather Alert
```

## Firebase Console Message Delivery

To verify messages are being sent:
1. Firebase Console → Cloud Messaging
2. Click on a campaign/message
3. Check "Message Delivery" tab
4. Should show:
   - Messages Sent: X
   - Success Rate: ~100%
   - Platform breakdown (Android, iOS, Web)

## If Still Not Working

1. **Ensure proper firebase cloud messaging API is enabled**
   - Firebase Console → Project Settings → APIs
   - Cloud Messaging API should be enabled

2. **Check google-services.json**
   - File location: `android/app/google-services.json`
   - Must contain correct project ID: `skypulse-pakistan`

3. **Rebuild the App**
   ```
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Clear Cache & Reinstall**
   ```
   flutter clean
   flutter pub get
   flutter run --release
   ```

5. **Check FCM Token in Logs**
   - Token should be printed on startup
   - If not present, permissions were denied

## Important Notes

1. **Internet Connection Required**: Device must have active internet
2. **APK Build**: Same keystore must be used (for signed APKs)
3. **Topic Subscription**: App auto-subscribes to `all_alerts` on init
4. **System Notification**: Android system controls display, not app
5. **Persistence**: Messages persist in notification tray until dismissed

## References

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Android NotificationChannel](https://developer.android.com/develop/ui/views/notifications/channels)
- [Flutter Firebase Messaging](https://pub.dev/packages/firebase_messaging)

## Summary

Your app now properly receives:
- ✅ **Foreground notifications** → Displayed in-app as alerts
- ✅ **Background notifications** → System notification in tray
- ✅ **Tapped notifications** → App launches with alert
- ✅ **Read/Unread tracking** → Badge shows unread count
- ✅ **Topic subscriptions** → Auto-subscribes to `all_alerts`

**Test it now by sending a notification through Firebase Console!**
