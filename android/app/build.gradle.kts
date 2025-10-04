apply plugin: 'com.android.application'
apply plugin: 'org.jetbrains.kotlin.android'

android {
    namespace "com.drillos.app"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.drillos.app"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
            signingConfig signingConfigs.debug
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
        debug {
            minifyEnabled false
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
    }

    packagingOptions {
        resources {
            excludes += ['META-INF/LICENSE*', 'META-INF/NOTICE*']
        }
    }
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24"
}
