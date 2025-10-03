# 🚀 DrillSergeantX GitHub Actions Workflows

This repository includes comprehensive GitHub Actions workflows for building and testing your DrillSergeantX app.

## 📱 Available Workflows

### 1. **Quick APK Build** (`quick-apk.yml`)
- **Trigger**: Manual dispatch only
- **Purpose**: Fast APK builds for testing
- **Options**: Debug or Release builds
- **Duration**: ~5 minutes

**How to use:**
1. Go to Actions tab
2. Select "Quick APK Build"
3. Click "Run workflow"
4. Choose build type (debug/release)
5. Download APK from Artifacts

### 2. **Standard APK Build** (`build-apk.yml`)
- **Trigger**: Push to main/develop, PRs, Manual
- **Purpose**: Standard APK builds with testing
- **Outputs**: Debug + Release APKs
- **Duration**: ~8 minutes

### 3. **Signed APK Build** (`build-signed-apk.yml`)
- **Trigger**: Git tags (v*), Manual
- **Purpose**: Production-ready signed APKs
- **Features**: Keystore creation, Release management
- **Duration**: ~10 minutes

### 4. **APK Variants** (`build-apk-variants.yml`)
- **Trigger**: Push to main, PRs, Manual
- **Purpose**: Multiple APK variants (debug/release)
- **Outputs**: APK + App Bundle for each variant
- **Duration**: ~12 minutes

### 5. **Full Stack Build** (`full-stack-build.yml`)
- **Trigger**: Push to main/develop, PRs, Manual
- **Purpose**: Complete stack testing
- **Features**: Backend compilation + Flutter builds
- **Duration**: ~15 minutes

### 6. **Backend API Build** (`backend-api.yml`)
- **Trigger**: Backend changes, Manual
- **Purpose**: Backend testing with database
- **Features**: PostgreSQL + Redis testing
- **Duration**: ~10 minutes

## 🎯 Workflow Selection Guide

| Use Case | Recommended Workflow | Why |
|----------|-------------------|-----|
| **Quick Testing** | Quick APK Build | Fastest, manual trigger |
| **Regular Development** | Standard APK Build | Automatic, includes tests |
| **Production Release** | Signed APK Build | Tagged releases, signed APKs |
| **Multiple Variants** | APK Variants | Debug + Release + Bundles |
| **Full Testing** | Full Stack Build | Backend + Frontend testing |
| **Backend Changes** | Backend API Build | Database + API testing |

## 📦 Artifact Downloads

All workflows generate downloadable artifacts:

- **APK Files**: Ready to install on Android devices
- **App Bundles**: For Google Play Store upload
- **Build Logs**: Detailed compilation information

## 🔧 Configuration

### Environment Variables (Optional)
Add these to your repository secrets for enhanced functionality:

```bash
# For signed builds
ANDROID_KEYSTORE_PASSWORD=your_keystore_password
ANDROID_KEY_ALIAS=your_key_alias
ANDROID_KEY_PASSWORD=your_key_password

# For backend testing
DATABASE_URL=your_database_url
REDIS_URL=your_redis_url
```

### Customization
- **Flutter Version**: Change in workflow files (currently 3.24.0)
- **Java Version**: Modify in setup-java steps (currently 17)
- **Retention Days**: Adjust artifact retention (currently 30 days)

## 🚀 Quick Start

1. **Push your code** to trigger automatic builds
2. **Check Actions tab** for build status
3. **Download APKs** from Artifacts section
4. **Install on device** and test your features!

## 📊 Build Status

All workflows include comprehensive status reporting:

- ✅ **Backend**: TypeScript compilation, API health
- ✅ **Frontend**: Flutter tests, APK generation
- ✅ **Features**: All DrillSergeantX features verified
- ✅ **Artifacts**: Ready-to-use APK files

## 🎖️ DrillSergeantX Features Included

Your APKs include all these powerful features:

- 🔥 **Habits & Streaks**: Complete habit tracking system
- 🤖 **AI Nudges**: Smart coaching with legendary mentors
- 🎤 **Voice AI**: ElevenLabs integration with 5 mentor voices
- ⏰ **Smart Alarms**: Intelligent reminder system
- 🏆 **Achievements**: Gamified progression system
- 📱 **Modern UI**: Glass design with smooth animations
- 🔔 **Notifications**: Push notification support
- 📊 **Analytics**: Progress tracking and insights

## 🆘 Troubleshooting

### Common Issues:
1. **Build Fails**: Check Flutter/Java versions
2. **APK Too Large**: Use App Bundle for Play Store
3. **Tests Fail**: Verify all dependencies installed
4. **Signing Issues**: Check keystore configuration

### Support:
- Check workflow logs for detailed error messages
- Verify all dependencies are properly configured
- Ensure your code compiles locally first

---

**Ready to build your DrillSergeantX APK? Just push your code and watch the magic happen! 🚀**