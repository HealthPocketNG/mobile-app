# HealthPocket

HealthPocket helps Nigerians prepare financially for healthcare before an
emergency occurs. This repository currently implements the mobile UI MVP in
Flutter.

## Environments

HealthPocket uses separate Android flavors and Firebase projects:

| Environment | Android application ID | Firebase project |
| --- | --- | --- |
| Development | `com.healthpocket.app.dev` | `healthpocket-dev-a82f3` |
| Production | `com.healthpocket.app` | `healthpocket-ng` |

The production Android flavor is release-only. Gradle does not generate a
`prodDebug` or `prodProfile` variant. The Dart bootstrap also rejects production
Firebase options outside release mode, a Firebase project assigned to the wrong
environment, or an entrypoint paired with the wrong Android flavor. The Firebase
CLI's default project alias is development.

## Run locally

```bash
flutter pub get
flutter run --flavor dev --target lib/main_dev.dart
```

VS Code users can select the `HealthPocket Dev` launch configuration.

## Firebase emulators

Start the local Auth and Firestore emulators from the repository root:

```bash
firebase emulators:start --only auth,firestore --project healthpocket-dev-a82f3
```

For an Android emulator, select `HealthPocket Dev (Firebase emulators)` in VS
Code or run:

```bash
flutter run --flavor dev --target lib/main_dev.dart --dart-define=USE_FIREBASE_EMULATORS=true
```

Android emulators reach the host computer at `10.0.2.2`. For a USB-connected
Android device, reverse the emulator ports and override the host instead:

```bash
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
flutter run --flavor dev --target lib/main_dev.dart --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

The Dart bootstrap rejects emulator routing in a production build. Running the
DEV app without `USE_FIREBASE_EMULATORS=true` connects to the real DEV Firebase
project, never production.

Install and run the Firestore security-rule tests with:

```bash
npm install --prefix firebase-tests
firebase emulators:exec --only auth,firestore --project demo-healthpocket "npm --prefix firebase-tests test"
```

## Before production distribution

Production deliberately has no signing key configured yet. Create a protected
upload key, enable Play App Signing, configure Gradle to read the credentials
from an uncommitted properties file or CI secrets, and register the upload/app
signing SHA-1 and SHA-256 fingerprints with the production Firebase app. Then
create the Play Store bundle with:

```bash
flutter build appbundle --release --flavor prod --target lib/main_prod.dart
```

Refresh Firebase configuration after adding a Firebase product or platform:

```bash
flutterfire configure --project=healthpocket-dev-a82f3 --platforms=android --android-package-name=com.healthpocket.app.dev --out=lib/firebase/firebase_options_dev.dart --android-out=android/app/src/dev/google-services.json --yes
flutterfire configure --project=healthpocket-ng --platforms=android --android-package-name=com.healthpocket.app --out=lib/firebase/firebase_options_prod.dart --android-out=android/app/src/prod/google-services.json --yes
```

The MVP scope and product decisions are maintained in
`HealthPocketMVP-PRD-for-Codex.md`.
