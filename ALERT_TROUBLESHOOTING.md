# Skypulse Alerts Troubleshooting Guide

If you're not receiving alerts on your phone, follow these steps:

## Quick Fixes (Try These First)

### 1. **Grant Notification Permission**
   - Open **Settings** → **Apps** → **Skypulse**
   - Tap **Permissions**
   - Enable **Notifications** or **Allow notifications**
   - Restart the app

### 2. **Force Stop & Restart**
   - Go to **Settings** → **Apps** → **Skypulse**
   - Tap **Force Stop**
   - Wait 5 seconds
   - Open the app again from your home screen
   - This allows Firebase to reinitialize

### 3. **Check Battery Optimization**
   - Go to **Settings** → **Battery** or **Power**
   - Find **Battery Optimization** or **Battery Saver**
   - Set Skypulse to **Don't optimize** or **Exempt from optimization**
   - This prevents the system from killing the app

### 4. **Enable Background Activity**
   - Go to **Settings** → **Apps** → **Skypulse**
   - Enable **Background restriction** or **Allow background activity**
   - Some phones have this under **App battery management**

### 5. **Check Do Not Disturb (DND)**
   - Make sure **Do Not Disturb** is not enabled
   - If enabled, add Skypulse to the allowed apps list

### 6. **Reinstall the App**
   - Uninstall Skypulse completely
   - Restart your phone
   - Reinstall Skypulse
   - Grant all permissions when prompted
   - Wait 30 seconds for initialization

## Why You Might Not Be Receiving Alerts

- ❌ Notification permissions not granted
- ❌ Battery optimization killing the app background process
- ❌ Firebase not properly initialized
- ❌ Poor internet connection when Firebase initializes
- ❌ Do Not Disturb mode enabled
- ❌ VPN or firewall blocking Firebase servers

## For Android 12+

Recent Android versions are strict about background apps. Make sure:

1. Notifications permission is **explicitly granted** (not just assumed)
2. Battery optimization is **disabled** for Skypulse
3. App is not restricted by **Doze Mode**

## Check Alerts Are Working

Open the app and go to the **Alerts** tab. If you see alerts there, your app is receiving alerts correctly. The issue is just the notification delivery.

## Still Not Working?

If alerts still aren't coming through after trying all above steps:

1. Reinstall the app fresh
2. Make sure your **internet connection is stable**
3. Check if your phone **date/time is correct** (Firebase requires this)
4. Try on a different WiFi network
5. Temporarily disable any VPNs

---

**Note:** Alerts may take up to 30 seconds to reach your device due to:
- Firebase Cloud Messaging delivery time
- Your phone's network conditions
- Background refresh intervals

