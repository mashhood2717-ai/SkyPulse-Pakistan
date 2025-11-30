# Push Notifications Troubleshooting Guide

## Problem Statement
"Notifications are not coming when the app is closed"

## Root Cause Analysis

The notifications aren't arriving because **the backend is not sending them through Firebase Cloud Messaging (FCM)**.

Think of it like this:
- App = Radio receiver that's turned ON and tuned to the right station ✅
- Backend = Radio broadcaster that should send signals ❌
- Firebase = The transmission infrastructure ✅

**The broadcaster (backend) is not sending any signals, so the receiver (app) gets nothing.**

---

## Verification: Is the App Ready? ✅

Run the app and check the logs. You should see:

```
✅ Firebase initialized!
✅ [PushNotifications] Initialization started...
✅ [PushNotifications] Permission granted by user
📱 [PushNotifications] FCM Token: eyJhbGc...APA91...
✅ [PushNotifications] Initialization complete
✅ [PushNotifications] Subscribed to topic: all_alerts
✅ [PushNotifications] Subscribed to topic: islamabad_alerts
```

**If you see these logs, the app is ready to receive notifications.**

---

## Quick Test: Send a Test Notification

### Method 1: Firebase Console (Easiest - 2 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **skypulse-pakistan**
3. Left menu → **Cloud Messaging**
4. Click **"Send your first message"** (or **Compose notification**)
5. Fill the form:
   ```
   Notification title:  "Test Alert"
   Notification body:   "This is a test notification from Firebase"
   ```
6. Click **Next**
7. Select target:
   ```
   Target type: Topic
   Topic name: all_alerts
   ```
8. Click **"Next"** → **"Review"** → **"Publish"**
9. **Check your device** - notification should appear in notification bar (if app is closed)

---

## Complete Setup: Send from Your Backend

### Step 1: Get Firebase Service Account Key

```
1. Firebase Console → Project Settings (gear icon)
2. Tab: "Service Accounts"
3. Click: "Generate New Private Key"
4. Save the JSON file securely
```

### Step 2: Initialize Firebase Admin SDK

**For Node.js:**
```bash
npm install firebase-admin
```

**Code:**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path-to-serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'skypulse-pakistan'
});
```

### Step 3: Send Notification

```javascript
const message = {
  notification: {
    title: 'Heavy Rain Alert',
    body: 'Heavy rain expected in Islamabad tomorrow'
  },
  data: {
    severity: 'high',
    location: 'Islamabad'
  },
  android: {
    priority: 'high',
    notification: {
      sound: 'default'
    }
  }
};

// Send to all subscribed users (via topic)
await admin.messaging().sendToTopic('all_alerts', message)
  .then(response => console.log('Message sent:', response))
  .catch(error => console.log('Error:', error));
```

---

## How Notifications Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Backend (Your Alert Service)                                │
│ - Detects a weather alert                                   │
│ - Calls Firebase Admin SDK: sendToTopic('all_alerts', msg)  │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ Firebase Cloud Messaging (FCM)                              │
│ - Routes message to all subscribed devices                  │
│ - Delivers to Android system                                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
        ┌──────────┴───────────┐
        │                      │
        ▼                      ▼
   APP IS CLOSED         APP IS OPEN
        │                      │
        ▼                      ▼
   SYSTEM NOTIFICATION   IN-APP ONLY
   (Notification Bar)    (AlertsScreen)
   Shows immediately    Shows in bell icon
```

---

## Two Notification Modes

### 1. When App is CLOSED (User Wants This)

- Firebase sends message
- Android shows in system notification bar
- User taps notification
- App launches and opens to weather data
- `onMessageOpenedApp` listener triggers

**Current Status**: ✅ Ready but no backend sending

### 2. When App is OPEN (Already Working)

- Firebase sends message
- `onMessage` listener receives it
- App stores in internal list
- No system notification shown (by design)
- User sees alert in app:
  - Red badge on bell icon (shows count)
  - Full details in AlertsScreen

**Current Status**: ✅ Fully working (but no messages coming from backend)

---

## Files You Need to Configure

### For Node.js Backend
- Create `.env` or config file with Firebase credentials
- Import `firebase-admin` package
- Create function to send notifications (example in `BACKEND_NOTIFICATION_SENDING.js`)
- Call function when alerts are detected

### For Cloudflare Workers
- Store service account in encrypted environment variable
- Use Firebase REST API to send notifications
- See example code in `BACKEND_NOTIFICATION_SENDING.js`

### For Python Backend
```python
from firebase_admin import credentials, messaging, initialize_app

cred = credentials.Certificate('serviceAccountKey.json')
initialize_app(cred)

message = messaging.Message(
    notification=messaging.Notification(
        title='Alert Title',
        body='Alert message'
    ),
    topic='all_alerts',
)

response = messaging.send(message)
print(f'Successfully sent message: {response}')
```

---

## Debugging Checklist

### App-Side ✅
- [x] Firebase initialized
- [x] FCM token generated
- [x] Permission granted
- [x] Topics subscribed (`all_alerts`)
- [x] Message handlers registered
- [x] Notification channel created in Android
- [x] App reads incoming messages

### Backend-Side ❌
- [ ] Firebase Admin SDK installed
- [ ] Service account key obtained
- [ ] Backend initialized with credentials
- [ ] Alert check triggers notification send
- [ ] Message format is correct (has notification field)
- [ ] Topic name matches app subscription

### Network/Infrastructure ✅
- [x] Device has internet connection
- [x] Firebase project is active
- [x] Android API level 21+ (app targets API 33)

---

## Expected Behavior After Setup

### App Closed, Message Sent
```
1. Backend sends to Firebase topic 'all_alerts'
2. Message routed to your device
3. Android notification bar shows notification
4. User sees: "Heavy Rain Alert" with body text
5. User taps notification
6. App launches
7. App shows alert in AlertsScreen
8. Badge on bell icon shows count
```

### App Open, Message Sent  
```
1. Backend sends to Firebase topic 'all_alerts'
2. onMessage listener triggers
3. App stores message
4. Badge on bell icon updates (count increases)
5. User clicks bell icon → sees alert in AlertsScreen
6. No system notification (intentional)
```

---

## Next Steps for You

1. **Immediate**: Test with Firebase Console (should take 2 minutes)
   - Verify notification appears on your device
   - This confirms app is ready

2. **Short-term**: Set up Firebase Admin SDK in your backend
   - Use example code from `BACKEND_NOTIFICATION_SENDING.js`
   - Create endpoint to send test notifications

3. **Integration**: Hook into your alert detection system
   - When alerts are found, send Firebase message
   - Call `sendAlertNotification()` function with alert data

---

## Support Files in This Project

- `PUSH_NOTIFICATIONS_SETUP.md` - Detailed setup instructions
- `NOTIFICATIONS_STATUS.md` - Current status and verification
- `BACKEND_NOTIFICATION_SENDING.js` - Code examples for backend
- `lib/services/push_notification_service.dart` - App-side implementation
- `lib/providers/weather_provider.dart` - Topic subscription logic

---

## Common Issues & Solutions

### "Notification still not appearing"
1. **Verify app is subscribed**: Check logs for "Subscribed to topic"
2. **Verify backend is sending**: Add console logs to backend code
3. **Check notification channel**: Should see in Android Settings → Notifications
4. **Verify internet**: Device must have active connection

### "Firebase not initialized"
- Check `lib/main.dart` - Firebase init should happen BEFORE PushNotificationService
- Check `google-services.json` exists in `android/app/`

### "Topic subscription shows error"
- Topic name must be lowercase and valid
- Check for typos in `'all_alerts'` vs `'all_alerts_'`

### "Token keeps changing"
- This is normal - token can rotate
- Only a problem if old tokens aren't cleaned up on backend

---

## Questions?

**Q: Will notifications work if I just copy this code?**
A: The app code is complete, but you need your backend to send messages through Firebase Admin SDK. That's outside the app.

**Q: Can I test without a backend?**
A: Yes! Use Firebase Console to send a test message (see Method 1 above).

**Q: What if user has notifications disabled?**
A: App requests permission on launch. If denied, notifications won't work (by design).

**Q: Do I need to modify the app?**
A: No. The app is fully configured. Just set up the backend to send.

