# HealthPocket direct-download beta release

This workflow produces the Android-only, no-money DEV beta. It never uses the
production Firebase project and it does not require a Google Play account.

## One-time signing setup

The signing key is the identity used by Android to accept later beta updates.
Losing it means testers must uninstall the existing app before installing an
update, so keep the keystore and its passwords in secure, separate backups.

1. From the repository root, create the keystore locally using Android Studio's
   bundled JDK. The leading `&` is required by PowerShell because the executable
   path contains spaces:

   ```powershell
   & 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -genkeypair -v -keystore android/healthpocket-beta.jks -keyalg RSA -keysize 2048 -validity 10000 -alias healthpocket-beta
   ```

   If Android Studio is installed elsewhere, locate its `jbr\bin\keytool.exe`
   and use that full path. There is no need to change the system `PATH` just for
   this release.

2. Copy `android/beta-signing.properties.example` to
   `android/beta-signing.properties` and replace both password placeholders.
   The file paths are relative to the `android` directory.
   Java properties treat a backslash as an escape character: if the actual
   password contains one `\`, enter it as `\\` in both password fields. Do not
   add quotes around the value. Colons and most other punctuation after the
   `=` separator do not need escaping.
3. Save the keystore, alias and both passwords in the owner-controlled Proton
   password manager. Keep an additional encrypted backup of the keystore.
4. Never send the keystore or passwords through chat, email or the tester group.

Both private files are ignored by Git. Check `git status` before every commit.

## Build the APK

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build-beta-apk.ps1
```

The script refuses to build without complete signing configuration, builds the
`devRelease` flavour from `lib/main_dev.dart`, copies the versioned APK into
`beta-site/releases/`, and prints its SHA-256 checksum. APK files in that
directory are ignored by Git; deploy the generated file directly with Netlify.

Before sharing a release, install it on at least one physical Android device and
complete the smoke test in `beta-site/README.md`.

## Updating testers

Increase the build number after every shared APK, even when the version name is
unchanged—for example, `1.0.0+2`. Build with the same signing key. Testers can
install the newer APK over the existing beta without losing local app data.
