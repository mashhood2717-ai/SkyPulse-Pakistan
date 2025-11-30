# Quick Deployment Checklist

## Build Release APK
```bash
cd "d:\Flutter weather app new\flutter_weather_app"
flutter clean
flutter pub get
flutter build apk --release
```

**APK Location:** `build/app/outputs/apk/release/app-release.apk`

---

## Pre-Deployment Testing (Local)

- [ ] App builds without errors
- [ ] App launches without crash
- [ ] Console shows "Firebase initialized"
- [ ] Console shows "Permission status: GRANTED"
- [ ] Console shows "FCM Token obtained"
- [ ] Console shows "Subscribed to all_alerts topic"

### Alert Reception Test (App Open)
- [ ] Send test alert
- [ ] Alert appears in Alerts tab within 5 seconds
- [ ] Red unread dot appears
- [ ] Badge count increments on Alerts icon

### Alert Reception Test (App Closed)
- [ ] Close app completely
- [ ] Send test alert
- [ ] Notification appears in system tray within 10 seconds
- [ ] Tap notification
- [ ] App opens to Alerts tab
- [ ] Alert shows with unread indicator

---

## Distribute to Family

### Files to Send
1. `app-release.apk` (the built app)
2. `ALERT_DEPLOYMENT_GUIDE.md` (troubleshooting guide)
3. Brief message with installation instructions

### Installation Instructions for Them
1. Download APK file
2. Open file manager
3. Tap the APK file
4. Tap "Install"
5. If prompted for permissions, tap "Install anyway"
6. When app launches, **GRANT** notification permission
7. Open the app and verify weather displays

---

## Verify on Their Device

**Have them check:**
1. App opens without crash
2. Weather displays properly
3. They see a toast/prompt about notifications permission
4. Permission was granted
5. They wait 30 seconds

**Then send a test alert:**
1. Send test weather alert from your server
2. Ask if they see it in system tray AND in-app Alerts tab
3. Ask them to open Alerts tab
4. Alert should show with red unread dot

---

## If Alerts Don't Work

**Have them follow these steps in order:**

### Fix #1: Check Notification Permission
1. Go to **Settings** → **Apps** → **Skypulse**
2. Tap **Permissions**
3. Ensure **Notifications** is **ON**
4. Close and reopen app

### Fix #2: Force Stop and Restart
1. Go to **Settings** → **Apps** → **Skypulse**
2. Tap **Force Stop**
3. Wait 5 seconds
4. Reopen app
5. Wait 30 seconds

### Fix #3: Disable Battery Optimization
1. Go to **Settings** → **Battery** (or Power)
2. Find **Battery Optimization** or **Adaptive Battery**
3. Search for **Skypulse**
4. Tap **Don't Optimize**
5. Close and reopen app

### Fix #4: Disable Do Not Disturb
1. Check notification settings aren't silenced
2. Go to **Settings** → **Sound & Vibration**
3. Ensure **Do Not Disturb** is OFF
4. Close and reopen app

### Fix #5: Check Network
1. Make sure they have working WiFi or cellular
2. Try sending a message in another app to verify network works
3. Restart their phone

### Fix #6: Reinstall App
1. Uninstall Skypulse from **Settings** → **Apps** → **Skypulse** → **Uninstall**
2. Go to **Settings** → **Apps** → **Skypulse** → **Storage** → **Clear Cache** (if option available)
3. Restart phone
4. Reinstall APK and grant permissions

---

## Success Indicators

### Console Logs on App Launch
```
✅ Firebase initialized successfully!
🔐 Requesting notification permissions...
📱 Permission status: GRANTED
🔔 Initializing push notifications...
🔑 Requesting FCM token...
✅ FCM Token obtained on attempt 1
📱 FCM Token: abc123...xyz789
💾 FCM Token saved to local storage
📢 Subscribing to global alert topic...
✅ Subscribed to global topic: all_alerts
```

### In Settings
- **Settings** → **Apps** → **Skypulse** → **Notifications**
  - Should show **weather_alerts** channel
  - Importance should be **HIGH**

### Receiving Alerts
- Alert appears in system tray within 10 seconds
- Tapping alert opens app to Alerts tab
- Alert has red unread indicator
- Tapping alert marks it read (removes red dot)

---

## If Still Not Working

**Collect diagnostic information:**
1. Screenshot of app console on startup
2. Screenshot of Settings → Apps → Skypulse → Permissions (showing Notifications is ON)
3. Screenshot of Settings → Battery → Optimization (showing Skypulse isn't optimized)
4. Android version (Settings → About → Android version)
5. Phone model

**Server-side check:**
- Verify alert server is configured with Firebase
- Verify sending to topic: `all_alerts`
- Check message has `notification` field with `title` and `body`
- Verify Firebase project key is correct

---

## One-Line Status Check

Have family member open app and look for this in console:
```
✅ Push notifications initialized!
```

If they see this, notifications should work.

If they see this:
```
❌ Permission denied by user
```

Then: Settings → Apps → Skypulse → Permissions → Enable Notifications
