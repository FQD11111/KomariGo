plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.lcdcxp.komarigo"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.lcdcxp.komarigo"
        minSdk = 26
        targetSdk = 34
        versionCode = 9
        versionName = "1.5.2"
    }

    signingConfigs {
        create("release") {
            val storePath = project.findProperty("komari.storeFile") as String?
            if (storePath != null) {
                storeFile = file(storePath)
                storePassword = project.findProperty("komari.storePassword") as String?
                keyAlias = (project.findProperty("komari.keyAlias") as String?) ?: "komari"
                keyPassword = project.findProperty("komari.keyPassword") as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources.excludes += setOf(
            "META-INF/*.version",
            "META-INF/LICENSE*",
            "META-INF/NOTICE*",
            "DebugProbesKt.bin",
            "kotlin/**"
        )
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.09.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.activity:activity-compose:1.9.2")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // 后台告警轮询
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    // 桌面小组件
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.glance:glance-material3:1.1.1")
}
