import java.util.Properties
import java.io.FileInputStream
import java.io.FileNotFoundException
import org.gradle.api.GradleException
plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val dotenv = Properties()

val envFile = file("${rootProject.projectDir}/../lib/config/.env")
val localPropertiesFile = rootProject.file("local.properties")

val localProperties = Properties()
if (localPropertiesFile.exists()) {
    localPropertiesFile.reader().use { reader ->
        localProperties.load(reader)
    }
}


if (envFile.exists()) {
    FileInputStream(envFile).use { inputStream ->
        dotenv.load(inputStream)
    }
} else {
    throw FileNotFoundException("Could not find .env file at: ${envFile.path}")
}


android {
    namespace = "com.example.muse_mate"
    compileSdk = flutter.compileSdkVersion
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
        applicationId = "com.example.muse_mate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val googleKey = dotenv["GOOGLE_MAPS_API_KEY"] as? String
        if (googleKey == null) {
            throw GradleException("GOOGLE_MAPS_APP_KEY not found in .env file")
        }
        manifestPlaceholders["MAPS_API_KEY"] = googleKey
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
