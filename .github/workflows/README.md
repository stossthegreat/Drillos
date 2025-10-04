# GitHub Actions Workflows

## Active Workflows

### 🤖 `android-build.yml`
**Primary Android APK build workflow**

- **Triggers**: 
  - Push to `main` or `develop` branches
  - Pull requests to `main`
  - Manual dispatch with build type selection
  
- **What it does**:
  - Sets up Java 17 and Flutter stable
  - Runs tests (if available)
  - Builds debug APK for PRs
  - Builds release APK for main/develop
  - Uploads artifacts with retention
  - Generates build summary

- **Manual Trigger**: 
  Go to Actions → Android APK Build → Run workflow → Select build type

### 🔧 `backend-api.yml`
**Backend API deployment workflow**

- Handles backend deployment to Railway/hosting platform
- Separate from Android builds

---

## Archived Workflows

The following workflows have been archived to `_archive/` folder to prevent conflicts and reduce CI complexity:

- `build-apk.yml` - Replaced by `android-build.yml`
- `build-signed-apk.yml` - Merged into `android-build.yml`
- `build-apk-variants.yml` - Redundant
- `quick-apk.yml` - Redundant
- `test-android-build.yml` - Merged into `android-build.yml`
- `flutter_build.yml` - Redundant
- `flutter.yml` - Redundant
- `flutter-build.kts` - Invalid file (wrong extension)
- `full-stack-build.yml` - Split into separate workflows

---

## Build Configuration

### Java Version
- **Workflows**: Java 17
- **Android Config**: Java 17
- ✅ **Consistent**

### Gradle Version
- **AGP**: 8.7.2
- ✅ **Consistent across all files**

### Package Name
- **Namespace**: `com.example.drillos`
- **Application ID**: `com.example.drillos`
- ✅ **Consistent**

---

## Troubleshooting

### Build fails with "Flutter SDK not found"
- The workflow auto-installs Flutter, no action needed
- `local.properties` is auto-generated during build

### Build fails with "Gradle error"
- Check that `android/app/build.gradle.kts` has all required sections
- Verify Java 17 is being used

### Package name errors
- All files now use `com.example.drillos` consistently
- If you change package name, update all 3 locations:
  1. `android/app/build.gradle.kts` (namespace & applicationId)
  2. `android/app/src/main/AndroidManifest.xml` (android:name)
  3. Kotlin package directories

---

## Best Practices

1. **Use `android-build.yml` for all Android builds**
2. **Don't edit `local.properties`** - it's auto-generated
3. **Keep workflows simple** - one workflow per platform
4. **Use manual dispatch** for testing builds
5. **Check artifacts** - APKs are uploaded for 30-90 days

---

Last updated: October 2024
