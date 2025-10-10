#!/bin/bash

echo "🔧 Patching broken plugin build.gradle files..."

# Find all plugin build.gradle files in pub cache
for plugin_dir in "$HOME/.pub-cache/hosted/pub.dev/"*"/android"; do
    if [ -d "$plugin_dir" ]; then
        build_file="$plugin_dir/build.gradle"
        
        if [ -f "$build_file" ]; then
            # Check if this file references flutter.* properties
            if grep -q "flutter\\.compileSdkVersion\|flutter\\.minSdkVersion\|flutter\\.targetSdkVersion\|flutter\\.ndkVersion" "$build_file"; then
                plugin_name=$(basename $(dirname "$plugin_dir"))
                echo "📝 Patching $plugin_name"
                
                # Create backup
                cp "$build_file" "$build_file.bak"
                
                # Replace flutter property references with hardcoded values
                sed -i 's/compileSdk flutter\.compileSdkVersion/compileSdk 34/g' "$build_file"
                sed -i 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion 21/g' "$build_file"
                sed -i 's/targetSdkVersion flutter\.targetSdkVersion/targetSdkVersion 34/g' "$build_file"
                sed -i 's/ndkVersion flutter\.ndkVersion/ndkVersion "26.1.10909125"/g' "$build_file"
                
                # Also handle potential variations without 'flutter.' prefix in context
                sed -i 's/compileSdkVersion = flutter\.compileSdkVersion/compileSdkVersion = 34/g' "$build_file"
                sed -i 's/minSdkVersion = flutter\.minSdkVersion/minSdkVersion = 21/g' "$build_file"
                sed -i 's/targetSdkVersion = flutter\.targetSdkVersion/targetSdkVersion = 34/g' "$build_file"
                
                echo "✅ Patched $plugin_name"
            fi
        fi
    fi
done

echo "✅ Plugin patching complete"
