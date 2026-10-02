plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Release signing credentials live in android/key.properties, which is NEVER
// committed (see android/.gitignore). The app OWNER creates the real upload
// keystore once with:
//   keytool -genkey -v -keystore ~/gotrvl-upload-key.jks -keyalg RSA \
//     -keysize 2048 -validity 10000 -alias gotrvl
// then copies android/key.properties.example to android/key.properties and
// fills in the real passwords. When key.properties is absent (fresh clone,
// CI without secrets), the release build falls back to debug signing so
// `flutter build` still runs; that fallback must never ship to Play.
val keystoreProperties =
    run {
        val properties = Properties()
        val keyPropertiesFile = rootProject.file("key.properties")
        if (keyPropertiesFile.exists()) {
            keyPropertiesFile.inputStream().use { properties.load(it) }
        }
        properties
    }

android {
    namespace = "com.gotrvl.app"
    // Google Play requires targetSdk 36+ for new apps and app updates
    // submitted on/after Aug 31, 2026. compileSdk must be >= targetSdk.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.gotrvl.app"
        // minSdk 24: the highest minimum required by our plugins
        // (google_maps_flutter_android and image_picker_android both require
        // 24; firebase plugins and geolocator need only 21). Do not lower it.
        minSdk = 24
        targetSdk = 36
        // versionCode / versionName come from pubspec.yaml `version: 1.0.0+1`,
        // which resolves to versionCode 1 and versionName "1.0.0".
        // Bump pubspec.yaml for each store release (1.1.0+2, ...).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // True when android/key.properties exists with a storeFile entry.
    val hasReleaseKey = keystoreProperties.containsKey("storeFile")

    signingConfigs {
        // Always registered so `signingConfigs.getByName("release")` resolves,
        // but only populated with real credentials when key.properties exists.
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // No key.properties (fresh clone, CI without secrets): fall back
            // to debug signing so local release builds still run. Never
            // upload a build signed this way to Google Play.
            signingConfig =
                if (hasReleaseKey) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
        }
    }

    // Deduplicate META-INF license files that ship in both -jvm and
    // non-jvm variants of the same androidx artifact, and Kotlin/Native
    // metadata (.knm) duplicated across datastore/collection jars.
    packaging {
        resources {
            excludes += "META-INF/**/LICENSE.txt"
            excludes += "META-INF/kotlin-project-structure-metadata.json"
            excludes += "nativeMain/**"
            excludes += "commonMain/**"
        }
    }
}

// Force a single consistent androidx KTX line: old -ktx artifacts (pulled
// transitively by preference:1.2.1 and others) bundle classes that were
// merged into the newer -jvm artifacts, causing duplicate-class failures.
configurations.all {
    resolutionStrategy {
        force("androidx.activity:activity-ktx:1.10.1")
        force("androidx.collection:collection-ktx:1.4.2")
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
