plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

android {
    namespace "com.example.drillos"
    compileSdk 36

    defaultConfig {
        applicationId "com.example.drillos"
        minSdk 23
        targetSdk 36
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro", "proguard-flutter.txt"
            signingConfig signingConfigs.debug
        }
        debug {
            minifyEnabled false
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
        coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation "androidx.multidex:multidex:2.0.1"
    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4"
}

flutter {
    source "../.."
}
