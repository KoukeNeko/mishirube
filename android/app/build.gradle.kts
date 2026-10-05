import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key, kept out of the repository: key.properties locally, the
// ANDROID_* variables in CI. Without either, release falls back to debug.
val uploadKey = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.reader()?.use(::load)
}

fun uploadKeyValue(property: String, variable: String): String? =
    uploadKey.getProperty(property) ?: System.getenv(variable)

android {
    namespace = "com.example.mishirube"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The same id as the iOS app. The Kotlin package stays the namespace.
        applicationId = "dev.koukeneko.mishirube"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect's client needs Android 8 (API 26).
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            storeFile = uploadKeyValue("storeFile", "ANDROID_KEYSTORE_PATH")?.let(::file)
            storePassword = uploadKeyValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
            keyAlias = uploadKeyValue("keyAlias", "ANDROID_KEY_ALIAS")
            keyPassword = uploadKeyValue("keyPassword", "ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.getByName("upload").storeFile != null) {
                signingConfigs.getByName("upload")
            } else {
                // So `flutter run --release` works without the key.
                signingConfigs.getByName("debug")
            }
        }
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

dependencies {
    implementation("androidx.health.connect:connect-client:1.1.0")
    // Bundled, so reading a label works offline on first use.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    // The workout on a paired Wear OS watch (android/wear).
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
    // A workout's route (RouteMap.kt), on OpenFreeMap's tiles.
    implementation("org.maplibre.gl:android-sdk:13.6.1")
}
