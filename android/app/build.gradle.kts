import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun signingProp(name: String): String? {
    val fromEnv = System.getenv(name)
    if (!fromEnv.isNullOrBlank()) {
        return fromEnv
    }
    val fromFile = keystoreProperties.getProperty(name)
    if (!fromFile.isNullOrBlank()) {
        return fromFile
    }
    return null
}

android {
    namespace = "net.roamkit.bbuem"
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
        applicationId = "net.roamkit.bbuem"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath =
                signingProp("KEYSTORE_PATH") ?: signingProp("storeFile")
            val storePasswordValue =
                signingProp("KEYSTORE_PASSWORD") ?: signingProp("storePassword")
            val keyAliasValue =
                signingProp("KEYSTORE_ALIAS") ?: signingProp("keyAlias")
            val keyPasswordValue =
                signingProp("KEY_PASSWORD") ?: signingProp("keyPassword")
            if (
                !storeFilePath.isNullOrBlank() &&
                !storePasswordValue.isNullOrBlank() &&
                !keyAliasValue.isNullOrBlank() &&
                !keyPasswordValue.isNullOrBlank()
            ) {
                storeFile = file(storeFilePath)
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            val hasReleaseSigning = releaseSigning.storeFile != null
            val requireSigning =
                System.getenv("CI") == "true" ||
                    System.getenv("ROAMKIT_REQUIRE_RELEASE_SIGNING") == "true"
            if (requireSigning && !hasReleaseSigning) {
                throw GradleException(
                    "Release signing required but KEYSTORE_* / key.properties missing",
                )
            }
            // Local unsigned convenience: fall back to debug when no keystore configured.
            signingConfig =
                if (hasReleaseSigning) {
                    releaseSigning
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
