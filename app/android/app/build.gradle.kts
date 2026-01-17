plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "it.unisa.mocc"
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
        applicationId = "it.unisa.mocc"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")

            // TODO: Insert the Base64 Signature Hash for your DEBUG key here
            // This is required for MSAL to work in debug mode
            manifestPlaceholders["msalSignatureHash"] = "1/pNWOaXQYYPE8oUh+gnFURnVeE="
        }

        getByName("release") {
            // Signing with the debug keys for now so `flutter run --release` works
            // without needing a JKS file.
            signingConfig = signingConfigs.getByName("debug")

            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // TODO: Insert the Base64 Signature Hash for your RELEASE key here.
            // IMPORTANT: Since we are using "signingConfigs.debug" above,
            // you should put the DEBUG HASH here as well for now.
            // When you eventually switch to a real release key, update this value.
            manifestPlaceholders["msalSignatureHash"] = "GhA+HfJcocF4G9Oe5GK90xDBzHo="
        }
    }
}

flutter {
    source = "../.."
}