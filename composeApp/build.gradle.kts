import org.jetbrains.compose.desktop.application.dsl.TargetFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.composeHotReload)
    alias(libs.plugins.kotlinSerialization)
}

kotlin {
    androidTarget {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }
    
    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "ComposeApp"
            isStatic = true
        }
    }
    
    jvm()
    
    sourceSets {
        androidMain.dependencies {
            implementation(libs.compose.uiToolingPreview)
            implementation(libs.androidx.activity.compose)
        }
        commonMain.dependencies {
            implementation(libs.compose.runtime)
            implementation(libs.compose.foundation)
            implementation(libs.compose.material3)
            implementation(libs.compose.ui)
            implementation(libs.compose.components.resources)
            implementation(libs.compose.uiToolingPreview)
            implementation(libs.androidx.lifecycle.viewmodelCompose)
            implementation(libs.androidx.lifecycle.runtimeCompose)
            implementation(libs.compose.icons.tabler)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.filekit.dialogs.compose)
            implementation(libs.composemediaplayer)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
        }
        jvmMain.dependencies {
            implementation(compose.desktop.currentOs)
            implementation(libs.kotlinx.coroutinesSwing)
            implementation(libs.javacv)
            // Only include macOS natives (javacv-platform pulls all platforms)
            val javacvVersion = "1.5.11"
            val ffmpegVersion = "7.1-$javacvVersion"
            val opencvVersion = "4.10.0-$javacvVersion"
            listOf("macosx-x86_64", "macosx-arm64").forEach { platform ->
                implementation("org.bytedeco:ffmpeg:$ffmpegVersion:$platform")
                implementation("org.bytedeco:opencv:$opencvVersion:$platform")
                implementation("org.bytedeco:openblas:0.3.28-$javacvVersion:$platform")
                implementation("org.bytedeco:javacpp:$javacvVersion:$platform")
            }
        }
    }
}

val appVersion = providers.fileContents(rootProject.layout.projectDirectory.file("VERSION"))
    .asText.map { it.trim() }

android {
    namespace = "com.yannickpulver.slides"
    compileSdk = libs.versions.android.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.yannickpulver.slides"
        minSdk = libs.versions.android.minSdk.get().toInt()
        targetSdk = libs.versions.android.targetSdk.get().toInt()
        versionCode = 1
        versionName = appVersion.get()
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    debugImplementation(libs.compose.uiTooling)
}

val generateVersionResource by tasks.registering {
    val version = appVersion
    val outputDir = layout.buildDirectory.dir("generated/resources/version")
    inputs.property("version", version)
    outputs.dir(outputDir)
    doLast {
        val dir = outputDir.get().asFile
        dir.mkdirs()
        dir.resolve("version.txt").writeText(version.get())
    }
}

kotlin.sourceSets.named("jvmMain") {
    resources.srcDir(generateVersionResource)
}

compose.desktop {
    application {
        mainClass = "com.yannickpulver.slides.MainKt"

        nativeDistributions {
            targetFormats(TargetFormat.Dmg)
            packageName = "Slides"
            packageVersion = appVersion.get()
            includeAllModules = true
            macOS {
                bundleID = "com.yannickpulver.slides"
                iconFile.set(project.file("icon.icns"))
                minimumSystemVersion = "12.0"
                signing {
                    sign.set(true)
                    identity.set("Yannick Pulver")
                }
                entitlementsFile.set(project.file("default-entitlements.plist"))
            }
        }

        buildTypes.release.proguard {
            isEnabled = false
        }
    }
}
