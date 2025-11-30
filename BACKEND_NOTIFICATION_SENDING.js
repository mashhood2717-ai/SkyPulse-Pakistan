// Cloudflare Worker - Send Alerts as Push Notifications
// This is an example of how your alert backend should send Firebase Cloud Messaging notifications

// ============================================
// Option 1: Simple Firebase Admin SDK (if using Node.js backend)
// ============================================

const admin = require('firebase-admin');

// Initialize Firebase Admin (use environment variables for sensitive data)
admin.initializeApp({
  credential: admin.credential.cert({
    projectId: process.env.FIREBASE_PROJECT_ID,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  }),
  projectId: process.env.FIREBASE_PROJECT_ID
});

/**
 * Send a weather alert as a push notification to all subscribed users
 * @param {Object} alert - Alert object with {title, message, severity}
 * @param {String} city - City name for city-specific topic
 */
async function sendAlertNotification(alert, city = null) {
  try {
    const message = {
      notification: {
        title: alert.title,
        body: alert.message
      },
      data: {
        severity: alert.severity || 'medium',
        city: city || 'global',
        timestamp: new Date().toISOString()
      },
      android: {
        priority: alert.severity === 'critical' ? 'high' : 'normal',
        notification: {
          sound: 'default',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'mutable-content': 1
          }
        }
      }
    };

    // Send to global topic
    await admin.messaging().sendToTopic('all_alerts', message);
    console.log('✅ Notification sent to all_alerts:', alert.title);

    // Send to city-specific topic if provided
    if (city) {
      const cityTopic = city.toLowerCase().replace(/\s+/g, '_') + '_alerts';
      await admin.messaging().sendToTopic(cityTopic, message);
      console.log(`✅ Notification sent to ${cityTopic}:`, alert.title);
    }

    return { success: true, sentTo: ['all_alerts', ...(city ? [cityTopic] : [])] };
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    throw error;
  }
}

/**
 * Send notification to specific device by FCM token
 * @param {String} token - Device FCM token
 * @param {Object} alert - Alert object
 */
async function sendNotificationToDevice(token, alert) {
  try {
    const message = {
      notification: {
        title: alert.title,
        body: alert.message
      },
      data: {
        severity: alert.severity || 'medium'
      },
      android: {
        priority: 'high'
      }
    };

    await admin.messaging().sendToDevice(token, message);
    console.log('✅ Notification sent to device:', token);
    return { success: true };
  } catch (error) {
    console.error('❌ Error sending to device:', error);
    throw error;
  }
}

// ============================================
// Option 2: Cloudflare Worker with Firebase REST API
// ============================================

/**
 * Send notifications using Firebase REST API (works in Cloudflare Workers)
 * @param {String} topic - Topic name (e.g., 'all_alerts')
 * @param {Object} notification - {title, body}
 * @param {Object} data - Custom data
 */
async function sendViaFirebaseAPI(topic, notification, data = {}) {
  const firebaseProjectId = 'skypulse-pakistan'; // Your project ID
  const accessToken = await getFirebaseAccessToken();

  const message = {
    message: {
      topic: topic,
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: data,
      android: {
        priority: 'HIGH'
      }
    }
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      },
      body: JSON.stringify(message)
    }
  );

  if (!response.ok) {
    throw new Error(`Firebase API error: ${await response.text()}`);
  }

  return response.json();
}

/**
 * Get Firebase access token using service account
 */
async function getFirebaseAccessToken() {
  const serviceAccount = JSON.parse(atob(env.FIREBASE_SERVICE_ACCOUNT_B64));
  
  const assertion = createJWT(
    serviceAccount,
    'https://oauth2.googleapis.com/token'
  );

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${assertion}`
  });

  const data = await response.json();
  return data.access_token;
}

// ============================================
// Example Usage in Alert Checking
// ============================================

/**
 * Called whenever alerts are updated
 * Sends notifications for new or high-severity alerts
 */
async function handleAlertUpdate(alerts, city) {
  for (const alert of alerts) {
    try {
      // Send notification for all high/critical alerts
      if (['critical', 'high'].includes(alert.severity)) {
        await sendAlertNotification(alert, city);
      }
    } catch (error) {
      console.error('Failed to send alert notification:', error);
      // Don't fail the whole process if one notification fails
    }
  }
}

/**
 * API endpoint to test sending notifications
 * POST /api/send-test-notification
 * Body: {
 *   "title": "Test Alert",
 *   "message": "This is a test",
 *   "severity": "medium",
 *   "city": "Islamabad"
 * }
 */
async function handleTestNotification(request) {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  try {
    const data = await request.json();
    
    await sendAlertNotification(
      {
        title: data.title,
        message: data.message,
        severity: data.severity || 'medium'
      },
      data.city
    );

    return new Response(JSON.stringify({ 
      success: true, 
      message: 'Notification sent' 
    }), { status: 200 });
  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), { status: 500 });
  }
}

// ============================================
// Integration Points
// ============================================

/*
After checking alerts, call this in your alert checking logic:

async function checkAlerts(latitude, longitude) {
  // ... get alerts from API ...
  
  const alerts = await getAlertsForLocation(latitude, longitude);
  
  // Send notifications for new/important alerts
  await handleAlertUpdate(alerts, 'Islamabad');
  
  // Store alerts in database, etc...
}

*/

// ============================================
// Testing: Manual cURL command
// ============================================

/*
curl -X POST https://your-domain.com/api/send-test-notification \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Heavy Rain Alert",
    "message": "Heavy rain expected in Islamabad",
    "severity": "high",
    "city": "Islamabad"
  }'
*/

// ============================================
// Firebase Console Test (Easiest)
// ============================================

/*
1. Go to Firebase Console (https://console.firebase.google.com)
2. Select project "skypulse-pakistan"
3. Go to "Cloud Messaging" tab
4. Click "Send your first message"
5. Enter:
   - Title: "Test Alert"
   - Body: "This is a test notification"
   - Target: Topic → "all_alerts"
6. Click "Publish"
7. Check your device for notification
*/

// ============================================
// Exports for module usage
// ============================================

module.exports = {
  sendAlertNotification,
  sendNotificationToDevice,
  sendViaFirebaseAPI,
  handleAlertUpdate,
  handleTestNotification
};

