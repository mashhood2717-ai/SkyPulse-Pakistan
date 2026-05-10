# 🚀 Google Play Production Deployment Guide - SkyPulse Pakistan

## ✅ Pre-Deployment Checklist

### 1. **Code Quality** ✓ PASSED
- ✅ `flutter analyze` - No issues found
- ✅ All dependencies updated
- ✅ No console errors/warnings in production mode

### 2. **Build Configuration** - ACTION REQUIRED ⚠️

#### 2.1 Signing Configuration
The app now supports proper release signing. Follow these steps:

**Step 1: Create a Keystore (if you don't have one)**
```bash
cd android/
keytool -genkey -v -keystore app.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias app-key
```
This will prompt you for:
- Keystore password (remember this!)
- First and last name
- Organizational unit
- Organization
- City/Locality
- State/Province
- Country code (e.g., PK for Pakistan)

**Step 2: Configure Keystore Properties**
```bash
# Copy the template
cp android/keystore.properties.template android/keystore.properties

# Edit android/keystore.properties with your values:
store.file=../app.keystore           # Path to your keystore
store.password=YOUR_PASSWORD        # Keystore password from Step 1
key.alias=app-key                   # Alias from Step 1
key.password=YOUR_KEY_PASSWORD      # Key password from Step 1
```

**Step 3: Protect Sensitive Data**
```bash
# Make sure keystore.properties is in .gitignore
echo "keystore.properties" >> android/.gitignore
echo "app.keystore" >> android/.gitignore
```

#### 2.2 ProGuard/R8 Configuration ✅ DONE
- ✅ ProGuard rules file created: `android/app/proguard-rules.pro`
- ✅ Minification enabled for release builds
- ✅ Resource shrinking enabled
- ✅ Code obfuscation active

### 3. **Permissions Verification** ✓ COMPLIANT

**Current Permissions in AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

**Google Play Policy Compliance:**
- ✅ Location permissions: Required for weather based on location
- ✅ Notification permissions: Necessary for weather alerts
- ✅ Vibrate: Used for alert notifications
- ✅ Boot completed: Needed for background alert monitoring
- ✅ Internet: Required for API calls

**Action Items:**
1. In Play Console → App content → Permissions:
   - Select "Location" as the primary permission
   - Justify usage: "Provides weather data for user's location"
   - For notifications: "Sends weather alerts and warnings"

### 4. **API Key Security** - ACTION REQUIRED ⚠️

#### Google Maps API Key
- ⚠️ Currently exposed in AndroidManifest.xml
- **ACTION**: Restrict in Google Cloud Console:
  1. Go to Google Cloud Console
  2. Select your project
  3. Navigate to "APIs & Services" → "Credentials"
  4. Find your Maps API key
  5. Click on it and set restrictions:
     - **Application restrictions**: Select "Android apps"
     - **Package name**: `com.mashhood.skypulse`
     - **SHA-1 fingerprint**: [Run command below to get this]

**Get SHA-1 Fingerprint:**
```bash
# For release key (production)
keytool -list -v -keystore android/app.keystore -alias app-key -storepass YOUR_PASSWORD -keypass YOUR_PASSWORD

# Copy the SHA1 value and paste in Google Cloud Console
```

#### Firebase API Keys
- ℹ️ Firebase keys are part of standard config and are secure (read-only access only)
- ✅ google-services.json is properly configured

### 5. **Target SDK & Minification** ✓ COMPLIANT

**Current Configuration:**
```
compileSdk: 36
targetSdk: 36
minSdk: 21 (flutter default)
```

✅ Meets Google Play requirements:
- minSdkVersion ≥ 21
- targetSdkVersion ≥ 34 (as of November 2024)
- Code shrinking enabled
- ProGuard rules configured

### 6. **Testing Checklist** - REQUIRED BEFORE UPLOAD

Before generating the signed APK/AAB:

- [ ] Test on physical device (Android 8+)
- [ ] Test location permissions grant/denial
- [ ] Test notification permissions (Android 13+)
- [ ] Verify weather data loads correctly
- [ ] Test offline mode (if cached)
- [ ] Test background alert notifications
- [ ] Verify no crashes on app startup
- [ ] Test home screen widget

**Run tests:**
```bash
flutter run -d <device-id> --release
# Or for signed APK:
flutter build apk --release
```

### 7. **Google Play Console Setup** - REQUIRED

**Account & App Setup:**
1. ✅ Create Google Play Developer account ($25 one-time)
2. ✅ Create app: "SkyPulse Pakistan"
3. ✅ Primary category: "Weather"
4. ✅ Content rating: Fill out questionnaire

**Store Listing (Important for approval):**
- ✅ App name: "SkyPulse Pakistan"
- ✅ Short description (80 chars): "Real-time weather & storm alerts for Pakistan"
- ✅ Full description: Explain location and notification usage
- ✅ Screenshots (minimum 2):
  - Home screen with weather
  - Alerts screen
  - Map view
- ✅ Feature graphic (1024×500 px)
- ✅ Icon (512×512 px)
- ✅ Privacy policy URL: [Create and provide]

**Privacy Policy Requirements:**
Must clearly state:
- Location data is used for weather only
- Notifications are for weather alerts
- No personal data collection or sharing
- Firebase usage (optional)

**Content Rating Questionnaire:**
- Violence: None
- Profanity: None
- Sexual content: None
- Alcohol/tobacco: None
- Dating: None
- Gambling: None

### 8. **Generate Signed APK/AAB** - BUILD INSTRUCTIONS

#### Option A: Android App Bundle (AAB) - RECOMMENDED for Play Store
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

#### Option B: Signed APK
```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

**Upload to Play Console:**
1. Go to "Release" → "Production"
2. Click "Create new release"
3. Upload the AAB file
4. Review and proceed to rollout

### 9. **Common Rejection Reasons & Fixes** ⚠️

| Rejection Reason | Fix |
|---|---|
| Missing privacy policy | Add privacy policy URL in Play Console |
| Unclear permission usage | Add prominent in-app message about location/notifications |
| Unsafe implementation | Ensure all URLs use HTTPS (already done) |
| Crash on startup | Test on Android 8, 12, 13+ |
| Incomplete store listing | Add all screenshots and descriptions |
| App not installable | Ensure correct app signing |
| Policy violation (ads) | No ad networks detected - should be fine |

### 10. **Release Workflow Summary**

```
1. Create keystore and sign key
   └─ keytool -genkey -v ...

2. Configure keystore.properties
   └─ Edit android/keystore.properties

3. Test release build locally
   └─ flutter build apk --release

4. Run on device to verify
   └─ adb install build/app/outputs/apk/release/app-release.apk

5. Generate final AAB
   └─ flutter build appbundle --release

6. Upload to Play Console
   └─ Internal testing → Beta → Production

7. Monitor for crashes
   └─ Check Play Console → Performance → ANRs & crashes
```

### 11. **Post-Release Monitoring** 📊

After release, monitor:
- ✅ Crash reports in Play Console
- ✅ User ratings and reviews
- ✅ Uninstall rate
- ✅ Performance metrics

Check daily for first week, then weekly after.

---

## 📝 Notes

- **buildNumber**: Current version is 1.2.0 (code 1). Increment for each release:
  - Minor updates: code +1 (1.2.0 → 1.2.1)
  - Features: minor +1 (1.2.0 → 1.3.0)
  - Major changes: major +1 (1.2.0 → 2.0.0)
  
  Update in `pubspec.yaml`: `version: X.Y.Z+CODE`

- **Testing devices**: Ensure you test on:
  - Android 8 (API 26) - minimum
  - Android 12 (API 31) - mid-range
  - Android 13+ (API 33+) - latest with scoped storage

- **Size limits**: 
  - APK size: Must be < 100 MB (current estimated ~40-50 MB)
  - AAB size: Typically smaller than APK

---

## ✅ Files Modified for Production

1. **android/app/build.gradle** ✅
   - Added release signing configuration
   - Enabled ProGuard/R8 minification
   - Enabled resource shrinking

2. **android/app/proguard-rules.pro** ✅ (NEW)
   - ProGuard rules for all dependencies
   - Flutter, Firebase, location, permissions
   - Code obfuscation rules

3. **android/app/src/main/AndroidManifest.xml** ✅
   - Added security note for Google Maps API key

4. **android/keystore.properties.template** ✅ (NEW)
   - Template for signing configuration
   - Instructions for creating keystore

---

**Last Updated**: May 10, 2026
**App Version**: 1.2.0+1
**Flutter Analyze**: ✅ No issues
**Status**: Ready for signing key configuration and upload

