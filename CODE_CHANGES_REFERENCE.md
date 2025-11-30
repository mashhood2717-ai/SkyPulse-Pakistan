# Code Changes Summary - Firebase Token Storage

## Files Modified

### 1. `pubspec.yaml`
**Change:** Added Firestore dependency

```yaml
# ADDED:
cloud_firestore: ^4.14.0
```

**Location:** In dependencies section with other Firebase packages

---

### 2. `lib/services/push_notification_service.dart`

#### Change 1: Added Firestore Import
```dart
// ADDED:
import 'package:cloud_firestore/cloud_firestore.dart';
```

#### Change 2: Enhanced Initial Token Saving (Line ~115)
```dart
// BEFORE:
// Save to SharedPreferences (with error handling)
try {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', token ?? '');
  print('💾 [PushNotifications] FCM Token saved to local storage');
} catch (e) {
  print('⚠️ [PushNotifications] Error saving FCM token to storage: $e');
}

// AFTER:
// Save to SharedPreferences (with error handling)
try {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('fcm_token', token ?? '');
  print('💾 [PushNotifications] FCM Token saved to local storage');
} catch (e) {
  print('⚠️ [PushNotifications] Error saving FCM token to storage: $e');
}

// Save to Firebase Firestore (with error handling) ← NEW
if (token != null && token.isNotEmpty) {
  try {
    await _saveTokenToFirebase(token);
    print('☁️ [PushNotifications] FCM Token saved to Firebase');
  } catch (e) {
    print(
        '⚠️ [PushNotifications] Error saving FCM token to Firebase: $e');
    print(
        '   Token will still work locally - Firebase save is optional');
  }
}
```

#### Change 3: Enhanced Token Refresh Listener (Line ~190)
```dart
// BEFORE:
// Listen for FCM token refresh (token changes periodically)
_firebaseMessaging.onTokenRefresh.listen((String newToken) {
  print('🔄 [PushNotifications] FCM token refreshed!');
  print('   New token: $newToken');
  // Save new token to SharedPreferences
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('fcm_token', newToken);
    print('💾 [PushNotifications] New token saved to storage');
  }).catchError((e) {
    print('⚠️ [PushNotifications] Error saving new token: $e');
  });
});

// AFTER:
// Listen for FCM token refresh (token changes periodically)
_firebaseMessaging.onTokenRefresh.listen((String newToken) {
  print('🔄 [PushNotifications] FCM token refreshed!');
  print('   New token: $newToken');
  // Save new token to SharedPreferences
  SharedPreferences.getInstance().then((prefs) {
    prefs.setString('fcm_token', newToken);
    print('💾 [PushNotifications] New token saved to local storage');
  }).catchError((e) {
    print('⚠️ [PushNotifications] Error saving new token locally: $e');
  });

  // Also save new token to Firebase ← NEW
  _saveTokenToFirebase(newToken).then((_) {
    print('☁️ [PushNotifications] New token saved to Firebase');
  }).catchError((e) {
    print(
        '⚠️ [PushNotifications] Error saving new token to Firebase: $e');
  });
});
```

#### Change 4: Enhanced Unsubscribe Method (Line ~325)
```dart
// BEFORE:
/// Unsubscribe from topic
static Future<void> unsubscribeFromTopic(String topic) async {
  try {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('✅ [PushNotifications] Unsubscribed from topic: $topic');
  } catch (e) {
    print('❌ [PushNotifications] Error unsubscribing from topic: $e');
  }
}

// AFTER:
/// Unsubscribe from topic
static Future<void> unsubscribeFromTopic(String topic) async {
  try {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('✅ [PushNotifications] Unsubscribed from topic: $topic');
    
    // If unsubscribing from all alerts, mark token as inactive ← NEW
    if (topic == 'all_alerts') {
      try {
        final token = await _firebaseMessaging.getToken();
        if (token != null && token.isNotEmpty) {
          await _deleteTokenFromFirebase(token);
        }
      } catch (e) {
        print('⚠️ [PushNotifications] Error updating Firebase on unsubscribe: $e');
      }
    }
  } catch (e) {
    print('❌ [PushNotifications] Error unsubscribing from topic: $e');
  }
}
```

#### Change 5: New Methods Added (Before `_convertMessageToAlert`)
```dart
// COMPLETELY NEW METHODS:

/// Save FCM token to Firebase Firestore for cloud tracking
/// This allows checking which devices have valid tokens from Firebase Console
static Future<void> _saveTokenToFirebase(String token) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final DateTime timestamp = DateTime.now();

    // Save token to Firestore collection 'fcm_tokens'
    // Document ID is the token itself for easy lookups
    await firestore.collection('fcm_tokens').doc(token).set({
      'token': token,
      'timestamp': timestamp,
      'lastUpdated': timestamp,
      'active': true,
      'appVersion': '1.0.0', // Can be made dynamic
      'platform': 'android', // Can be made dynamic
    }, SetOptions(merge: true));

    print(
        '✅ [Firebase] Token saved to Firestore collection "fcm_tokens"');
  } catch (e) {
    print('❌ [Firebase] Error saving token to Firestore: $e');
    // Don't throw - allow app to continue with local storage only
    rethrow;
  }
}

/// Delete FCM token from Firebase Firestore when unsubscribing
/// This marks the device as no longer active
static Future<void> _deleteTokenFromFirebase(String token) async {
  try {
    final firestore = FirebaseFirestore.instance;

    // Mark as inactive instead of deleting (for debugging)
    await firestore.collection('fcm_tokens').doc(token).update({
      'active': false,
      'lastUpdated': DateTime.now(),
      'unsubscribedAt': DateTime.now(),
    });

    print(
        '✅ [Firebase] Token marked as inactive in Firestore');
  } catch (e) {
    print('⚠️ [Firebase] Error marking token as inactive: $e');
    // Don't throw - this is non-critical
  }
}
```

---

## Summary of Changes

| Component | Change | Impact |
|-----------|--------|--------|
| **Dependencies** | Added `cloud_firestore: ^4.14.0` | Enables Firestore access |
| **Imports** | Added Firestore import | Enables document writes |
| **Token Save** | Now calls `_saveTokenToFirebase()` | Tokens saved to cloud |
| **Token Refresh** | Now calls `_saveTokenToFirebase()` | Refreshes tracked in cloud |
| **Unsubscribe** | Calls `_deleteTokenFromFirebase()` | Marks token as inactive |
| **New Methods** | `_saveTokenToFirebase()`, `_deleteTokenFromFirebase()` | Handles cloud storage |

---

## Error Handling Strategy

1. **Firestore save fails** → App continues with local storage only
2. **Network unavailable** → Exception caught, logged, not fatal
3. **Permission denied** → Graceful fallback to local storage
4. **Token empty** → Not attempted, prevents empty token saves

```dart
// Pattern used throughout:
try {
  // Attempt Firebase save
  await _saveTokenToFirebase(token);
  print('✅ Saved');
} catch (e) {
  print('⚠️ Error but continuing...');
  // App continues normally - local storage still works
}
```

---

## Testing the Changes

### Step 1: Verify Compilation
```bash
flutter analyze  # Should show only deprecation warnings
flutter pub get  # Should install cloud_firestore
```

### Step 2: Run and Monitor
```bash
flutter run -d <device_id> --verbose
```

### Step 3: Watch Logs
```bash
flutter logs | grep -E "Firebase|Token"
```

Expected output:
```
✅ [PushNotifications] FCM Token obtained on attempt 1
💾 [PushNotifications] FCM Token saved to local storage
☁️ [Firebase] Token saved to Firestore collection "fcm_tokens"
✅ [Firebase] Token saved to Firestore collection "fcm_tokens"
```

### Step 4: Check Firebase Console
```
Firestore Database > fcm_tokens collection
```

Should see new documents with structure:
```json
{
  "token": "...",
  "timestamp": "2024-01-15T10:30:00Z",
  "lastUpdated": "2024-01-15T10:30:00Z",
  "active": true,
  "appVersion": "1.0.0",
  "platform": "android"
}
```

---

## Lines Changed

| File | Lines | Type | Change |
|------|-------|------|--------|
| `pubspec.yaml` | ~100 | Addition | Added `cloud_firestore: ^4.14.0` |
| `push_notification_service.dart` | 4 | Addition | Added Firestore import |
| `push_notification_service.dart` | ~115-130 | Enhancement | Added Firebase save on initial token |
| `push_notification_service.dart` | ~190-205 | Enhancement | Added Firebase save on token refresh |
| `push_notification_service.dart` | ~325-340 | Enhancement | Added Firebase save on unsubscribe |
| `push_notification_service.dart` | ~415-465 | Addition | Added 2 new methods (~50 lines) |

**Total New/Modified Lines:** ~100 lines across 2 files

**Total File Count:** 2 files modified + 2 documentation files created

---

## Backward Compatibility

✅ **Fully backward compatible:**
- Local storage (SharedPreferences) still works exactly as before
- If Firestore fails, app continues normally
- If Firebase is not initialized, errors are caught and logged
- Existing features unaffected

---

## Production Considerations

1. **Add Authentication**
   - Link tokens to user IDs for per-user tracking
   - Use Firebase Auth before saving tokens

2. **Add Validation**
   - Verify token format before saving
   - Add retry logic for failed Firestore writes

3. **Add Analytics**
   - Track token create/refresh/delete events
   - Monitor failure rates

4. **Add Cleanup**
   - Set TTL on documents for auto-deletion
   - Archive historical data to BigQuery

5. **Update Security Rules**
   - Restrict to authenticated users only
   - Verify user ownership of tokens

See `FIREBASE_TOKEN_TRACKING.md` for detailed production setup.
