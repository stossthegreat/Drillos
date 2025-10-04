android {
    namespace = "com.drillos.app"
    compileSdk = 36 // ⚠️ Upgrade to satisfy path_provider & shared_preferences

    defaultConfig {
        applicationId = "com.drillos.app"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ✅ FIX: Keep Flutter & Play Core classes
            proguardFiles("proguard-flutter.txt")
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    // ✅ Kotlin/Java configs unchanged
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}
