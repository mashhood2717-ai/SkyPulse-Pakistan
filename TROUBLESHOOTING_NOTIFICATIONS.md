# Troubleshooting Push Notifications - SkyPulse Pakistan

This guide helps diagnose and fix issues with Firebase Cloud Messaging (FCM) and push notifications in the SkyPulse weather app.

## 🚀 Quick Checklist

- [ ] App is running and device has FCM token visible in Debug Screen
- [ ] Device has notification permissions granted
- [ ] Firebase project is properly configured with `google-services.json` in `android/app/`
- [ ] Backend is sending FCM messages to the correct topic or device token
- [ ] Notification channel "weather_alerts" exists on Android device
- [ ] Test message sent via Firebase Console successfully

## 📱 Access the Debug Screen

1. **Open the app** and navigate to the home screen
2. **Click the Bug icon** in the top-right AppBar (red icon with `⚙️`)
3. **Copy your FCM Token** - this is your unique device identifier

### Debug Screen Shows:
- **FCM Token**: Your device's unique identifier for receiving messages
- **Message Count**: Number of messages received in current app session
- **Reinitialize Button**: Force reinit FCM if listeners seem unresponsive
- **Instructions**: Step-by-step guide for testing

---

## 🔍 Diagnostic Steps

### Step 1: Verify Firebase is Connected

**Check Terminal Logs:**
```
Look for these log messages on app startup:

✅ [PushNotifications] Initialization started...
✅ [PushNotifications] Permission granted by user
📱 [PushNotifications] FCM Token: [long token string]
✅ [PushNotifications] Initialization complete
```

**If you don't see these:**
- App might have crashed - check console for errors
- Permissions might be blocked - grant notification permissions in Android settings
- Firebase might not be initialized - check `firebase_options.dart` matches your project

### Step 2: Check Topic Subscriptions

**Look for in terminal:**
```
✅ Subscribed to topic: all_alerts
✅ Subscribed to topic: [city_name]_alerts
```

**If missing:**
- Go to HomeScreen and trigger a location fetch (click my_location icon)
- Weather provider will call `_subscribeToTopics()`
- Check logs again

### Step 3: Verify Android Notification Channel

**Run in terminal:**
```powershell
adb shell dumpsys notification | findstr weather_alerts
```

**Should show:**
- Channel ID: `weather_alerts`
- Importance: HIGH (5)
- Sound enabled
- Vibration enabled

**If not found:**
- Channel is created in `MainActivity.kt` in `onCreate()`
- Force stop and restart app: `adb shell am force-stop com.mashhood.skypulse`
- Restart app

---

## 📊 How to Test Notifications

### Method 1: Firebase Console (RECOMMENDED)

1. **Go to:** [Firebase Console](https://console.firebase.google.com/)
2. **Project:** Select "skypulse-pakistan"
3. **Navigation:** Cloud Messaging → Send your first message
4. **Fill Details:**
   - Title: "Test Alert"
   - Body: "This is a test notification"
   - Add any custom data if desired
5. **Target:**
   - Select "Topic"
   - Enter: `all_alerts`
6. **Publish**
7. **Check Phone:**
   - App in foreground: Message added to in-app list (badge updates)
   - App in background: System notification appears
   - App closed: System notification appears

### Method 2: Using Device Token

**Same steps as above, but in "Target" section:**
- Select "Device tokens"
- Paste your FCM token from Debug Screen

---

## 🚨 Common Issues & Solutions

### Issue 1: "No FCM Token in Debug Screen"

**Symptoms:**
- Debug Screen shows loading spinner forever
- Or shows "Failed to load FCM token"

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Notification permission denied | Go to Settings → App → Permissions → Allow notifications |
| Firebase not initialized | Check `firebase_options.dart` exists and matches Firebase project |
| Network issues | Check WiFi/mobile connection is working |
| App crashed on startup | Check terminal for crash logs |

**Try:**
```dart
// In Debug Screen, click "Reinitialize FCM" button
// This will restart FCM listeners
```

---

### Issue 2: Notifications Don't Appear When App is Closed

**Symptoms:**
- Notifications work when app is open (foreground)
- But nothing appears when app is closed/background

**Root Causes:**

1. **Notification Channel Not Created**
   - Solution: Force restart app
   ```powershell
   adb shell am force-stop com.mashhood.skypulse
   flutter run
   ```

2. **`google-services.json` Missing or Invalid**
   - Check: `android/app/google-services.json` exists
   - Solution: Re-download from Firebase Console → Project Settings

3. **Android Manifest Missing Permissions**
   - Check: `android/app/src/main/AndroidManifest.xml` has:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   <meta-data
       android:name="com.google.firebase.messaging.default_notification_channel_id"
       android:value="weather_alerts" />
   ```

4. **Backend Not Sending Messages**
   - Test with Firebase Console first (steps above)
   - If that works, your backend needs to call Firebase Admin SDK

---

### Issue 3: Bug Icon Disappears from AppBar

**Symptoms:**
- Bug icon visible on first load
- After navigating or some action, icon disappears
- Icon reappears only after full app restart

**Root Causes & Solutions:**

1. **Widget Tree Rebuild Issue**
   - Solution: This is a state management edge case
   - Workaround: Press back to ensure proper state restoration
   - Report: File issue if reproducible with steps

2. **AppBar Conditional Logic**
   - Check `HomeScreen` line ~220 for bug icon button in actions
   - Icon should always be present

**Debug:**
```dart
// Add to HomeScreen.dart to verify AppBar rebuilds
print('🔄 [HomeScreen] AppBar rebuilt');
```

---

### Issue 4: Messages Stop Coming After Initial Test

**Symptoms:**
- First notification works fine
- Subsequent notifications don't appear
- Device token is still valid

**Root Causes:**

1. **Firebase Listeners Detached**
   - Solution: Click "Reinitialize FCM" in Debug Screen
   - This calls `PushNotificationService.reinitialize()`

2. **Hot Reload Causing Issues**
   - Solution: Use Full Restart instead of Hot Reload
   - Run: `flutter run --no-fast-start`

3. **App Memory/Process Issues**
   - Solution: Force stop and restart
   ```powershell
   adb shell am force-stop com.mashhood.skypulse
   flutter run
   ```

4. **Topic Subscription Lost**
   - Solution: Navigate to trigger new weather fetch
   - This calls `_subscribeToTopics()` again

---

### Issue 5: Wrong FCM Token Shown

**Symptoms:**
- Every time you open Debug Screen, token changes
- Token format looks wrong (too short, invalid chars)

**Solutions:**

1. **App Not Fully Initialized**
   - Wait 3-5 seconds after app launch before opening Debug Screen
   - FCM token generation takes time

2. **Multiple Firebase Apps Initialized**
   - Check `main.dart` only calls `Firebase.initializeApp()` once
   - Check `firebase_options.dart` is correct

---

## 📋 Backend Integration Checklist

If you're sending notifications from your backend, verify:

- [ ] Backend has Firebase Admin SDK configured
- [ ] Service account JSON key is valid
- [ ] Backend sends to correct topic: `all_alerts` (global) or `[city]_alerts`
- [ ] FCM message has `notification` field (title + body)
- [ ] Optional: Add `data` field for custom handling
- [ ] Test message sent successfully via Firebase Console first

### Example Backend Code (Node.js):
```javascript
const admin = require('firebase-admin');

// Initialize
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Send to topic
await admin.messaging().send({
  notification: {
    title: 'Weather Alert',
    body: 'High winds expected in Islamabad'
  },
  data: {
    alertType: 'wind',
    city: 'Islamabad'
  },
  topic: 'all_alerts'  // or 'islamabad_alerts'
});
```

---

## 🛠️ Debugging Commands

### Check FCM Status:
```powershell
# Device logs - shows FCM registration and message handling
adb logcat | findstr firebase

# Show all app logs
adb logcat | findstr "com.mashhood.skypulse"

# Show notification system events
adb shell dumpsys notification
```

### Force Reinitialization:
```powershell
# Stop app
adb shell am force-stop com.mashhood.skypulse

# Clear app cache
adb shell pm clear com.mashhood.skypulse

# Restart
flutter run
```

### Check Permissions:
```powershell
adb shell pm dump com.mashhood.skypulse | grep NOTIFICATION
```

---

## 📞 Getting Help

If notifications still aren't working:

1. **Gather Logs:**
   - Terminal output during app startup
   - Debug Screen information (FCM token, message count)
   - Android logcat: `adb logcat > logs.txt`

2. **Test with Firebase Console:**
   - Confirm notifications work via Firebase Console
   - If they work there but not from backend, backend needs fixes
   - If they don't work via Console, FCM configuration is broken

3. **Check Common Issues:**
   - Device has notifications enabled for app
   - Android 6+ requires runtime permissions (handled by app)
   - iOS requires Apple Push Notification (APNs) certificate

4. **Full Reset (Nuclear Option):**
   ```powershell
   # Clean Flutter
   flutter clean
   
   # Rebuild completely
   flutter pub get
   
   # Uninstall from device
   adb uninstall com.mashhood.skypulse
   
   # Reinstall
   flutter run
   ```

---

## 📚 Related Files

| File | Purpose |
|------|---------|
| `lib/services/push_notification_service.dart` | FCM initialization & listeners |
| `lib/screens/debug_screen.dart` | Debug interface for testing |
| `lib/providers/weather_provider.dart` | Topic subscriptions & provider |
| `android/app/src/main/kotlin/com/mashhood/skypulse/MainActivity.kt` | Notification channel setup |
| `android/app/src/main/AndroidManifest.xml` | Android config & permissions |
| `firebase_options.dart` | Firebase project config |

---

## ✅ Success Indicators

You'll know notifications are working when:

✅ FCM Token visible in Debug Screen  
✅ Notification appears when sending via Firebase Console  
✅ Message appears in app logs: `📨 [PushNotifications] Foreground message received`  
✅ Message count increases in Debug Screen  
✅ Badge count on app icon increases  
✅ System notification appears when app is closed  

---

**Last Updated:** After FCM optimization (removed duplicate init guard added)  
**Tested On:** Android 13+, Flutter 3.x, Firebase Messaging 14.7.10
