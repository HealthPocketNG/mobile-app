# HealthPocket beta landing page

This directory is a standalone static site. It has no package manager, build
step or dependency on the Flutter application. Netlify publishes only this
directory, as configured in the repository-level `netlify.toml`.

## Local preview

Open `index.html` directly, or run any local static-file server with this
directory as its root.

## Release checklist

1. Complete the signing setup in `docs/beta-release.md`.
2. Run `scripts/build-beta-apk.ps1`.
3. Install the generated APK on a physical Android device.
4. Confirm sign-up, email verification, PIN creation and restart unlock.
5. Confirm profile editing, a simulated contribution and Family Pocket access.
6. Confirm Find Care filtering and the demo QR/manual-code path.
7. Confirm the support-email handoff or copy-address fallback.
8. Confirm the download path, file size and SHA-256 checksum in `index.html`
   match the generated APK.
9. Deploy `beta-site/` and the ignored APK together through a Netlify manual
   folder upload or `netlify deploy --dir beta-site --prod`. A Git-only deploy
   will intentionally omit the ignored APK.
10. Open the deployed link on an Android device and download/install once more.

The site is deliberately marked `noindex`, but that is not authentication.
Anyone who receives or forwards the URL can access it. Share it only in the
private tester group and rotate the Netlify site URL if it leaks.
