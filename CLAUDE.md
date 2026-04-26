# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

xpad is a Flutter app with native C code linked via Dart FFI. It uses the `hooks` + `native_toolchain_c` packages to compile C sources at build time, and `ffigen` to generate Dart FFI bindings from C headers.

## Architecture

### Native (C → FFI)

- **`native/header/xpad.h`** — C header declaring the native API
- **`native/src/xpad.c`** — C implementation
- **`lib/xpad.g.dart`** — Auto-generated FFI bindings (do not edit manually)
- **`tool/ffigen.dart`** — Script that runs ffigen to regenerate `lib/xpad.g.dart` from the C header
- **`hook/build.dart`** — Build hook that compiles C sources using `native_toolchain_c`'s `CBuilder`

The flow: C code in `native/` → ffigen generates `lib/xpad.g.dart` → Dart code in `lib/` calls native functions via FFI → `hook/build.dart` compiles the C at build time.

### Dart services

- **`lib/core/result.dart`** — Sealed `Result<T>` type (`Success`/`Failure`) and `AppError` used by all services
- **`lib/services/weather/weather_service.dart`** — Public `WeatherService` (caching, re-exports models+result)
- **`lib/services/weather/weather_api.dart`** — HTTP layer for Open-Meteo API
- **`lib/services/weather/weather_models.dart`** — `WeatherData` and `WeatherCondition` enum

Pattern for new services: create `lib/services/<name>/` with `_service.dart` (public API), `_api.dart` (HTTP), `_models.dart` (data classes). Reuse `Result` and `AppError` from `lib/core/`.

## Key Commands

```bash
# Regenerate FFI bindings after changing C headers
dart run tool/ffigen.dart

# Run the app (compiles C via hook/build.dart automatically)
flutter run

# Analyze Dart code
flutter analyze

# Run tests
flutter test
```

## Important Notes

- After modifying `native/header/xpad.h`, always regenerate bindings with `dart run tool/ffigen.dart`
- `hook/build.dart` auto-discovers all `.c` files in `native/src/` — just add new files there
- The build hook sources path must be relative to the package root (not absolute `/native/src`)
