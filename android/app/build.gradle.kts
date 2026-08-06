plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.apix_example_app"
    // Pinned above the Flutter defaults because plugins pulled in through apix
    // — flutter_secure_storage, sentry_flutter, path_provider_android,
    // package_info_plus — require them. Flutter only warns and builds anyway,
    // so the mismatch is invisible until a toolchain that lacks the older NDK
    // has to resolve it. Both are backward compatible.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.apix_example_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 24, not flutter.minSdkVersion (21): flutter_secure_storage 10.x
        // declares minSdk 24, and the manifest merger fails the build outright
        // rather than warning. apix depends on it for SecureTokenProvider, so
        // any app using apix's auth features inherits this floor.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
