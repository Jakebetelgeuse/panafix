import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.panafix.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.panafix.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val releaseKeyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("Falta keyAlias en android/key.properties")
                val releaseKeyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: error("Falta keyPassword en android/key.properties")
                val releaseStoreFile = keystoreProperties.getProperty("storeFile")
                    ?: error("Falta storeFile en android/key.properties")
                val releaseStorePassword = keystoreProperties.getProperty("storePassword")
                    ?: error("Falta storePassword en android/key.properties")

                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = file(releaseStoreFile)
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            // Use a proper release keystore when `android/key.properties` exists.
            // This keeps local builds working while leaving Play Store signing ready.
            signingConfig = if (keystorePropertiesFile.exists()) {
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
