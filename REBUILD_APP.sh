#!/bin/bash

# 🔥 REBUILD THE FLUTTER APP
# Run this if "nothing works" after code changes

echo "🧹 Cleaning Flutter build cache..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🚀 Rebuilding app..."
flutter run

echo "✅ App should now have all the latest fixes!"

