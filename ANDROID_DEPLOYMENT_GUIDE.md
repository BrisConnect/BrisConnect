# 🤖 Android Deployment Guide

**Status**: Ready to Build | **Target**: Google Play & APK Distribution
**Minimum SDK**: API 21 (Android 5.0) | **Target SDK**: API 34 (Android 14)

---

## 📦 Build & Deploy Android

### Prerequisites Check
```bash
# Verify Flutter recognizes Android setup
flutter doctor -v

# Expected output:
[✓] Flutter (Channel stable, 3.41.9)
[✓] Android toolchain (Android SDK version 34.0.0)
[✓] Android Studio version 2024.1
[✓] Android Studio plugins
[✓] Android Virtual Device (emulator if available)
```

### If Missing Android Setup
```bash
# Install Android SDK
flutter doctor --android-licenses
flutter config --android-sdk /path/to/android/sdk

# Or use Android Studio:
# Android Studio > Settings > Languages & Frameworks > Android SDK
```

---

## 🔧 Configure Android App

### 1. Update App Information

**File**: `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        applicationId = "com.brisconnect.app"  // Update package name
        minSdk = 21
        targetSdk = 34
        versionCode = 1                         // Increment for each release
        versionName = "1.0.0"                   // Version string
        
        // Required for image picker and URL launcher
        compileSdkVersion 34
    }
}
```

### 2. Update App Name & Icon

**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
    <application
        android:label="BrisConnect+"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:theme="@style/LaunchTheme">
            <!-- Main intent filter -->
        </activity>
    </application>
</manifest>
```

### 3. Set App Icon

Replace icon files:
```
android/app/src/main/res/mipmap-*/ic_launcher.png
android/app/src/main/res/mipmap-*/ic_launcher_foreground.png (for adaptive icons)
```

Available sizes:
- `mipmap-ldpi/`: 36x36
- `mipmap-mdpi/`: 48x48
- `mipmap-hdpi/`: 72x72
- `mipmap-xhdpi/`: 96x96
- `mipmap-xxhdpi/`: 144x144
- `mipmap-xxxhdpi/`: 192x192

### 4. Configure Signing

**Create keystore** (one-time):
```bash
keytool -genkey -v -keystore ~/brisconnect.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias brisconnect_key

# When prompted, enter:
# - Password: [choose strong password]
# - First & Last Name: Your Name
# - Org Unit: BrisConnect
# - Organization: BrisConnect+
# - City: Brisbane
# - State: QLD
# - Country: AU
```

**Create signing configuration**:

**File**: `android/app/build.gradle.kts`

```kotlin
android {
    signingConfigs {
        create("release") {
            keyAlias = "brisconnect_key"
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD") ?: "your_password"
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: 
                           "/Users/ibrahim_ahhoa/brisconnect.jks")
            storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: "your_password"
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

Or use environment variables (recommended):
```bash
export ANDROID_KEYSTORE_PATH="$HOME/brisconnect.jks"
export ANDROID_KEYSTORE_PASSWORD="your_password"
export ANDROID_KEY_PASSWORD="your_password"
```

---

## 🏗️ Build APK for Testing

### Debug APK (For Testing)
```bash
flutter build apk --debug

# Output:
# build/app/outputs/apk/debug/app-debug.apk

# Install on device/emulator
adb install build/app/outputs/apk/debug/app-debug.apk

# Or run directly
flutter run --release
```

### Release APK (For Distribution)
```bash
flutter build apk --release

# Output:
# build/app/outputs/apk/release/app-release.apk
```

**Size**: ~50-70MB (depends on Flutter engine)

---

## 📦 Build AAB for Google Play

### Android App Bundle (Recommended)
```bash
flutter build appbundle --release

# Output:
# build/app/outputs/bundle/release/app-release.aab

# Size: ~35-45MB (optimized by Play Store)
```

**Advantages over APK**:
- ✅ Smaller downloads (optimized per device)
- ✅ Required for Google Play Store
- ✅ Auto-generates device-specific APKs
- ✅ Includes feature modules

---

## 🧪 Test APK Locally

### On Android Emulator
```bash
# Start emulator
emulator -avd Pixel_7_API_34 &

# List connected devices
flutter devices

# Install and run
flutter run -d emulator-5554
```

### On Physical Android Device
```bash
# Enable Developer Mode
# Settings > About > Build Number (tap 7 times)
# Settings > Developer Options > USB Debugging (ON)

# Connect via USB
adb devices

# Run app
flutter run -d <device_id>

# Install APK directly
adb install build/app/outputs/apk/release/app-release.apk
```

### Testing Checklist
- [ ] App launches without crashes
- [ ] Landing page displays correctly
- [ ] HomePage loads data from Firestore
- [ ] Search and filters work
- [ ] Business profile CRUD operations work
- [ ] Image upload functions (camera/gallery)
- [ ] Phone number tappable (tel: scheme)
- [ ] Website links open correctly
- [ ] Rotation works (portrait/landscape)
- [ ] Back button navigation works
- [ ] Memory usage reasonable (<150MB)
- [ ] Battery drain acceptable

---

## 🎮 Google Play Store Deployment

### Step 1: Create Google Play Account
```
https://play.google.com/console
- Sign in with Google account
- Pay $25 registration fee
- Create new application
```

### Step 2: Create App Listing

In Google Play Console:
1. **App Information**
   - App name: "BrisConnect+"
   - Default language: English
   - App category: Travel & Local
   - Content rating: Self-rate

2. **Create App**
   - Package name: `com.brisconnect.app`
   - Type: Android App

### Step 3: Prepare Store Listing

**Screenshots** (required: 2-8 per orientation):
- Minimum dimensions: 320x426px
- Maximum dimensions: 3840x2160px
- File format: 32-bit PNG/JPEG
- **Recommended**: 1080x1920 (standard)

**Graphic Assets**:
- Feature Graphic: 1024x500px
- Icon: 512x512px (32-bit PNG)

**Descriptions**:
- **Short description** (80 chars max):
  "Discover & manage Brisbane businesses"

- **Full description** (4000 chars max):
  ```
  BrisConnect+ helps you discover amazing Brisbane attractions, 
  events, and local businesses. Create your business profile to 
  connect with customers and share your story.
  
  Features:
  • Browse attractions and events
  • Create and manage business profiles
  • Upload photos and business information
  • Real-time business updates
  • Share on social media
  • Multi-language support
  
  Built with Flutter for iOS, Android, and Web.
  ```

- **Release notes**:
  "Initial release - Business profile feature added"

### Step 4: Upload AAB

1. Go to **Release** > **Production**
2. Click **Create new release**
3. Upload AAB: `build/app/outputs/bundle/release/app-release.aab`
4. Add release notes
5. Review and submit

### Step 5: Set Pricing & Distribution

1. **Pricing & Distribution**
   - Countries: Select target regions
   - Content rating: Self-rate (IARC)
   - Permissions: Auto-detected from manifest

2. **Content Rating**
   - Fill out questionnaire
   - Get rating certificate

### Step 6: Submit for Review
- Google Play team reviews (typically 2-24 hours)
- App becomes available on approval
- Monitor reviews and crash reports

---

## 🐛 Common Android Issues

### Issue: "Google Play Services not available"
**Solution**: Ensure device has Google Play Services installed
```bash
# Check if installed
adb shell pm list packages | grep google

# If missing, update from Play Store app
```

### Issue: "Compilation failed: Unknown host 'storage.googleapis.com'"
**Solution**: Network issue, check internet and firewall
```bash
flutter pub get --offline  # Use cached packages
```

### Issue: "Certificate is not yet valid"
**Solution**: Device date/time is wrong
```bash
# On emulator: Settings > Date & Time > Set automatically
# On physical device: Settings > Date & Time > Auto-sync
```

### Issue: "App crashes on startup"
**Solution**: Check logcat for errors
```bash
flutter run -v  # Verbose output shows crash traces
adb logcat | grep flutter  # Real-time logs
```

### Issue: "Image upload fails"
**Solution**: Check file permissions in AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
```

---

## 📊 Build Optimization

### Reduce APK Size
```bash
# Enable ProGuard/R8
# In android/app/build.gradle.kts:
minifyEnabled = true
shrinkResources = true

# This typically reduces size by 30-40%
```

### Enable Compression
```bash
# Split APK by architecture
# In android/app/build.gradle.kts:
bundle {
    density {
        enableSplit = true
    }
    abi {
        enableSplit = true
    }
}
```

### Performance Profiling
```bash
# Debug app performance
flutter run --profile

# Profile specific areas
DevTools > Performance > Start Recording
```

---

## 📱 Device Compatibility

### Minimum Requirements
- Android 5.0 (API 21)
- 2GB RAM minimum
- 100MB free storage

### Recommended
- Android 8.0+ (API 26+)
- 4GB+ RAM
- Modern SoC (2020+)

### Supported Architectures
- ✅ arm64-v8a (64-bit ARM)
- ✅ armeabi-v7a (32-bit ARM)
- ✅ x86_64 (Intel 64-bit)
- ✅ x86 (Intel 32-bit)

---

## 🔄 Update Deployment

### For Existing App
```bash
# Increment version code and name
# android/app/build.gradle.kts:
versionCode = 2
versionName = "1.0.1"

# Rebuild AAB
flutter build appbundle --release

# Upload to Play Store > Production
```

### Version Code Tracking
```
1.0.0 = versionCode 1
1.0.1 = versionCode 2
1.1.0 = versionCode 10
2.0.0 = versionCode 100
```

---

## 📞 Support & Monitoring

### Google Play Console Monitoring
- ✅ Crash reports (realtime)
- ✅ Performance metrics
- ✅ User reviews & ratings
- ✅ Download statistics
- ✅ Device/Android version analytics

### Set Up Firebase Crash Reporting
```bash
# Already integrated via Firebase SDK
# Crashes automatically reported to Firebase Console
```

### Monitor App Analytics
```
Firebase Console:
- User engagement
- Crash frequency
- Performance metrics
- Funnel analysis
```

---

## ✅ Deployment Checklist

### Before Release
- [ ] All features tested on Android devices
- [ ] No critical bugs or crashes
- [ ] Performance acceptable (<2s load time)
- [ ] Images optimized
- [ ] Sign APK/AAB with production keystore
- [ ] Update version code
- [ ] Write release notes
- [ ] Prepare store listing graphics
- [ ] Legal review (privacy policy, T&Cs)

### Store Listing
- [ ] App name clear and descriptive
- [ ] Short description compelling
- [ ] Full description detailed
- [ ] Screenshots show key features
- [ ] Graphics professional quality
- [ ] Preview video (optional but recommended)

### Post-Release
- [ ] Monitor crash reports
- [ ] Respond to user reviews
- [ ] Track download/active user metrics
- [ ] Plan follow-up updates
- [ ] Gather user feedback

---

## 🎯 Quick Reference Commands

```bash
# Development
flutter run                           # Debug on connected device
flutter run --release                # Release mode on device

# Build APK
flutter build apk                     # Debug APK
flutter build apk --release           # Release APK

# Build AAB (for Play Store)
flutter build appbundle --release     # Production AAB

# Testing
adb devices                           # List connected devices
adb install app.apk                   # Install APK
adb logcat | grep flutter             # View logs

# Signing
keytool -list -v -keystore ~/brisconnect.jks  # Verify keystore
```

---

**Status**: Ready for Android deployment ✅
