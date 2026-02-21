#!/bin/bash
set -e

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/tmp/android-sdk
export PATH=$PATH:$ANDROID_HOME/build-tools/34.0.0:$ANDROID_HOME/platform-tools

# Create structure
mkdir -p app/src/main/{java/com/popis/app,assets/www,res/{values,mipmap-mdpi,mipmap-hdpi,mipmap-xhdpi,mipmap-xxhdpi}}

# Copy web files
cp ../docs/* app/src/main/assets/www/

# Copy icons
cp ../docs/icon-192.png app/src/main/res/mipmap-mdpi/ic_launcher.png
cp ../docs/icon-192.png app/src/main/res/mipmap-hdpi/ic_launcher.png
cp ../docs/icon-192.png app/src/main/res/mipmap-xhdpi/ic_launcher.png
cp ../docs/icon-192.png app/src/main/res/mipmap-xxhdpi/ic_launcher.png

# AndroidManifest.xml
cat > app/src/main/AndroidManifest.xml << 'MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.popis.app"
    android:versionCode="1"
    android:versionName="1.0">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="Popis"
        android:theme="@android:style/Theme.NoTitleBar.Fullscreen">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
MANIFEST

# strings.xml
cat > app/src/main/res/values/strings.xml << 'STRINGS'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Popis</string>
</resources>
STRINGS

# MainActivity.java
cat > app/src/main/java/com/popis/app/MainActivity.java << 'JAVA'
package com.popis.app;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebSettings;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView webView = new WebView(this);
        setContentView(webView);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        webView.loadUrl("file:///android_asset/www/index.html");
    }
}
JAVA

# Compile resources
mkdir -p build
aapt2 compile --dir app/src/main/res -o build/compiled_resources.zip

# Link resources
aapt2 link \
  -o build/popis-unsigned.apk \
  -I $ANDROID_HOME/platforms/android-34/android.jar \
  --manifest app/src/main/AndroidManifest.xml \
  --java app/src/main/java \
  build/compiled_resources.zip

# Compile Java
javac -source 1.8 -target 1.8 \
  -bootclasspath $JAVA_HOME/jre/lib/rt.jar \
  -classpath $ANDROID_HOME/platforms/android-34/android.jar \
  -d build/classes \
  app/src/main/java/com/popis/app/MainActivity.java

# Create DEX
d8 --lib $ANDROID_HOME/platforms/android-34/android.jar \
  --output build/ \
  build/classes/com/popis/app/MainActivity.class

# Package APK
cd build
mkdir -p temp && cd temp
unzip -q -o ../popis-unsigned.apk
cp ../classes.dex .
mkdir -p assets
cp -r ../../app/src/main/assets/* assets/
zip -qr -0 ../popis-packaged.apk .
cd ..

# Align
zipalign -f 4 popis-packaged.apk popis-aligned.apk

# Sign (debug)
keytool -genkeypair -v \
  -keystore debug.keystore \
  -storepass android \
  -alias androiddebugkey \
  -keypass android \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Debug,O=Android,C=US" 2>/dev/null

apksigner sign \
  --ks debug.keystore \
  --ks-pass pass:android \
  --out popis.apk \
  popis-aligned.apk

echo "APK built: $(pwd)/popis.apk"
ls -lh popis.apk
