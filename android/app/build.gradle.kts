plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nermalav.lastmove"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Placeholder id - replace it with the final Play Console id before the
        // first upload (it cannot be changed afterwards).
        applicationId = "com.nermalav.lastmove"

        // 24 is Flutter's own floor and comfortably covers Flame.
        minSdk = 24

        // Google Play requires a recent target API; 36 (Android 16) is the
        // current requirement for new apps and updates.
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // The prototype signs release builds with the debug key so that
            // `flutter build appbundle` works out of the box. Create a real
            // keystore plus a key.properties file before publishing.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
