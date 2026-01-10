plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.secure_p2p_messenger"
    compileSdk = 35
    ndkVersion = "25.1.8937393"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        // IMPORTANT: Change this to your own unique package name
        // Format: com.yourdomain.appname
        // Example: com.mycompany.securemessenger
        applicationId = "com.example.secure_p2p_messenger"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 1
        versionName = "2.0.0"
    }

    buildTypes {
        release {
            // For production builds, you need to configure signing:
            //
            // 1. Generate a keystore file:
            //    keytool -genkey -v -keystore ~/upload-keystore.jks \
            //            -keyalg RSA -keysize 2048 -validity 10000 \
            //            -alias upload
            //
            // 2. Create android/key.properties file:
            //    storePassword=<password from previous step>
            //    keyPassword=<password from previous step>
            //    keyAlias=upload
            //    storeFile=<path to upload-keystore.jks>
            //
            // 3. Uncomment the signingConfigs section below
            //
            // For now, using debug signing (NOT secure for production!)
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Uncomment this section after creating your keystore:
    /*
    signingConfigs {
        create("release") {
            val keystorePropertiesFile = rootProject.file("key.properties")
            val keystoreProperties = java.util.Properties()
            if (keystorePropertiesFile.exists()) {
                keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
            }
            
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    */
}

flutter {
    source = "../.."
}

dependencies {}
