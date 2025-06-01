import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Read versionCode and versionName from local.properties
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val flutterVersionCode = localProperties.getProperty("flutter.versionCode") ?: "1"
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

// Function to read properties from local.properties or a dedicated keystore.properties
fun getKeystoreProperties(project: Project): Properties {
    val keystoreProps = Properties()
    // Try local.properties first, then a dedicated keystore.properties
    var keystoreFile = project.rootProject.file("local.properties")
    if (!keystoreFile.exists()) {
        keystoreFile = project.file("keystore.properties") // Assumes keystore.properties is in android/app/
    }
    if (keystoreFile.exists()) {
        keystoreProps.load(FileInputStream(keystoreFile))
    }
    return keystoreProps
}

val keystoreProperties = getKeystoreProperties(project)

android {
    namespace = "com.mohamad.hasan.it.smart_waste"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mohamad.hasan.it.smart_waste"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
        multiDexEnabled = true
    }
    dependencies {
        // Import the Firebase BoM
        implementation(platform("com.google.firebase:firebase-bom:33.13.0"))

        // TODO: Add the dependencies for Firebase products you want to use
        // When using the BoM, don't specify versions in Firebase dependencies
        implementation("com.google.firebase:firebase-analytics")
        implementation("com.google.firebase:firebase-messaging")
        implementation("androidx.multidex:multidex:2.0.1")

        // Add the dependencies for any other desired Firebase products
        // https://firebase.google.com/docs/android/setup#available-libraries
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
    signingConfigs {
        create("release") {
            val storeFileProperty = keystoreProperties.getProperty("MYAPP_RELEASE_STORE_FILE")
            val storePasswordProperty = keystoreProperties.getProperty("MYAPP_RELEASE_STORE_PASSWORD")
            val keyAliasProperty = keystoreProperties.getProperty("MYAPP_RELEASE_KEY_ALIAS")
            val keyPasswordProperty = keystoreProperties.getProperty("MYAPP_RELEASE_KEY_PASSWORD")

            if (storeFileProperty != null && storePasswordProperty != null && keyAliasProperty != null && keyPasswordProperty != null) {
                storeFile = project.file(storeFileProperty) // Ensure this path is correct relative to the project root or app module
                storePassword = storePasswordProperty
                keyAlias = keyAliasProperty
                keyPassword = keyPasswordProperty
            } else {
                println("Warning: Release signing keystore properties not found in local.properties or keystore.properties. The release build may not be signed correctly or might use a default debug key if available.")
                // Fallback to debug if properties are missing, or handle as an error
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // You can add other release-specific configurations here, like ProGuard rules
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
