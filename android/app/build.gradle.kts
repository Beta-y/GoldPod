import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.text.SimpleDateFormat
import java.util.*
import java.io.File

// 读取 pubspec.yaml 文件内容
val pubspec = File("${project.projectDir}/../../pubspec.yaml").readText()

// 解析 versionName 和 versionCode
val versionNameRegex = Regex("version:\\s+(\\d+\\.\\d+\\.\\d+)\\+\\d+")
val versionCodeRegex = Regex("version:\\s+\\d+\\.\\d+\\.\\d+\\+(\\d+)")

val versionName = versionNameRegex.find(pubspec)?.groupValues?.get(1) ?: "1.0.0"
val versionCode = versionCodeRegex.find(pubspec)?.groupValues?.get(1)?.toInt() ?: 1

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    defaultConfig {
        versionName = versionName
        versionCode = versionCode
    }

    namespace = "com.example.bill_app"
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
        applicationId = "com.example.bill_app"
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

applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val buildType = variant.buildType.name
            val versionName = variant.versionName

            // 修复后的日期处理
            val dateFormat = SimpleDateFormat("yyyyMMdd_HHmm", Locale.getDefault())
            val date = dateFormat.format(Date())

            (this as BaseVariantOutputImpl).outputFileName =
                "BillApp_${versionName}_${date}_${buildType}.apk"
        }
    }
}

flutter {
    source = "../.."
}
