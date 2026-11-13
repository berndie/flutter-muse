import java.util.Properties

group = "dev.fluttermuse.flutter_muse_android"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

// ---------------------------------------------------------------------------
// The Muse SDK is proprietary and is not shipped with this package. Point the
// build at your copy of it: a directory containing
//
//   libmuse_android.jar
//   arm64-v8a/libmuse_android.so      (and any other ABIs you ship)
//   armeabi-v7a/libmuse_android.so
//
// Set it in the first of these places that applies (relative paths are
// resolved against your app's android/ directory):
//   1. `museSdkDir=...` in android/gradle.properties (or -PmuseSdkDir=...)
//   2. `muse.sdk.dir=...` in android/local.properties
//   3. the MUSE_SDK_DIR environment variable
// Otherwise this package's own android/libs/ directory is used (for
// development of the plugin itself; it is git- and pub-ignored).
// ---------------------------------------------------------------------------
fun resolveMuseSdkDir(): File {
    val localProperties = Properties().apply {
        val f = rootProject.file("local.properties")
        if (f.isFile) f.inputStream().use { load(it) }
    }
    val configured = (findProperty("museSdkDir") as String?)
        ?: localProperties.getProperty("muse.sdk.dir")
        ?: System.getenv("MUSE_SDK_DIR")
    return if (configured.isNullOrBlank()) file("libs") else rootProject.file(configured)
}

val museSdkDir: File = resolveMuseSdkDir()
val museJar: File = museSdkDir.resolve("libmuse_android.jar")
if (!museJar.isFile) {
    throw GradleException(
        "flutter_muse_android: libmuse_android.jar not found in $museSdkDir.\n" +
            "Get the Muse SDK from Interaxon and set museSdkDir=/path/to/sdk in android/gradle.properties " +
            "(see the flutter_muse_android README)."
    )
}

android {
    namespace = "dev.fluttermuse.flutter_muse_android"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            // <museSdkDir>/<abi>/libmuse_android.so
            jniLibs.srcDirs(museSdkDir)
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        // Keeps the JNI-bound Muse SDK classes in apps that run R8.
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // The Muse SDK Java API. Exposed with `api` so app code can also use
    // com.choosemuse.libmuse classes directly (e.g. to install a socket.io
    // client factory for cloud features).
    api(files(museJar))

    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
