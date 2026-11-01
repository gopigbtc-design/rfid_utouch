plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // CRITICAL: namespace and applicationId MUST match. AGP 8+ resolves
    // android:name=".MainActivity" against `namespace`, not
    // `applicationId`. A mismatch here is what caused the long-standing
    // "handheld not receiving RFID data" bug previously - Android was
    // launching Flutter's auto-generated default MainActivity instead
    // of the real one with the broadcast receivers in it.
    namespace = "com.isens.rfidscanner"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.isens.rfidscanner"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: replace with a real release signing config before
            // distributing outside your own test devices.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
