# Android Permissions Configuration

Add the following permissions to your `android/app/src/main/AndroidManifest.xml` file:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

Place these permissions before the `<application>` tag.

## Example AndroidManifest.xml structure:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <application
        android:label="fake_currency_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- Your activity configurations -->
    </application>
</manifest>
```
