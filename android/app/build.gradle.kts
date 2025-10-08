plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mayank.study_sensei"
    compileSdk = 36
    ndkVersion = "26.1.10909125"

    defaultConfig {
        applicationId = "com.mayank.study_sensei"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode?.toInt() ?: 1
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:32.5.0"))

    // Add the dependencies for the Firebase products you want to use
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")
    // Add other Firebase dependencies as needed
}

flutter {
    source = "../.."
}