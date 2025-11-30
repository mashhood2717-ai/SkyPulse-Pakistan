# Alert Delivery Troubleshooting & Deployment Guide

## Status: Alerts Stopped Working

Your notifications were working initially but have stopped. This guide will help you diagnose and fix the issue.

---

## IMMEDIATE ACTION PLAN (Try These First)

### 1. **Grant Notification Permission**
- Open **Settings** on your Android phone
- Go to **Apps → Skypulse**
- Tap **Permissions**
- Enable **Notifications**
- Return to the app

### 2. **Force Stop and Restart**
- Open **Settings** → **Apps** → **Skypulse**
- Tap **Force Stop**
- Wait 5 seconds
- Open the app again
- Wait 30 seconds for alerts to refresh

### 3. **Disable Battery Optimization**
- Open **Settings** → **Battery** (or Power)
- Find **Battery Optimization** or **Adaptive Battery**
- Search for **Skypulse** in the apps list
- Tap **Don't Optimize** or remove from optimization

### 4. **Disable Do Not Disturb (DND)**
- Some phones block notifications in DND mode
- Check your notification settings aren't silenced
- Go to **Settings** → **Sound & Vibration**
- Ensure notifications are not muted

### 5. **Check Network Connectivity**
- Make sure you have a working internet connection
- Try **Cellular** and **WiFi** separately
- Firebase needs connectivity to receive messages

### 6. **Reinstall the App**
- Uninstall Skypulse completely
- Clear app cache in **Settings** → **Apps** → **Skypulse** → **Storage** → **Clear Cache**
- Restart your phone
- Reinstall from the APK

---

## DIAGNOSTIC CHECK

### Run the Diagnostic Tool
Open the Skypulse app and check the console logs:

```
🔍 Starting comprehensive notification health check...

📊 NOTIFICATION SYSTEM HEALTH CHECK SUMMARY
═══════════════════════════════════════════════════════

Status: ✅ HEALTHY  OR  ❌ ISSUES FOUND
Issues Found: 0 or [list of issues]
```

**Interpret the Results:**

| Issue | Meaning | Solution |
|-------|---------|----------|
| ❌ Firebase not initialized | Firebase couldn't start | Reinstall app, check google-services.json |
| ❌ Notification permission denied | You rejected the permission | Re-enable in Settings > Apps > Skypulse > Permissions |
| ❌ Notification permission permanently denied | Permission blocked | Go to Settings > Apps > Skypulse > Permissions and enable |
| ❌ No FCM token available | Can't register device | Restart app, check internet connection |
| ⚠️ No stored token | Token gets lost on restart | This will be fixed on next startup |

---

## VERIFICATION STEPS

After applying fixes, verify alerts are working:

### Step 1: Check Console Logs
When you open the app, you should see:
```
✅ Firebase initialized successfully!
📱 Permission status: GRANTED
🔔 Initializing push notifications...
✅ Push notifications initialized!
💾 FCM Token saved to local storage
✅ Subscribed to global topic: all_alerts
```

### Step 2: Check Notification Channel
Your phone should have created a notification channel:
- Go to **Settings** → **Apps** → **Skypulse**
- Look for **Notifications**
- You should see a channel called **weather_alerts**
- Importance should be set to **HIGH**

### Step 3: Send a Test Alert
Ask your admin to send a test weather alert to the `all_alerts` topic via Firebase Cloud Messaging. You should receive it within 5-10 seconds.

### Step 4: Check Alert Reception
When you receive the alert:
- You should see a notification in your system tray
- It should show on the **Alerts** tab in the app
- It should have a red unread indicator

---

## COMMON ISSUES & FIXES

### Issue: "No FCM Token" in Diagnostic
**Causes:**
- Firebase not properly initialized
- Internet connection lost
- Google Play Services not available
- Notification permission denied

**Fix:**
1. Ensure internet is working (try WiFi and cellular)
2. Force stop app and restart
3. Check notification permissions are GRANTED
4. Uninstall and reinstall the app

### Issue: "Permission Denied" in Diagnostic
**Causes:**
- You declined permission when asked
- Permission was revoked in settings

**Fix:**
- Go to **Settings** → **Apps** → **Skypulse** → **Permissions**
- Enable **Notifications**
- Restart the app

### Issue: "Alerts Come Late or Not At All"
**Causes:**
- Battery optimization killing the app
- Do Not Disturb mode enabled
- Network connectivity issues
- Topic subscription not persisting

**Fix:**
1. Disable battery optimization (see step 3 above)
2. Turn off DND mode
3. Check internet connection
4. Force stop and restart app to re-subscribe to topics

### Issue: "Token Exists But Still No Alerts"
**Causes:**
- Not subscribed to the correct topic
- Firebase configuration issue
- Server not sending to the right topic

**Fix:**
1. Check you're subscribed to `all_alerts` topic
2. Verify your phone has internet access
3. Restart the app to re-subscribe
4. Contact admin to verify server is sending alerts

---

## FOR FAMILY MEMBERS (Deployment)

When distributing the APK to family members:

### Before Installing
1. Ensure they have **Android 8.0 or higher**
2. Check they have **Google Play Services** installed
3. Ensure they have **Internet connection** (WiFi or cellular)

### During Installation
1. Tap the APK file to install
2. Grant all requested permissions
3. When prompted: **Grant Notification Permission**

### After Installation
1. Open Skypulse
2. Wait 30 seconds for initialization
3. Confirm the notification channel was created:
   - **Settings** → **Apps** → **Skypulse** → **Notifications** → should show "weather_alerts"
4. Have them follow the **IMMEDIATE ACTION PLAN** above

### Verify It Works
1. Ask them to open the app
2. Check console for success logs
3. Send a test alert from server
4. They should receive it within 5-10 seconds
5. Alert appears in both system tray AND Alerts tab

---

## WHAT'S BEEN IMPLEMENTED FOR RELIABILITY

### ✅ Automatic Recovery
- FCM token saved to local storage (persists on app restart)
- Token refresh listener (updates token automatically when it expires)
- Auto-subscription to topics on app launch
- Retry logic for failed topic subscriptions (retries after 2 seconds)

### ✅ Comprehensive Initialization
- Enhanced error messages for each initialization step
- Permission status checking with specific remediation steps
- Multiple token fetch attempts (up to 3 times)
- Graceful degradation if permissions are denied

### ✅ Improved Logging
- Emojis and symbols for easy scanning
- Verbose status messages at each step
- Clear indication of what's working vs what's not
- Helpful hints for troubleshooting

### ✅ All Message States Handled
- **Foreground** (app open): Shows in Alerts tab
- **Background** (app minimized): Shows in system tray
- **Terminated** (app closed): Shows in system tray, opens app when tapped
- **Tapped**: Opens app and shows alert details

---

## DEBUG LOGS TO LOOK FOR

### Success Indicators
```
✅ Firebase initialized successfully!
📱 Permission status: GRANTED or PROVISIONAL
🔔 Initializing push notifications...
🔑 FCM Token obtained on attempt 1
💾 FCM Token saved to local storage
✅ Subscribed to global topic: all_alerts
📨 Foreground message received
📩 User tapped notification
📥 App launched from terminated state via notification
```

### Problem Indicators
```
❌ Firebase initialization failed
❌ Permission denied by user
❌ No FCM Token obtained!
⚠️ FCM token is empty
⚠️ Failed to auto-subscribe to all_alerts
⚠️ Error saving FCM token to storage
```

---

## When to Contact Support

If you've tried all steps above and alerts still aren't working:

1. **Collect diagnostic data:**
   - Screenshot the console logs from app startup
   - Take a screenshot of Settings > Apps > Skypulse > Permissions
   - Note your Android version
   - Note your phone model

2. **Check these server-side issues:**
   - Is your alert server properly configured with Firebase?
   - Is it sending to the correct topic (`all_alerts` or city-specific)?
   - Are the message fields correct (title, body, data)?
   - Is your FCM project key correct?

3. **Provide to support:**
   - Your diagnostic logs
   - Screenshots from steps above
   - What you've already tried
   - Your Android version and phone model
   - Any error messages you see

---

## Timeline

**Alerts worked initially** → ✅ Proof of concept works
- This means Firebase is correctly configured
- Your phone was receiving messages
- Issue is likely: permissions, battery optimization, or token refresh

**Alerts stopped after** → 🔴 Likely causes:
- You manually disabled notifications in settings
- Battery optimization killed the app
- App was force-stopped
- Phone was restored/updated
- Token expired and wasn't refreshed

**Best practice going forward:**
- Don't disable notification permissions
- Disable battery optimization for Skypulse
- Allow app to auto-update
- Keep internet connected

---

## Quick Reference

| Item | Status | How to Check |
|------|--------|--------------|
| Notification Permission | ✅ Should be GRANTED | Settings > Apps > Skypulse > Permissions > Notifications |
| Battery Optimization | ✅ Should be OFF | Settings > Battery > Optimization > Don't Optimize Skypulse |
| Do Not Disturb | ✅ Should be OFF | Settings > Sound & Vibration > DND should be off |
| Internet | ✅ Should be ON | WiFi or Cellular signal |
| Notification Channel | ✅ Should exist | Settings > Apps > Skypulse > Notifications > weather_alerts |
| FCM Token | ✅ Should exist | App logs should show a long token string |
| Topic Subscription | ✅ Should be subscribed | App logs should say "Subscribed to topic: all_alerts" |

---

## Version Info

- **App Name:** Skypulse
- **Min Android:** 8.0
- **FCM SDK:** 14.7.10
- **Notification Channel:** weather_alerts (HIGH importance)
- **Auto-Refresh:** 30 seconds
- **Topics:** all_alerts (global) + city-specific topics
