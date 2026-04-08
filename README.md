# Lexaway

A language learning adventure game built with Flutter and Flame. Answer questions, walk a tiny dino across pixel-art landscapes.

## Running

```bash
flutter run
```

## Testing

```bash
# Unit / widget tests
flutter test

# Integration tests (single device)
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart
```

## App Store Screenshots

Full pipeline — captures raw screenshots across multiple iOS simulators, then composites marketing assets with dithered scrims and captions:

```bash
./tools/screenshots.sh
```

Useful flags for iteration:

```bash
# Capture only (skip compose step)
./tools/screenshots.sh --capture-only

# Compose only (re-process existing raw screenshots)
./tools/screenshots.sh --compose-only

# Single device
./tools/screenshots.sh --device iPhone_16_Plus

# Combine flags
./tools/screenshots.sh --device iPhone_16_Plus --capture-only
```

Device list, captions, and style are configured in `tools/screenshot_config.yaml`.

Output lands in `screenshots/raw/` (captures) and `screenshots/final/` (composed).

## Native Splash Screen

Regenerate after changing the config in `pubspec.yaml`:

```bash
dart run flutter_native_splash:create
```
