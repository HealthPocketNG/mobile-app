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

## MVP authentication

The app uses Firebase Authentication for Email/Password and Google Sign-In.
Email/password accounts must verify their email before Firestore data is
accessible. Firebase restores the signed-in account session; subsequent local
opens require a six-digit HealthPocket PIN.

The PIN is only an app-unlock factor. It never replaces the Firebase credential,
is never written to Firestore, and is stored as a salted PBKDF2-SHA256 hash in
Android Keystore-backed secure storage. Five failed attempts trigger a short
local lockout. Forgot-PIN recovery requires Firebase re-authentication before a
new local PIN can be created. Android backup is disabled so PIN material is not
silently transferred to a different device.

Phone/SMS authentication, production KYC, BVN/NIN checks, biometric unlock and
identity-document collection are deliberately not implemented in this MVP.
Repository and profile boundaries retain room for regulated providers later.

Before testing Google Sign-In against real DEV Firebase, enable Email/Password
and Google in **Authentication → Sign-in method** for
`healthpocket-dev-a82f3`, select the project support email, then refresh only
the DEV Android configuration:

```bash
flutterfire configure --project=healthpocket-dev-a82f3 --platforms=android --android-package-name=com.healthpocket.app.dev --out=lib/firebase/firebase_options_dev.dart --android-out=android/app/src/dev/google-services.json --yes
```

Do not enable production providers or refresh production configuration until
the production-auth review is approved.
# Find care beta directory

## DEV care-request simulator

In the DEV app, open Find care, select an active demo centre, then tap its
demo-authorization action. Confirm an amount and scan a mock QR such as
`hp://provider/demo_clinic_001`. The QR contains only a stable fictional provider
ID. Unknown, inactive, malformed, and mismatched providers are rejected.

This is temporary in-memory design state, not a partner portal. It does not sync,
persist, debit/reserve balances, write contributions, or expose settlement
controls. It is gated by the existing development-simulation flag. Device camera
tests remain required before the external beta build.
Rebuild the app after adding the scanner plugin; hot reload is insufficient.


The Find care tab currently uses bundled, explicitly fictional demo providers.
It works offline and supports name search, state/type filters, and details.
No real addresses, phone numbers, bookings, payments, or care authorizations
are supplied by these listings. `CareDirectoryRepository` is the extension
point for reviewed partner data; no Firestore resources were changed for this
slice. Real provider onboarding and administration remain in `TODO.md`.

Website copy is drafted in `privacy-policy/terms.txt`. It is not publication-ready:
resolve the owner checklist, review actual data practices, and supply the final
Privacy and Terms URLs before connecting the app's website links.
