# Levelr

Bubble level, angle, ruler, sound meter and compass in one app.

**[Website](https://levelr.itsash.in)** · **[Download APK](https://github.com/its-ash/levelr/releases/latest/download/levelr.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Level**: a two-axis bullseye bubble when the phone lies flat, a one-axis
  tube level when it stands on an edge. Smoothed readings, a haptic tick at
  ±0.1°, hold the value, and per-axis calibration on a surface you trust.
- **Angle**: the tilt of the phone's edge from 0 to 360°, with a relative mode:
  tap to set zero and read the difference.
- **Ruler**: centimetres and inches at true scale from the screen's real DPI,
  draggable markers, and a bank card calibration (85.60 mm) that is saved.
- **Sound meter**: approximate dB from the microphone with current, min, max and
  average, a live chart, an everyday loudness scale and an offset to match a
  reference meter. Nothing is recorded.
- **Compass**: heading from the rotation vector sensor with a "needs
  calibration" hint.
- The screen stays on while Levelr is open, and the level, angle and compass
  tools work in landscape.
- **Private**: no accounts, no ads. The only network call is the update check
  in Settings.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Levelr from it.
- **APK**: download the [latest APK](https://github.com/its-ash/levelr/releases/latest/download/levelr.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or later. A phone without a compass or
microphone still runs the other tools.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make test     # flutter analyze + flutter test
make build    # release APK
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `levelr.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                    # UiApp + HomeScreen
├── core/                        # pure, tested math
│   ├── angles.dart              # tilt, incline, low-pass filter, heading smoothing
│   ├── sound_math.dart          # RMS → dBFS → dB SPL, loudness bands, stats
│   └── ruler_math.dart          # DPI → px per mm, card calibration
├── platform/device_channel.dart # MethodChannel + EventChannels to Kotlin
├── settings/settings_store.dart # units, haptics, calibrations (shared_preferences)
├── widgets/                     # LiveStream, painters, sound offset sheet
└── screens/                     # home (UiShell), level, angle, ruler, sound, compass, settings
android/app/src/main/kotlin/com/itsash/levelr/
├── MainActivity.kt              # channels, DisplayMetrics, keep screen on
├── SensorStreams.kt             # gravity and rotation-vector streams
└── MicStreamHandler.kt          # AudioRecord RMS stream
```

See `CLAUDE.md` for details.

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
