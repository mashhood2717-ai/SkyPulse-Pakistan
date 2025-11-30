# Firebase Token Tracking Guide

## Overview

The Skypulse app now stores FCM tokens in two places:
1. **Local Storage (SharedPreferences)** — For offline backup and quick access
2. **Firebase Firestore** — For cloud-based tracking and visibility across devices

This dual storage approach ensures:
- ✅ Tokens persist even if Firebase is temporarily unavailable
- ✅ Cloud visibility for debugging alert delivery issues
- ✅ Central dashboard to see which devices have active notification setup
- ✅ Historical tracking of token changes and device activity

---

## How It Works

### Token Lifecycle

1. **Initial Token Acquisition**
   - App starts → requests FCM token from Firebase
   - Retries up to 3 times if token is empty
   - Saves to SharedPreferences (local backup)
   - Saves to Firestore (cloud tracking) ✨ NEW

2. **Token Refresh**
   - FCM refreshes token periodically (Firebase handles timing)
   - New token is immediately saved to SharedPreferences
   - New token is immediately saved to Firestore ✨ NEW
   - App continues using new token without restart

3. **Token Deactivation**
   - If user unsubscribes from notifications
   - Token is marked as `active: false` in Firestore
   - Historical data preserved for debugging

### Firestore Collection Structure

**Collection:** `fcm_tokens`
**Document ID:** The FCM token itself (for easy lookups)

#### Document Fields:
```json
{
  "token": "eYf...xyz",                          // FCM token value
  "timestamp": "2024-01-15T10:30:00.000Z",      // When first created
  "lastUpdated": "2024-01-15T10:35:00.000Z",    // Last refresh
  "active": true,                                 // Is token valid/subscribed
  "appVersion": "1.0.0",                         // App version using this token
  "platform": "android",                         // Device platform
  "unsubscribedAt": "2024-01-15T11:00:00.000Z"  // When deactivated (if applicable)
}
```

---

## Verification Methods

### Method 1: Firebase Console (Easiest for Cloud Tokens)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (SkyPulse/Weather App)
3. Click **Firestore Database** in left sidebar
4. Select collection **`fcm_tokens`**
5. You'll see all stored tokens with metadata:
   - ✅ Count of active tokens
   - ✅ When each token was last updated
   - ✅ Which tokens are still active vs. inactive
   - ✅ Device info and app versions

**What to Look For:**
- `"active": true` = Device can receive notifications
- `"active": false` = Device disabled notifications
- Recent `lastUpdated` timestamp = Token is fresh

### Method 2: Android Console Logs (Real-Time)

While app is running, open Android logcat:

```bash
flutter logs
```

Look for these log lines:

```
✅ [PushNotifications] FCM Token obtained on attempt 1
💾 [PushNotifications] FCM Token saved to local storage
☁️ [PushNotifications] FCM Token saved to Firebase          ← NEW!
```

**Token Refresh:**
```
🔄 [PushNotifications] FCM token refreshed!
💾 [PushNotifications] New token saved to local storage
☁️ [PushNotifications] New token saved to Firebase          ← NEW!
```

### Method 3: Direct Firestore Query

If you want to query tokens programmatically:

```dart
final firestore = FirebaseFirestore.instance;

// Get all active tokens
final activeTokens = await firestore
    .collection('fcm_tokens')
    .where('active', isEqualTo: true)
    .get();

print('Active tokens: ${activeTokens.docs.length}');
for (var doc in activeTokens.docs) {
  print('Token: ${doc.id}');
  print('Last updated: ${doc['lastUpdated']}');
}
```

### Method 4: Check Firestore Rules & Permissions

Make sure your Firestore has proper rules to allow reading/writing tokens:

```javascript
// Recommended Firestore rules for development:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow authenticated users to write their tokens
    match /fcm_tokens/{token} {
      allow read, write: if request.auth != null;
    }
  }
}

// For production with authentication:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /fcm_tokens/{token} {
      allow read: if request.auth != null && request.auth.uid == resource.data.userId;
      allow write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

### Method 5: App Diagnostic Screen

The app has a built-in verification utility. To access it, look for the notification checker in your app's settings or logs:

```dart
// In code, you can call:
final diagnostics = await PushNotificationService.verifyNotificationSetup();
print(diagnostics);
```

Returns:
```json
{
  "permissionStatus": "AuthorizationStatus.authorized",
  "authorizationGranted": true,
  "hasToken": true,
  "tokenValue": "eYf...xyz",
  "hasStoredToken": true,
  "storedTokenValue": "eYf...xyz",
  "isInitialized": true,
  "messageCount": 5,
  "hasCallback": true
}
```

### Method 6: SharedPreferences Local Check

Check if token is stored locally on the device:

```bash
adb shell
run-as com.mashhood.skypulse
cat /data/data/com.mashhood.skypulse/shared_prefs/com.example.weather_app.xml
```

Look for:
```xml
<string name="fcm_token">eYf...xyz</string>
```

### Method 7: Monitor Token Refresh Events

Set up a Firestore listener to monitor real-time token updates:

```dart
// Listen for token updates in real-time
FirebaseFirestore.instance
    .collection('fcm_tokens')
    .where('active', isEqualTo: true)
    .snapshots()
    .listen((snapshot) {
  print('Active tokens changed: ${snapshot.docs.length}');
  for (var doc in snapshot.docs) {
    print('  - ${doc.id.substring(0, 20)}... (updated: ${doc['lastUpdated']})');
  }
});
```

---

## Troubleshooting

### Issue: Tokens saved locally but NOT in Firestore

**Possible Causes:**
1. No internet connection when app initialized
2. Firestore rules blocking writes
3. Firebase project not configured correctly

**Solutions:**
```bash
# Check logs for specific error:
flutter logs | grep "Error saving token to Firebase"

# Verify Firebase setup:
firebase projects list
firebase use your-project-id

# Check Firestore rules:
firebase firestore:indexes:list
```

### Issue: Token exists in Firestore but app not receiving alerts

**Possible Causes:**
1. Device not subscribed to alert topics
2. Firebase topic permissions misconfigured
3. Cloud Function sending alerts to wrong topic

**Solutions:**
- Verify in logs: `✅ [PushNotifications] Subscribed to global topic: all_alerts`
- Check Firestore that `active: true`
- Test by sending test notification from Firebase Console > Cloud Messaging

### Issue: Old tokens accumulating in Firestore

**Solutions:**
- Set up TTL (Time-To-Live) on documents:
  ```dart
  // In Firestore, go to Data tab > Manage collections > TTL policies
  // Set field "timestamp" with 90 days TTL for auto-cleanup
  ```

- Or manually clean old inactive tokens:
  ```bash
  firebase firestore:delete fcm_tokens --recursive
  # This deletes all, then they'll be recreated on next app launch
  ```

---

## Testing Token Storage

### Quick Test Flow

1. **Launch App**
   ```bash
   flutter run -d <device_id>
   ```

2. **Check Console Logs**
   - Look for: `☁️ [Firebase] Token saved to Firestore collection "fcm_tokens"`
   - Verify no errors

3. **Open Firebase Console**
   - Navigate to Firestore > fcm_tokens collection
   - Confirm new document appeared with `active: true`

4. **Force Token Refresh** (optional)
   ```dart
   // In app or via debug code:
   await PushNotificationService.refreshFCMToken();
   ```

5. **Verify Firestore Update**
   - Document's `lastUpdated` timestamp should be recent
   - Token value should match what's in app logs

### Integration Test

Send a test alert and verify end-to-end:

```bash
# From Firebase Console > Cloud Messaging > Send your first message
# Or use Firebase CLI:
firebase firestore:import export.json
```

---

## Configuration Notes

### For Development

Firestore rules can be permissive:
```javascript
allow read, write: if true;  // NOT for production!
```

### For Production

Implement user authentication:

```dart
// In main.dart or initialization code:
FirebaseAuth.instance.signInAnonymously();

// Then use authenticated rules:
allow read, write: if request.auth != null;
```

---

## Next Steps

1. ✅ **Verify Initial Setup**
   - Run app on device
   - Check console logs for Firebase save messages
   - Confirm document appears in Firestore Console

2. **Add User Association** (Optional)
   - Link tokens to user accounts in Firestore
   - Enable per-user token management

3. **Add Analytics** (Optional)
   - Track token refresh frequency
   - Monitor active device count over time
   - Identify devices with stale tokens

4. **Implement Cleanup** (Optional)
   - Auto-delete inactive tokens after 30 days
   - Archive historical data for analysis

---

## Quick Reference

| Component | Storage | Scope | Persistence |
|-----------|---------|-------|-------------|
| FCM Token | LocalStorage (SharedPreferences) | Single device | Until app uninstall |
| FCM Token | Firestore (`fcm_tokens`) | Cloud | Until manual delete |
| Token Refresh Events | Firestore (`lastUpdated`) | Cloud | Historical tracking |
| Active Status | Firestore (`active` field) | Cloud | Real-time |

---

## Security Considerations

- Tokens are sensitive; treat like passwords
- Use Firestore security rules to restrict access
- Consider encrypting tokens at rest in local storage
- Monitor for token leaks in logs
- Rotate old tokens periodically

---

**For questions or issues, check:**
1. Console logs: `flutter logs | grep "Firebase\|Token"`
2. Firebase Console > Cloud Messaging diagnostics
3. Firestore Console > Rules tab for permission issues
