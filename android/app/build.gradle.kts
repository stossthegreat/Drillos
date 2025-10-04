plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drillos.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.drillos.app"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        resources {
            excludes += listOf(
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1"
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    // Core Kotlin + AndroidX
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
    implementation("androidx.core:core-ktx:1.13.1")

    // ✅ MultiDex Support
    implementation("androidx.multidex:multidex:2.0.1")
}
