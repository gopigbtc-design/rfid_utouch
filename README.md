# ISENS RFID Handheld App

Flutter/Android app for RFID handheld scanning, supporting **both**:
- **Janam XR2** (DataWedge-style broadcast: action `com.ubx.scan.rfid`, extras `rfid_epc`/`rfid_data`)
- **AutoID uTouch2** (broadcast: action `com.android.server.scannerservice.broadcast`, extra `scannerdata`)

Both scanners work simultaneously — whichever physical device you're using, the app receives it through the same pipeline.

## First-time setup after cloning into a new repo

1. Push this folder as the repo root (so `.github/workflows/build_apk.yml`, `pubspec.yaml`, `lib/`, `android/` are all at the top level).
2. Push to `main` (or use **Actions → Build APK → Run workflow** to trigger manually).
3. Once the run finishes green, download the `isens-rfid-handheld-apk` artifact and install it on the device.
4. Open the app → **Server Settings** (from the login screen) → enter your Raspberry Pi's IP and port (default `8000`) → **Test Connection** → **Save**.
5. Log in with your dashboard credentials.

## uTouch2 scanner-engine settings

In the uTouch2's own scanner app (UHF app) → **Settings → Broadcast mode → Customized broadcast**, set:

| Field | Value |
|---|---|
| Broadcast name (Intent Action) | `com.android.server.scannerservice.broadcast` |
| Data Key value | `scannerdata` |
| Add Enter with broadcast mode | ON |

`Start seek broadcast` / `Stop seek broadcast` can be left at their defaults — they're for *remote-triggering* a scan from another app, which this app doesn't use (you trigger scans with the physical trigger).

## Janam XR2 wedge-app settings

Associated application: `com.isens.rfidscanner`, broadcast action `com.ubx.scan.rfid`, extras `rfid_epc` and `rfid_data` (as configured previously).

## Diagnosing "scanner not receiving data"

Open the app → **Diagnostics** icon (top right) → **Diagnostics** tab:
- `Native code version` — confirms which build is actually installed on the device. Bump this string in `MainActivity.kt` whenever you change it, so you can always tell a rebuild actually took effect.
- Each scanner's card shows whether its receiver registered successfully and how many reads it has seen since app start.
- **Run XR2 self-test** / **Run uTouch2 self-test** fires a fake broadcast through the real native pipeline without needing the physical scanner. If the test scan appears on the **Raw RFID Scans** tab, the app itself is working correctly — so a real trigger-pull not showing up means the physical scanner's broadcast settings don't match what's listed above, not a bug in this app.

## Why this project builds more reliably than before

Earlier iterations ran `flutter create .` fresh in CI every time (since the generated `android/` folder was never committed), then patched `applicationId`, `namespace`, and the Kotlin version with `sed` after the fact. That was fragile and caused two major bugs:
- A `namespace`/`applicationId` mismatch made Android launch Flutter's own empty default `MainActivity` instead of the real one (the actual root cause of "handheld not receiving data" for a long time).
- A Kotlin plugin version conflict between the legacy `buildscript{}` classpath style and the new `plugins{}` DSL caused "incompatible Kotlin metadata version" build errors.

This project avoids both: the `android/` folder (with the correct `namespace`/`applicationId`, Kotlin 1.9.22 pinned once via the `plugins{}` block only, and `MainActivity.kt`) is committed directly to the repo, so CI just builds it as-is — no regeneration, no sed patching, nothing to drift out of sync.

## Project layout

```
lib/
  main.dart                  - app entry, login/home routing
  theme/isens_theme.dart     - ISENS brand colors
  models/rfid_read_event.dart
  services/
    rfid_receiver.dart       - EventChannel listener (both scanners)
    diagnostics_service.dart - MethodChannel wrapper (getInfo/self-test)
    api_service.dart         - backend HTTP calls
    settings_service.dart    - server IP/port/auth token storage
    app_logger.dart          - in-memory app-wide log
  screens/
    login_screen.dart
    home_screen.dart         - process selection + live scan feed
    ppc_fill_screen.dart     - create Job Cards against an InSquare
    rfid_log_screen.dart     - Diagnostics / Raw RFID Scans / App Log tabs
    settings_screen.dart
android/
  app/src/main/kotlin/com/isens/rfidscanner/MainActivity.kt
  app/build.gradle.kts       - namespace/applicationId fix baked in
.github/workflows/build_apk.yml
```

## Adding your real logo/icon later

Drop files at `assets/images/isens_logo.png` and `assets/icon/app_icon.png`, then:
1. Uncomment the `assets:` block in `pubspec.yaml`.
2. Uncomment `image_path` under `flutter_launcher_icons:` in `pubspec.yaml`.
3. Run `dart run flutter_launcher_icons` (or add that as a CI step before `flutter build apk`).
4. Reference the logo image in `login_screen.dart`/`home_screen.dart` in place of the current placeholder box.

## Backend API assumptions

`api_service.dart` calls `/api/auth/login`, `/api/processes`, `/api/insquares`, `/api/job-cards`, `/api/scan`, `/api/health`. If your backend's actual route names differ, adjust the paths in that one file.
