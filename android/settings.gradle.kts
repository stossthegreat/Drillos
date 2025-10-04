pluginManagement {
    val flutterSdkPath: String by lazy {
        val localProperties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { localProperties.load(it) }
        }
        val sdkPath = localProperties.getProperty("flutter.sdk")
            ?: throw GradleException("flutter.sdk not set in local.properties")
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
