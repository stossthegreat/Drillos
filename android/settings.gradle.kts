pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

includeBuild("${settingsDir.path}/../flutter/packages/flutter_tools/gradle")

include(":app")
