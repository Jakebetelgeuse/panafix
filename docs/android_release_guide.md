# Android Release Guide

## 1. Create the upload keystore

Run this from the project root:

```powershell
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias panafix_release
```

Keep the `.jks` file in a safe place. Do not upload it to public repos.

## 2. Create `android/key.properties`

Copy `android/key.properties.example` to `android/key.properties` and replace the placeholder values:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=panafix_release
storeFile=../upload-keystore.jks
```

## 3. Build the Play Store bundle

From the project root:

```powershell
flutter pub get
flutter build appbundle --release
```

The bundle is generated at:

`build/app/outputs/bundle/release/app-release.aab`

## 4. Before uploading

- Confirm Firebase rules are deployed.
- Confirm `functions` dependencies are installed if you deploy Cloud Functions.
- Update version in `pubspec.yaml`.
- Test login, payments, notifications, chat, tracking, emergency, subscriptions, owner and admin access.

## 5. Keep private

Do not commit:

- `android/key.properties`
- `upload-keystore.jks`

Only commit the example file and docs.
