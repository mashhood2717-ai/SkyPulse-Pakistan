# Push Notifications Setup Guide

## Current Implementation Status ✅

The Flutter app is **fully configured to receive push notifications**:

1. ✅ Firebase Cloud Messaging (FCM) initialized
2. ✅ Notification permissions granted (Android 13+)
3. ✅ Topic subscriptions active:
   - `all_alerts` (global alerts topic)
   - `{city}_alerts` (city-specific topic, e.g., `islamabad_alerts`)
4. ✅ Notification channel created in Android (NotificationManager)
5. ✅ Background message handler set up
6. ✅ Foreground message handler set up
7. ✅ Firebase configuration (`google-services.json`) properly configured

## How It Works

### When App is Closed (Background/Terminated)
1. Backend sends message to Firebase topic (e.g., `all_alerts`)
2. Firebase Cloud Messaging routes to all subscribed devices
3. Android system displays notification in notification bar
4. User taps notification → app launches → `onMessageOpenedApp` triggered

### When App is Open (Foreground)
1. Backend sends message to Firebase topic
2. Firebase Cloud Messaging routes to subscribed devices
3. `onMessage` listener triggered in app
4. App stores message in internal list (no system notification shown)
5. User sees alert count badge in AppBar + can view alerts in AlertsScreen

## What You Need to Do on Backend

To send push notifications, use Firebase Admin SDK in your backend (Node.js example):

```javascript
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert('/path/to/serviceAccountKey.json'),
  projectId: 'skypulse-pakistan'
});

// Send to all_alerts topic
const message = {
  notification: {
    title: 'Weather Alert',
    body: 'Heavy rain expected in Islamabad'
  },
  data: {
    severity: 'high',
    location: 'Islamabad'
  },
  android: {
    priority: 'high'
  }
};

admin.messaging().sendToTopic('all_alerts', message)
  .then((response) => {
    console.log('Message sent:', response);
  })
  .catch((error) => {
    console.log('Error:', error);
  });

// Or send to city-specific topic
admin.messaging().sendToTopic('islamabad_alerts', message)
  .then((response) => {
    console.log('Message sent to Islamabad:', response);
  })
  .catch((error) => {
    console.log('Error:', error);
  });
```

## Firebase Admin SDK Setup

1. **Get Service Account Key**:
   - Go to Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Save as `serviceAccountKey.json`

2. **Install Firebase Admin SDK** (Node.js):
   ```bash
   npm install firebase-admin
   ```

3. **Send Messages** using the code example above

## Testing Notifications

### Option 1: Use Firebase Console (Manual Testing)
1. Go to Firebase Console → Cloud Messaging
2. Click "Send Your First Message"
3. Title: "Test Alert"
4. Body: "This is a test notification"
5. Target: Topic → Enter `all_alerts`
6. Click "Publish"
7. Check if notification appears on device

### Option 2: Use Firebase Admin SDK
See code example in "What You Need to Do on Backend" section

### Option 3: Via Cloudflare Worker
If you want to send from your alerting backend:
```javascript
// In your Cloudflare Worker
const admin = require('firebase-admin');

export default {
  async fetch(request) {
    if (request.method === 'POST') {
      const data = await request.json();
      
      const message = {
        notification: {
          title: data.title,
          body: data.message
        },
        data: {
          severity: data.severity || 'medium'
        },
        android: {
          priority: 'high'
        }
      };
      
      await admin.messaging().sendToTopic('all_alerts', message);
      return new Response('Notification sent');
    }
  }
};
```

## Troubleshooting

### Notifications Not Appearing (App Closed)
- ✅ Check: App is subscribed to topics (see logs: "Subscribed to topic: all_alerts")
- ✅ Check: Notification channel exists in Android (created in MainActivity)
- ❌ Check: Backend is actually sending messages through Firebase Admin SDK
  - This is the most common issue - ensure messages are being sent

### Notifications Not Appearing (App Open)
- This is correct behavior - notifications are shown in-app only via:
  - Alert count badge in AppBar (red dot)
  - Click bell icon to see AlertsScreen with all alerts

### Firebase Configuration Issues
- Verify `google-services.json` is in `android/app/`
- Check `project_id` matches Firebase Console project
- Ensure Firebase is initialized before creating PushNotificationService

## Current App FCM Token

When you run the app, check the logs for:
```
📱 [PushNotifications] FCM Token: <token_here>
```

This token uniquely identifies the device. You can also use it to:
- Test sending to specific device (not just topics)
- Debug delivery issues
- Track device subscriptions

## Files Involved

- **Dart Code**:
  - `lib/services/push_notification_service.dart` - FCM initialization & handlers
  - `lib/providers/weather_provider.dart` - Topic subscriptions (`_subscribeToTopics`)
  - `lib/main.dart` - Firebase initialization

- **Android Config**:
  - `android/app/google-services.json` - Firebase configuration
  - `android/app/src/main/kotlin/com/mashhood/skypulse/MainActivity.kt` - Notification channel creation
  - `android/app/src/main/AndroidManifest.xml` - Permissions & Firebase meta-data

## Questions?

1. **Are notifications being sent from backend?** 
   - Add logging to verify backend is calling Firebase Admin SDK

2. **Is notification channel being created?**
   - Check Android logcat for channel creation (happens in MainActivity.onCreate)

3. **Is app subscribed to topics?**
   - Check logs for: "✅ [PushNotifications] Subscribed to topic: all_alerts"

