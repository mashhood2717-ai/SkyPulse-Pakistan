# Quick Start: Testing Push Notifications

This is a quick reference guide to verify your FCM setup is working correctly.

## ⚡ 5-Minute Verification Test

### Step 1: Prepare Your Device
```
1. Open the SkyPulse app
2. Grant notification permissions when prompted
3. Wait 5 seconds for Firebase to initialize
✅ You should see app logs:
   ✅ Firebase initialized!
   ✅ [PushNotifications] Initialization complete
```

### Step 2: Open Debug Screen
```
1. Look at AppBar (top-right corner)
2. Click the Bug icon 🐛 (next to my_location icon)
3. Copy your FCM Token that appears
✅ You should see:
   - A long alphanumeric token (100+ characters)
   - "Messages Received: 0"
```

### Step 3: Subscribe to Topics
```
1. In Debug Screen, note your FCM Token
2. Exit Debug Screen
3. Click my_location icon to refresh weather
✅ You should see logs:
   ✅ Subscribed to topic: all_alerts
   ✅ Subscribed to topic: [city_name]_alerts
```

### Step 4: Send Test Notification
```
1. Go to: https://console.firebase.google.com/
2. Select project: skypulse-pakistan
3. Navigation: Cloud Messaging → "Send your first message"
4. Fill in:
   - Title: "Test Alert"
   - Body: "Testing SkyPulse notifications"
5. Click Next
6. Target → Topic → Type: all_alerts
7. Click Publish
```

### Step 5: Verify on Device

**Test A: App is Running (Foreground)**
```
✅ Expected: Message appears in Alerts section
            Message count in Debug Screen increases
✅ NOT a system notification (by design - app is already open)
```

**Test B: App in Background**
```
1. Go back to home screen (don't close app)
2. Open another app or settings
3. Send notification via Firebase Console (same as Step 4)
✅ Expected: System notification appears at top
           Click it to open app to Alerts
```

**Test C: App is Completely Closed**
```
1. Close the app completely (swipe from recent apps)
2. Wait 2 seconds
3. Send notification via Firebase Console
✅ Expected: System notification appears
           Click it to launch app directly to Alerts
```

---

## 🐛 Troubleshooting Quick Fixes

### Issue: No FCM Token in Debug Screen

**Quick Fix:**
```
1. Check that notification permissions are granted
   Settings → Apps → SkyPulse → Permissions → Allow notifications
2. Close app completely
3. Reopen app
4. Wait 10 seconds
5. Open Debug Screen again
```

### Issue: Messages Show in Debug Screen but No System Notification (Closed App)

**Quick Fix:**
```
1. Open Debug Screen
2. Click "Reinitialize FCM" button
3. Wait 2 seconds
4. Close and reopen app
5. Try sending test notification again
```

### Issue: Test Notification Sent but Nothing Happens

**Quick Fix - Step 1: Verify Topic Name**
```
Open Debug Screen and check:
- Should show: ✅ Subscribed to topic: all_alerts
- If missing: Click my_location icon to trigger subscription
```

**Quick Fix - Step 2: Use Device Token Instead**
```
1. Copy token from Debug Screen
2. Go to Firebase Console
3. Send message → Target → Device tokens
4. Paste your token
5. Check if notification arrives
```

**Quick Fix - Step 3: Check Permissions**
```
Settings → Apps → SkyPulse → Permissions
- POST_NOTIFICATIONS: Must be ✅ Allowed
- If blocked: Toggle on
```

---

## 📊 How to Check Logs

### Using Android Studio Logcat
```
1. Connect device via USB
2. Open Android Studio
3. Bottom: Logcat tab
4. Filter: "com.mashhood.skypulse"
5. Look for:
   ✅ Firebase initialized
   ✅ Subscribed to topic
   📨 Message received
```

### Using adb Command
```powershell
adb logcat | findstr "skypulse"
```

### Expected Log Output
```
✅ Firebase initialized!
✅ [PushNotifications] Initialization started...
✅ [PushNotifications] Permission granted by user
📱 [PushNotifications] FCM Token: [YOUR_TOKEN_HERE]
✅ [PushNotifications] Initialization complete
✅ Subscribed to topic: all_alerts
✅ Subscribed to topic: islamabad_alerts
📨 [PushNotifications] Foreground message received: Test Alert
✅ Stored in-app (app is open - no system notification shown)
```

---

## ✅ Success Indicators

Check off each item:

- [ ] FCM Token visible in Debug Screen (not blank/error)
- [ ] Logs show "✅ Initialization complete"
- [ ] Logs show "✅ Subscribed to topic: all_alerts"
- [ ] Test notification from Firebase Console arrives
- [ ] System notification appears when app is closed
- [ ] Message count in Debug Screen increases
- [ ] Clicking "Reinitialize FCM" doesn't crash

When all are checked ✅, your setup is **WORKING CORRECTLY**.

---

## 🎯 What's Next

### For Testing/Development
```
→ See: TROUBLESHOOTING_NOTIFICATIONS.md
  For detailed debugging and advanced diagnostics
```

### For Backend Integration
```
→ See: TROUBLESHOOTING_NOTIFICATIONS.md → Backend Integration Checklist
  Code examples for sending notifications from your backend
```

### For Understanding the System
```
→ See: PUSH_NOTIFICATIONS_SETUP.md
  Complete technical documentation of the FCM setup
```

---

## 📝 Test Scenarios

### Scenario 1: Verify Foreground Reception
```
1. Open app → Go to HomeScreen
2. Send test notification
3. Expected: Alert appears in "Alerts" section
4. Expected: Message count in Debug Screen increases
✅ Foreground working
```

### Scenario 2: Verify Background Reception
```
1. Press home button (app in background)
2. Send test notification
3. Expected: System notification appears at top
4. Expected: Clicking it opens app
✅ Background working
```

### Scenario 3: Verify Multiple Messages
```
1. Open app
2. Send 5 notifications in quick succession
3. Expected: All 5 appear in Alerts section
4. Expected: Message count shows "5"
5. Expected: No messages lost
✅ Queuing working
```

### Scenario 4: Verify Recovery
```
1. After several messages, click "Reinitialize FCM"
2. Send new message
3. Expected: Notification arrives normally
✅ Recovery mechanism working
```

---

## 🔗 Quick Reference Links

| Need | File |
|------|------|
| Step-by-step debugging | `TROUBLESHOOTING_NOTIFICATIONS.md` |
| What was fixed | `FIXES_SUMMARY.md` |
| Technical details | `PUSH_NOTIFICATIONS_SETUP.md` |
| Code reference | `lib/services/push_notification_service.dart` |
| Debug UI | `lib/screens/debug_screen.dart` |

---

## ❓ FAQ

**Q: Why don't I see a system notification when the app is open?**  
A: By design - when the app is open, notifications appear in the Alerts section instead. This is better UX. System notifications only appear when app is closed.

**Q: How often are messages checked?**  
A: Messages arrive immediately via Firebase. The alert system also polls every 30 seconds as backup.

**Q: What if I miss a notification?**  
A: Go to Alerts section - all received alerts are stored there. You'll also see a badge count in the AppBar.

**Q: Can I test without Firebase Console?**  
A: For real testing yes (you need backend sending messages). For development, Firebase Console is the easiest.

**Q: Should I worry about the Kotlin version warning?**  
A: Not immediately, but Flutter will drop support soon. Can be updated later.

---

**Last Updated:** Latest FCM improvements  
**Status:** ✅ Ready to test  
**Time to Complete:** ~5 minutes
