name: Build Flutter APK

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.24.4"

      - name: Install dependencies
        run: flutter pub get

      # ⚠️ Skip tests (we don’t have any)
      - name: Skip tests
        run: echo "🟢 Skipping Flutter tests (no test files present)."

      - name: Build release APK
        run: flutter build apk --release

      - name: Upload APK artifact
        uses: actions/upload-artifact@v3
        with:
          name: drillos-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
