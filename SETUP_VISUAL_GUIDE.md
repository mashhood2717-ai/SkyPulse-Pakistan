# Firebase Token Storage - Visual Setup Guide

## 🎯 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SKYPULSE APP (Android)                   │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │         PushNotificationService                         │ │
│  ├────────────────────────────────────────────────────────┤ │
│  │                                                         │ │
│  │  1. Initialize → Request Permissions                  │ │
│  │  2. Get FCM Token from Firebase                        │ │
│  │  3. Save Locally (SharedPreferences) ✅              │ │
│  │  4. Save to Cloud (Firestore) ✨ NEW               │ │
│  │                                                         │ │
│  │  Listen for Token Refresh:                            │ │
│  │  → Save Locally + Cloud                               │ │
│  │                                                         │ │
│  │  On Unsubscribe:                                       │ │
│  │  → Mark as Inactive in Cloud                          │ │
│  │                                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│           │                            │                     │
│           ▼                            ▼                     │
│  ┌──────────────────┐      ┌──────────────────────────────┐ │
│  │ SharedPreferences│      │   Cloud Firestore            │ │
│  │  (Local Storage) │      │ Collection: fcm_tokens       │ │
│  ├──────────────────┤      ├──────────────────────────────┤ │
│  │ fcm_token:       │      │ Doc ID: <token_value>        │ │
│  │ "eYf...xyz"      │      │ {                            │ │
│  │                  │      │   token: "eYf...xyz"         │ │
│  │ (Local backup)   │      │   timestamp: <date>          │ │
│  └──────────────────┘      │   lastUpdated: <date>        │ │
│                            │   active: true               │ │
│                            │   appVersion: "1.0.0"        │ │
│                            │   platform: "android"        │ │
│                            │ }                            │ │
│                            │                              │ │
│                            │ (Cloud tracking)             │ │
│                            └──────────────────────────────┘ │
│                                     │                       │
│                                     ▼                       │
│                              ☁️ Firebase Console            │
│                                Firestore Dashboard          │
│                            (Real-time visibility)           │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Token Lifecycle Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                          APP STARTS                                   │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Initialize Push Notifications                                        │
│  └─ Request Notification Permissions from User                       │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│  Get FCM Token from Firebase (with retry logic)                      │
│  └─ Attempt 1, 2, 3 if needed                                        │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                ┌────────────┴─────────────┐
                │                          │
                ▼                          ▼
   ┌──────────────────────┐   ┌───────────────────────────────┐
   │ Save Locally         │   │ Save to Cloud ✨ NEW        │
   │ (SharedPreferences)  │   │ (Firestore)                   │
   │                      │   │                               │
   │ fcm_token:           │   │ Collection: fcm_tokens        │
   │ "eYf...xyz"          │   │ Doc ID: "eYf...xyz"           │
   │                      │   │ Fields:                       │
   │ ✅ Persistent       │   │  - token                      │
   │ ✅ Fast access      │   │  - timestamp                  │
   │ ✅ Offline backup   │   │  - lastUpdated                │
   │                      │   │  - active: true               │
   └──────────────────────┘   │                               │
                              └───────────────────────────────┘
                                          │
                                          ▼
                           ☁️ Available in Firebase Console
                              for real-time monitoring
                
         ┌─────────────────────────────────────────────┐
         │   Later: Firebase refreshes token           │
         │   (Happens periodically, Firebase internal) │
         └────────────────────┬────────────────────────┘
                              │
                   ┌──────────┴──────────┐
                   │                     │
                   ▼                     ▼
         Save locally again    Save to cloud again ✨
         (update SharedPrefs)  (update lastUpdated)
                   │                     │
                   └──────────┬──────────┘
                              ▼
                ✅ App continues using new token
                ✅ Tokens synced across storage
```

---

## 🔄 Real-Time Token Updates

```
TIMELINE:
─────────────────────────────────────────────────────────────

Device 1 (Samsung A12):
├─ 10:30:00 → App start, token acquired
│   ├─ Local: ✅ fcm_token = "aaa111"
│   └─ Cloud: ✅ Firestore doc created, active=true
├─ 10:35:00 → Firebase refresh
│   ├─ Local: ✅ fcm_token = "aaa222"
│   └─ Cloud: ✅ Firestore updated, lastUpdated=10:35:00
└─ 10:40:00 → User unsubscribes
    ├─ Local: fcm_token still exists (backup)
    └─ Cloud: ✅ active=false, unsubscribedAt=10:40:00

Device 2 (iPhone 14):
├─ 10:32:00 → App start, token acquired
│   ├─ Local: ✅ fcm_token = "bbb111"
│   └─ Cloud: ✅ Firestore doc created, active=true
└─ 10:45:00 → Still receiving alerts
    ├─ Local: ✅ fcm_token = "bbb111"
    └─ Cloud: ✅ active=true, lastUpdated=10:45:00

🎯 RESULT: Firebase Console shows 2 active devices!
```

---

## 📱 Firebase Console Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│ Firebase Console                                             │
│ Project: SkyPulse                                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  📊 Firestore Database > Collections                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ fcm_tokens                                            │  │
│  ├───────────────────────────────────────────────────────┤  │
│  │                                                       │  │
│  │ 📄 aaa111bbb222...ccc333                            │  │
│  │ ├─ token: "aaa111bbb222...ccc333"                   │  │
│  │ ├─ timestamp: Jan 15, 2024, 10:30:00 AM UTC        │  │
│  │ ├─ lastUpdated: Jan 15, 2024, 10:35:15 AM UTC      │  │
│  │ ├─ active: true ✅                                  │  │
│  │ ├─ appVersion: "1.0.0"                             │  │
│  │ └─ platform: "android"                             │  │
│  │                                                       │  │
│  │ 📄 ddd444eee555...fff666                            │  │
│  │ ├─ token: "ddd444eee555...fff666"                   │  │
│  │ ├─ timestamp: Jan 15, 2024, 10:32:00 AM UTC        │  │
│  │ ├─ lastUpdated: Jan 15, 2024, 10:45:30 AM UTC      │  │
│  │ ├─ active: true ✅                                  │  │
│  │ ├─ appVersion: "1.0.0"                             │  │
│  │ └─ platform: "ios"                                 │  │
│  │                                                       │  │
│  │ 📄 ggg777hhh888...iii999                            │  │
│  │ ├─ token: "ggg777hhh888...iii999"                   │  │
│  │ ├─ timestamp: Jan 14, 2024, 8:30:00 AM UTC         │  │
│  │ ├─ lastUpdated: Jan 15, 2024, 10:40:00 AM UTC      │  │
│  │ ├─ active: false ❌                                 │  │
│  │ ├─ unsubscribedAt: Jan 15, 2024, 10:40:00 AM UTC   │  │
│  │ ├─ appVersion: "1.0.0"                             │  │
│  │ └─ platform: "android"                             │  │
│  │                                                       │  │
│  │ 📊 Summary:                                         │  │
│  │ • Total tokens: 3                                  │  │
│  │ • Active tokens: 2 ✅                              │  │
│  │ • Inactive tokens: 1 ❌                            │  │
│  │ • Last activity: 10:45:30 AM                       │  │
│  │                                                       │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🧪 Quick Verification Checklist

```
╔═══════════════════════════════════════════════════════════════════╗
║           FIREBASE TOKEN STORAGE VERIFICATION                     ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║ ✅ SETUP COMPLETE?                                               ║
║    □ Cloud Firestore dependency added to pubspec.yaml           ║
║    □ Import added: import 'package:cloud_firestore/...'        ║
║    □ flutter pub get completed                                   ║
║    □ No compilation errors (flutter analyze)                    ║
║                                                                   ║
║ ✅ APP RUNNING?                                                   ║
║    □ App launches without errors                                 ║
║    □ firebase_messaging initializes                             ║
║    □ Notifications permissions requested                         ║
║                                                                   ║
║ ✅ LOGS SHOWING FIREBASE SAVES?                                 ║
║    □ "☁️ [Firebase] Token saved to Firestore collection"       ║
║    □ No errors in console logs                                   ║
║    □ "lastUpdated" updates on token refresh                     ║
║                                                                   ║
║ ✅ FIRESTORE CONSOLE SHOWS TOKENS?                              ║
║    □ Can navigate to Firestore > fcm_tokens collection          ║
║    □ Documents appear with token values                         ║
║    □ Fields match expected schema                                ║
║    □ active: true for current device                            ║
║    □ lastUpdated is recent                                       ║
║                                                                   ║
║ ✅ MULTIPLE DEVICES?                                             ║
║    □ Different tokens for each device                            ║
║    □ Each device's token appears in Firestore                   ║
║    □ All showing active: true                                    ║
║    □ Timestamps vary by device                                   ║
║                                                                   ║
║ ✅ LOCAL STORAGE STILL WORKS?                                    ║
║    □ Token persists locally (SharedPreferences)                 ║
║    □ Can retrieve with adb shell (if needed)                    ║
║    □ Survives app restart                                        ║
║    □ Matches cloud token value                                   ║
║                                                                   ║
║ ✅ ERROR SCENARIOS?                                              ║
║    □ Firebase save error doesn't crash app                       ║
║    □ App continues with local storage only                      ║
║    □ Permissions error handled gracefully                        ║
║    □ Network error doesn't block notifications                   ║
║                                                                   ║
║ ✅ TOKEN REFRESH?                                                ║
║    □ Token refreshes automatically                               ║
║    □ New token saved to Firestore                                ║
║    □ lastUpdated timestamp updates                               ║
║    □ active remains true                                         ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

All items checked? ✅ SUCCESS! Firebase token tracking is working!
```

---

## 🚀 Deployment Steps

```
STEP 1: Local Testing
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ cd flutter_weather_app
$ flutter pub get                    ✅ Install Firestore
$ flutter run -d <device_id>        ✅ Run on device
$ flutter logs | grep Firebase      ✅ Monitor logs
→ Open Firebase Console → Firestore → fcm_tokens
→ Verify tokens appearing

STEP 2: Test Multiple Devices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ flutter run -d device1
$ flutter run -d device2            ✅ Run on 2nd device
→ Open Firebase Console
→ Verify 2 different tokens showing

STEP 3: Test Token Refresh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Let app run for 5-10 minutes
→ Firebase will refresh tokens periodically
→ Check Console: lastUpdated should update
→ Log shows: "New token saved to Firebase"

STEP 4: Update Firestore Rules
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Go to Firebase Console > Firestore > Rules
Update to:

  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      match /fcm_tokens/{token} {
        allow read, write: if request.auth != null;
      }
    }
  }

→ Publish rules

STEP 5: Build Release APK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ flutter build apk --release
→ APK located at: build/app/outputs/flutter-app.apk
→ Ready to distribute

STEP 6: Monitor Production
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Firebase Console > Firestore > fcm_tokens
→ Monitor active token count daily
→ Track token refresh patterns
→ Identify inactive devices
```

---

## 🔍 Monitoring Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│ REAL-TIME METRICS (Firebase Console)                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  📊 Token Statistics                                         │
│  ├─ Total Tokens: 47                                        │
│  ├─ Active Tokens: 45 ✅ (95.7%)                            │
│  ├─ Inactive Tokens: 2 ❌ (4.3%)                            │
│  └─ Last Updated: 2 minutes ago                             │
│                                                               │
│  📈 Token Refresh Rate                                      │
│  ├─ Refreshes (last 24h): 89                                │
│  ├─ Average Refresh Interval: 8 hours                       │
│  └─ Devices with Recent Refresh: 42                         │
│                                                               │
│  🗓️ Timeline (last 7 days)                                  │
│  └─ New Tokens Created: 12                                  │
│  └─ Tokens Deactivated: 3                                   │
│  └─ Token Refresh Events: 156                               │
│                                                               │
│  ⚠️ Alerts & Issues                                         │
│  ├─ No Firestore save errors                                │
│  ├─ All tokens active and healthy                           │
│  └─ No anomalies detected                                   │
│                                                               │
│  🎯 Recommendations                                         │
│  ├─ Enable TTL on old inactive tokens                       │
│  └─ Consider archiving historical data                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎓 Learning Resources

| Topic | Resource | Time |
|-------|----------|------|
| Firestore Basics | `FIREBASE_TOKEN_TRACKING.md` | 10 min |
| Code Changes | `CODE_CHANGES_REFERENCE.md` | 5 min |
| Troubleshooting | `FIREBASE_TOKEN_TRACKING.md` (Section 4) | 10 min |
| Setup Summary | `FIREBASE_TOKEN_SETUP_SUMMARY.md` | 5 min |
| Main README | `README.md` | 15 min |

---

## ✅ Success Indicators

```
✅ WORKING PROPERLY when:
  • App logs show "☁️ [Firebase] Token saved"
  • Firebase Console shows new token documents
  • lastUpdated field is recent
  • active field is true for active devices
  • Different tokens appear for different devices
  • Logs show no Firebase errors

❌ NOT WORKING if:
  • No documents in fcm_tokens collection
  • Firestore permission errors in logs
  • lastUpdated timestamp is old/stale
  • active field is false (unless intentional)
  • Same token appears for multiple devices (shouldn't happen)
  • Firebase errors block app startup
```

---

**Status: ✅ Ready to Deploy**

Your app now has dual-storage FCM token tracking!
