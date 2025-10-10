#!/bin/bash

echo "🔧 Patching broken plugin build.gradle files..."

# Find and patch android_alarm_manager_plus
ALARM_MANAGER_BUILD="$HOME/.pub-cache/hosted/pub.dev/android_alarm_manager_plus-5.0.0/android/build.gradle"

if [ -f "$ALARM_MANAGER_BUILD" ]; then
    echo "📝 Found android_alarm_manager_plus build.gradle"
    
    # Backup original
    cp "$ALARM_MANAGER_BUILD" "$ALARM_MANAGER_BUILD.bak"
    
    # Replace the problematic line that references flutter.compileSdkVersion
    sed -i "s/compileSdk flutter.compileSdkVersion/compileSdk 34/" "$ALARM_MANAGER_BUILD"
    sed -i "s/minSdkVersion flutter.minSdkVersion/minSdkVersion 21/" "$ALARM_MANAGER_BUILD"
    sed -i "s/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 34/" "$ALARM_MANAGER_BUILD"
    
    echo "✅ Patched android_alarm_manager_plus"
else
    echo "⚠️ android_alarm_manager_plus build.gradle not found, might be different version"
fi

# Patch any other plugins that might have similar issues
for build_file in $HOME/.pub-cache/hosted/pub.dev/*/android/build.gradle; do
    if grep -q "flutter.compileSdkVersion" "$build_file" 2>/dev/null; then
        echo "📝 Patching $(dirname $(dirname $build_file))"
        sed -i "s/compileSdk flutter.compileSdkVersion/compileSdk 34/" "$build_file"
        sed -i "s/minSdkVersion flutter.minSdkVersion/minSdkVersion 21/" "$build_file"
        sed -i "s/targetSdkVersion flutter.targetSdkVersion/targetSdkVersion 34/" "$build_file"
    fi
done

echo "✅ Plugin patching complete"
