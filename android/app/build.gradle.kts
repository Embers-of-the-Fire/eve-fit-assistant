plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningVars = mapOf(
    "EFA_KEYSTORE_FILE" to System.getenv("EFA_KEYSTORE_FILE"),
    "EFA_KEYSTORE_PASSWORD" to System.getenv("EFA_KEYSTORE_PASSWORD"),
    "EFA_KEY_ALIAS" to System.getenv("EFA_KEY_ALIAS"),
    "EFA_KEY_PASSWORD" to System.getenv("EFA_KEY_PASSWORD"),
)
val releaseSigningConfigured = releaseSigningVars.values.count { !it.isNullOrEmpty() }
val releaseSigningAvailable = releaseSigningConfigured == releaseSigningVars.size
if (releaseSigningConfigured in 1 until releaseSigningVars.size) {
    val missing = releaseSigningVars.filterValues { it.isNullOrEmpty() }.keys
    throw GradleException(
        "Incomplete release signing configuration: $missing not set or empty. " +
            "Set all EFA_* variables or none (debug fallback)."
    )
}

android {
    namespace = "dev.efa_tech.eve_fit_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "dev.efa_tech.eve_fit_assistant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningAvailable) {
            create("release") {
                storeFile = file(releaseSigningVars.getValue("EFA_KEYSTORE_FILE"))
                storePassword = releaseSigningVars.getValue("EFA_KEYSTORE_PASSWORD")
                keyAlias = releaseSigningVars.getValue("EFA_KEY_ALIAS")
                keyPassword = releaseSigningVars.getValue("EFA_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Release builds are signed with the EFA release key when the EFA_* environment
            // variables are provided (CI real releases); a partially provided set fails the
            // build loudly, and a fully absent set falls back to the debug keys so
            // `flutter run --release` and CI test-mode builds keep working.
            signingConfig = if (releaseSigningAvailable) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
