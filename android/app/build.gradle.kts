plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.togaware.foliopod"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.togaware.foliopod"

        // 20260731 gjw flutter_appauth (via solidpod, for Solid OIDC
        // login) contributes AppAuth's RedirectUriReceiverActivity to the
        // merged manifest with android:scheme="${appAuthRedirectScheme}".
        // The merger fails unless the app supplies that placeholder, so
        // set it to the scheme of the redirect URI registered in
        // main.dart (com.togaware.foliopod://redirect) and in the
        // client-profile.jsonld. Schemes must be lower case.
        manifestPlaceholders["appAuthRedirectScheme"] =
            "com.togaware.foliopod"

        // oidcRedirectScheme is required by oidc_android, which declares no
        // default for it, so the manifest merger fails without it.
        manifestPlaceholders["oidcRedirectScheme"] = "com.togaware.foliopod"

        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
