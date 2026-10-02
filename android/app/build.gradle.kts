plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/*
 * Firebase, solo si está configurado.
 *
 * `google-services.json` lo descarga el colegio de la consola de Firebase y no
 * va al repositorio: identifica el proyecto de notificaciones del instituto.
 *
 * La comprobación es lo que permite que el proyecto compile y se ejecute sin
 * cuenta de Firebase. Sin ella, cualquiera que clone el repositorio tendría el
 * build roto hasta conseguir el archivo, y la app funciona perfectamente sin
 * notificaciones: las alertas llegan por el canal en vivo.
 */
val firebaseConfig = file("google-services.json")
if (firebaseConfig.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "ALERTIC: sin google-services.json. Se compila sin notificaciones push; " +
            "las alertas llegarán por el canal en vivo con la app abierta."
    )
}

android {
    namespace = "com.example.alertic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Obligatorio para flutter_local_notifications: usa clases de fecha y
        // hora modernas que en Android viejo no existen, y el desugaring las
        // traduce al compilar.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.alertic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Messaging pide 23 como mínimo. Se toma el mayor de los dos
        // para que subir la versión de Flutter no baje este piso por accidente.
        minSdk = maxOf(flutter.minSdkVersion, 23)
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
}
