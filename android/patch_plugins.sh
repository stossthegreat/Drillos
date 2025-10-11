#!/bin/bash
set -e

echo "🔧 Aggressively patching android_alarm_manager_plus..."

PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/android_alarm_manager_plus-5.0.0/android"

if [ ! -d "$PLUGIN_PATH" ]; then
    echo "❌ Plugin not found at $PLUGIN_PATH"
    echo "Searching for plugin..."
    PLUGIN_PATH=$(find "$HOME/.pub-cache/hosted/pub.dev" -type d -name "android_alarm_manager_plus-*" -print -quit)
    if [ -z "$PLUGIN_PATH" ]; then
        echo "❌ Could not find android_alarm_manager_plus"
        exit 1
    fi
    PLUGIN_PATH="$PLUGIN_PATH/android"
fi

BUILD_GRADLE="$PLUGIN_PATH/build.gradle"

if [ ! -f "$BUILD_GRADLE" ]; then
    echo "❌ build.gradle not found at $BUILD_GRADLE"
    exit 1
fi

echo "📝 Found plugin at: $PLUGIN_PATH"
echo "📄 Original build.gradle:"
cat "$BUILD_GRADLE"

# Backup
cp "$BUILD_GRADLE" "$BUILD_GRADLE.backup"

# Create completely new build.gradle
cat > "$BUILD_GRADLE" << 'EOF'
group 'dev.fluttercommunity.plus.androidalarmmanager'
version '1.0'

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:8.4.2'
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: 'com.android.library'

android {
    namespace 'dev.fluttercommunity.plus.androidalarmmanager'
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    
    lintOptions {
        disable 'InvalidPackage'
    }
}

dependencies {
    implementation 'androidx.core:core:1.10.1'
    implementation 'androidx.work:work-runtime:2.8.1'
}
EOF

echo ""
echo "✅ Created new build.gradle:"
cat "$BUILD_GRADLE"

echo ""
echo "✅ android_alarm_manager_plus patched successfully!"
