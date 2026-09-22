pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // The maplibre_android federated plugin (a transitive dependency of the
    // `maplibre` package, >=0.3.4) applies org.jlleitschuh.gradle.ktlint in
    // its own build.gradle.kts without a version — fine inside its own
    // monorepo (where the root build declares the classpath), but this app
    // includes that build script directly as a subproject, so Gradle needs
    // a version pinned here to resolve it at all. Not otherwise used by
    // this app; version matches what the maplibre package's own repo pins.
    plugins {
        id("org.jlleitschuh.gradle.ktlint") version "13.1.0"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
