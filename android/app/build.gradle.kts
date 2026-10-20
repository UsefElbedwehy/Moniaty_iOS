import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Firebase (push, analytics, Crashlytics) switches on once the Android app's
// google-services.json is in app/ — the same Firebase project as iOS. Without it the app builds
// and runs; push and Firebase analytics are simply off.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

// Backend values (the Android twin of App/Resources/BackendConfig.plist).
// `./gradlew :app:installDebug -Pmock` builds without them: everything runs on in-memory mocks.
val backend = Properties().apply {
    if (!project.hasProperty("mock")) {
        rootProject.file("backend.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
    }
}

// Release signing (the Play upload key) from keystore.properties, which stays out of git:
//   storeFile=/absolute/path/munyati-upload.jks
//   storePassword=…
//   keyAlias=upload
//   keyPassword=…
val keystore = Properties().apply {
    rootProject.file("keystore.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}

android {
    namespace = "co.munyati.app"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "co.munyati.app"
        minSdk = libs.versions.minSdk.get().toInt()
        targetSdk = libs.versions.compileSdk.get().toInt()
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "SUPABASE_URL", "\"${backend.getProperty("SUPABASE_URL", "")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${backend.getProperty("SUPABASE_ANON_KEY", "")}\"")
        // Google Maps for Explore (an Android key restricted to co.munyati.app). Empty = no map.
        val mapsKey = backend.getProperty("MAPS_API_KEY", "")
        buildConfigField("String", "MAPS_API_KEY", "\"$mapsKey\"")
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    signingConfigs {
        if (keystore.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keystore.getProperty("storeFile"))
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfigs.findByName("release")?.let { signingConfig = it }
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    androidResources {
        // Arabic first, English second — the same two languages as iOS.
        @Suppress("UnstableApiUsage")
        generateLocaleConfig = true
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    implementation(project(":core"))
    implementation(project(":networking"))
    implementation(project(":shared"))
    implementation(project(":designsystem"))
    implementation(project(":authentication"))
    implementation(project(":features:catalog"))
    implementation(project(":features:providerstudio"))
    implementation(project(":features:booking"))
    implementation(project(":features:trust"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.security.crypto)
    implementation(libs.okhttp)
    // Firebase pulls an old Fragment; ActivityResult (the notification permission) needs 1.3+.
    implementation(libs.androidx.fragment)
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.crashlytics)

    testImplementation(libs.junit)
}
