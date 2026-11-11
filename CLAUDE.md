# Levelr (package: levelr / com.itsash.levelr)

Measuring toolbox for Android: bubble level, angle (inclinometer), ruler, sound
meter and compass. `UiShell` bottom navigation with one tool per tab; only the
open tab is built, so only its sensor runs. The window keeps the screen on
(`FLAG_KEEP_SCREEN_ON`) while `HomeScreen` is alive.

## Code layout

- `lib/core/`: pure functions, all unit tested (`test/`). Add a test for every
  change.
  - `angles.dart`: gravity frame is x right, y up the screen, z out of the
    screen. `flatTilt` (2 axes), `edgeTilt` (1 axis, user-right-up positive),
    `classifyMode` (flat/edge with dead band), `inclineAngle` (0..360, clockwise,
    null when flat), `LowPassFilter`, `smoothAngle` (circular), `normalize180/360`.
  - `sound_math.dart`: `rmsToDbfs`, `dbfsToSpl` (assumes 0 dBFS = 90 dB SPL plus
    the user offset), `LoudnessBand`, `SoundStats`, `RollingWindow`.
  - `ruler_math.dart`: `logicalPxPerMm(dpi, devicePixelRatio, correction)`,
    `calibratedCorrection` (card = 85.60 mm).
- `lib/platform/device_channel.dart`: `DeviceChannel` wraps
  `com.itsash.levelr/device` (method: `displayMetrics`, `keepScreenOn`) and event
  channels `/gravity` (`[x,y,z]`), `/heading` (`[azimuth, accuracy]`), `/mic`
  (RMS 0..1). Native errors become `SensorUnavailable`.
- `lib/settings/settings_store.dart`: `ChangeNotifier` over
  `shared_preferences` (units, haptics, level offsets, ruler correction, sound
  offset, `resetCalibrations`).
- `lib/widgets/`: `LiveStream` (subscribes while visible, releases the sensor
  when the app is paused, shows a "sensor not available" state), CustomPainters
  (`level_painters`, `dial_painters`, `ruler_painter`; colors from
  `context.colors`), `sound_offset_sheet`.
- `lib/screens/`: `home_screen` (shell + settings icon), `level_screen`,
  `angle_screen`, `ruler_screen`, `sound_screen` (permission_handler for the
  microphone), `compass_screen`, `settings_screen` (ends with
  `UiUpdateSection(storeId: 'levelr')` then `UiDeveloperSection()`).
- `android/app/src/main/kotlin/com/itsash/levelr/`: `MainActivity.kt`,
  `SensorStreams.kt` (gravity falls back to the accelerometer; heading remaps
  the rotation matrix when the phone is upright), `MicStreamHandler.kt`
  (`AudioRecord`, 44.1 kHz, 125 ms RMS windows; the dB conversion is in Dart).

## Commands

- `make run`, `make build` (release APK), `make test` (`flutter analyze` +
  `flutter test`), `make clean`.
- Icon: SVG sources in `assets/icon/` (`logo`, `logo_foreground`,
  `logo_background`) → `rsvg-convert -w 1024 -h 1024` to `*-1024.png`, then
  `dart run flutter_launcher_icons`.

## Conventions

- minSdk 26. UI only from the shared `theme` package (`../theme`, read
  `../theme/COMPONENTS.md`); no hardcoded colors.
- Permissions: `INTERNET` (update check only), `RECORD_AUDIO` (sound meter,
  requested when the Sound tab opens). No analytics, nothing is recorded or sent.
- Sensors and microphone are optional (`uses-feature required=false`); a missing
  one shows an empty state in that tool only.
- Sound levels are uncalibrated estimates; keep that note in the UI.

## Release (Ash Store)

- `store.json` (id `levelr`, repo its-ash/levelr), `store.mk`,
  `index.html` + `CNAME` (`levelr.itsash.in`). See
  `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version → build → commit, tag `vX.Y.Z`, push → GitHub
  release with `levelr.apk` → topics, homepage, Pages. Never create releases,
  tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
