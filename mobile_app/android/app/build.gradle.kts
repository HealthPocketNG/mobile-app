import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val betaSigningPropertiesFile = rootProject.file("beta-signing.properties")
val betaSigningProperties = Properties().apply {
    if (betaSigningPropertiesFile.exists()) {
        betaSigningPropertiesFile.inputStream().use { input -> load(input) }
    }
}

android {
    namespace = "com.healthpocket.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        resValues = true
    }

    signingConfigs {
        if (betaSigningPropertiesFile.exists()) {
            create("betaRelease") {
                keyAlias = betaSigningProperties.getProperty("keyAlias")
                keyPassword = betaSigningProperties.getProperty("keyPassword")
                storeFile = rootProject.file(betaSigningProperties.getProperty("storeFile"))
                storePassword = betaSigningProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.healthpocket.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage 11 requires Android 6.0 or newer.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "HealthPocket Dev")
            // Local debug builds remain convenient. The documented beta build
            // script refuses to create a distributable APK without the private
            // beta signing properties and keystore.
            signingConfig = if (betaSigningPropertiesFile.exists()) {
                signingConfigs.getByName("betaRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "HealthPocket")
        }
    }

    buildTypes {
        release {
            // Production signing is intentionally not configured here. Add a
            // protected upload key before distributing the prodRelease bundle.
        }
    }
}

// Production Firebase must never be available to a debuggable Android build.
androidComponents {
    beforeVariants { variantBuilder ->
        val isProduction = variantBuilder.productFlavors.contains(
            "environment" to "prod",
        )
        if (isProduction && variantBuilder.buildType != "release") {
            variantBuilder.enable = false
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
