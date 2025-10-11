#!/bin/bash

echo "🔧 Aggressively patching android_alarm_manager_plus..."

# Search for the plugin more thoroughly
echo "Searching in pub cache..."
PLUGIN_DIRS=$(find "$HOME/.pub-cache/hosted" -type d -name "android_alarm_manager_plus-*" 2>/dev/null)

if [ -z "$PLUGIN_DIRS" ]; then
    echo "❌ Could not find android_alarm_manager_plus anywhere in pub cache"
    echo "Pub cache structure:"
    ls -la "$HOME/.pub-cache/hosted/" 2>/dev/null || echo "Pub cache not accessible"
    exit 1
fi

echo "Found plugin directories:"
echo "$PLUGIN_DIRS"

# Use the first one found
PLUGIN_PATH=$(echo "$PLUGIN_DIRS" | head -n1)
PLUGIN_PATH="$PLUGIN_PATH/android"

echo "Using: $PLUGIN_PATH"

if [ ! -d "$PLUGIN_PATH" ]; then
    echo "❌ Android directory not found at $PLUGIN_PATH"
    exit 1
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
