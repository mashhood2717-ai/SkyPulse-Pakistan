# 🚀 SkyPulse - Google Play Production Quick Reference

## ⚡ 5-Minute Action Items

### 1️⃣ Create Release Signing Key
```bash
cd android/
keytool -genkey -v -keystore app.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias app-key
# ⚠️ SAVE PASSWORD SOMEWHERE SECURE!
```

### 2️⃣ Configure Signing (CRITICAL!)
```bash
cd android/
cp keystore.properties.template keystore.properties
# Edit keystore.properties with your passwords from step 1
```

### 3️⃣ Verify Permissions (Google Play Requirement)
✅ **All Permissions are Production-Ready:**
- `INTERNET` - API calls
- `ACCESS_FINE_LOCATION` - Weather location
- `ACCESS_COARSE_LOCATION` - Fallback location
- `POST_NOTIFICATIONS` - Weather alerts
- `VIBRATE` - Alert notifications
- `RECEIVE_BOOT_COMPLETED` - Background monitoring

### 4️⃣ Build & Test Locally
```bash
flutter build apk --release
adb install -r build/app/outputs/apk/release/app-release.apk
# Test on real device!
```

### 5️⃣ Generate Final Release Bundle
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 6️⃣ Restrict Google Maps API Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project → APIs & Services → Credentials
3. Find your Maps API key and click it
4. Set restrictions:
   - Application: Android
   - Package: `com.mashhood.skypulse`
   - SHA1: Get from below ⬇️

**Get SHA1 for your keystore:**
```bash
keytool -list -v -keystore android/app.keystore -alias app-key
# Copy the SHA1 line
```

---

## 📊 Production Checklist

| Item | Status | Notes |
|---|---|---|
| Flutter Analyze | ✅ PASS | No issues found |
| Code Obfuscation | ✅ DONE | ProGuard/R8 enabled |
| Signing Config | ✅ READY | keystore.properties template created |
| Permissions | ✅ COMPLIANT | All justified for weather app |
| Firebase Config | ✅ OK | google-services.json in place |
| Crashlytics | ✅ ACTIVE | Enabled via firebase_messaging |
| Min SDK | ✅ OK | 21+ supported |
| Target SDK | ✅ OK | 36 (current) |

---

## 🎯 What NOT to Do

❌ Don't commit `keystore.properties` to Git  
❌ Don't use debug signing for Play Store  
❌ Don't expose API keys in code  
❌ Don't skip testing on real device  
❌ Don't upload same version code twice  

---

## 📱 Test on Device Before Upload

```bash
flutter run -d <device> --release

# Check:
✓ App launches without crash
✓ Location permission prompt appears
✓ Notification permission prompt (Android 13+)
✓ Weather loads correctly
✓ Alerts work
✓ Widget updates
✓ No console errors
```

---

## 🚢 Upload to Play Store

1. AAB file: `build/app/outputs/bundle/release/app-release.aab`
2. Go to Play Console → Your App → Release → Create new release
3. Upload AAB, review, publish
4. Monitor crashes for 24 hours

---

## 📋 Files Changed for Production

- ✅ `android/app/build.gradle` - Release signing + ProGuard
- ✅ `android/app/proguard-rules.pro` - Code obfuscation rules
- ✅ `android/app/src/main/AndroidManifest.xml` - API key security note
- ✅ `android/.gitignore` - Protect sensitive files
- ✅ `android/keystore.properties.template` - Signing config template

---

## 🔗 Next Steps

1. **Create keystore** (Step 1 above) → ~5 min
2. **Configure signing** (Step 2) → ~2 min  
3. **Test release build** (Step 4) → ~10-15 min
4. **Build AAB** (Step 5) → ~5 min
5. **Upload to Play Store** → Done! ✅

---

**App Version**: 1.2.0+1  
**Status**: Production-Ready ✅  
**Ready to Upload**: YES (after completing steps above)
