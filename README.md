Arbchar — Bluetooth Chat (Android)
==================================

This package contains a ready-to-use **Flutter** project skeleton for *Arbchar* (Bluetooth chat)
with a dark theme, local message history (sqflite), and basic AES encryption of messages.
It is designed for **Android** (test on real devices).

Quick start
-----------
1. Install Flutter and Android SDK on your machine. Verify with `flutter doctor`.
2. Create a new Flutter project (this generates necessary Android/Gradle files):
   ```bash
   flutter create arbchar
   ```
3. Replace the generated `lib/` folder with the `lib/` from this ZIP, and replace `pubspec.yaml` in the project root with the `pubspec.yaml` from this ZIP.
   ```bash
   # from the folder where you unzipped:
   cp -r lib /path/to/arbchar/
   cp pubspec.yaml /path/to/arbchar/
   ```
4. Get packages:
   ```bash
   cd /path/to/arbchar
   flutter pub get
   ```
5. Edit `android/app/src/main/AndroidManifest.xml` to include required permissions (see section below). The project created by `flutter create` already has the file; add the shown `<uses-permission>` lines inside the `<manifest>` element.
6. Connect an Android device with USB debugging enabled and run:
   ```bash
   flutter run
   ```
7. For release APK:
   ```bash
   flutter build apk --release
   ```

Important notes and permissions
-------------------------------
Add the following to `android/app/src/main/AndroidManifest.xml` (inside the `<manifest>` tag, before `<application>`):
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<!-- Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

For Android 12+ you must request new runtime permissions `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` as well as location as appropriate.
The app uses `permission_handler` package to ask for `location` permission; you may need to expand it for your target SDK and request specific Bluetooth runtime permissions on Android 12+.

Limitations
-----------
- This skeleton is targeted at **Android only** (iOS Bluetooth behavior differs).
- Bluetooth pairing and connection behavior may vary by device/manufacturer.
- Encryption is basic AES-CBC with a generated key stored locally (not secure for high-security needs). For stronger security, use proper key exchange and secure storage.

Support / Next steps
--------------------
If you want, I can:
- produce a full ZIP that automatically overwrites a `flutter create` generated project (I can do that next), or
- produce a signed APK (you must provide a signing key), or
- add file transfer, nicknames, rooms, or more robust key management.

