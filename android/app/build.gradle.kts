plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.fscm_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.fscm_mobile"
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

// Automatically forward local backend ports (7027 HTTPS, 5246 HTTP) over USB
// for every connected Android device whenever a debug build is assembled.
tasks.matching { it.name == "assembleDebug" }.configureEach {
    doLast {
        try {
            val adb = android.adbExecutable
            if (adb.exists()) {
                val out = ProcessBuilder(adb.absolutePath, "devices")
                    .redirectErrorStream(true)
                    .start()
                    .inputStream
                    .bufferedReader()
                    .readText()
                out.lines()
                    .drop(1)
                    .map { it.trim() }
                    .filter { it.endsWith("\tdevice") }
                    .map { it.substringBefore("\t").trim() }
                    .forEach { serial ->
                        ProcessBuilder(
                            adb.absolutePath, "-s", serial, "reverse", "tcp:7027", "tcp:7027"
                        ).start().waitFor()
                        ProcessBuilder(
                            adb.absolutePath, "-s", serial, "reverse", "tcp:5246", "tcp:5246"
                        ).start().waitFor()
                        println("Configured adb reverse (7027, 5246) for device $serial")
                    }
            }
        } catch (_: Exception) {
            // Ignore if no device is attached over USB (e.g. CI or Wi-Fi).
        }
    }
}
