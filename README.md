# nitro_torch

A Flutter plugin for controlling the device flashlight (torch) built on top of
[nitro](https://pub.dev/packages/nitro) — a zero-overhead Dart FFI bridge with
Kotlin, Swift, and C++ backends.

## Features

| Feature | Android | iOS | macOS |
|---------|---------|-----|-------|
| Turn on / off | ✅ | ✅ | ✅ (if hardware present) |
| Toggle | ✅ | ✅ | ✅ |
| Get status | ✅ | ✅ | ✅ |
| Brightness levels | ✅ API 33+ | ✅ 10 steps | ✅ (if hardware present) |
| Max level query | ✅ | ✅ | ✅ |
| State stream | ✅ | ✅ | ✅ |
| Level-change stream | ✅ API 33+ | ✅ | ✅ |

## Installation

```yaml
dependencies:
  nitro_torch: ^0.0.1
```

> **Requires** [`nitro`](https://pub.dev/packages/nitro) `^0.4.2` and `nitro_annotations: ^0.4.2`.

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera.flash" android:required="false" />
```

### iOS

Add a camera usage description to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to control the flashlight.</string>
```

### macOS

No extra configuration needed. Most Macs have no torch hardware; torch operations
raise a `NoFlashAvailable` error on those devices.

---

## Usage

```dart
import 'package:nitro_torch/nitro_torch.dart';

final torch = NitroTorch.instance;

// Basic on / off / toggle
torch.turnOn();
torch.turnOff();
torch.toggle();

// Current state
final isOn = torch.getStatus(); // bool

// Brightness levels — null when hardware does not support levels
final max = torch.maxLevel(); // int?
if (max != null && max > 1) {
  torch.setLevel(5); // 1 = dim, max = full brightness
}

// Live state stream
torch.onTorchStateChanged().listen((state) {
  print(state == TorchState.on ? 'ON' : 'OFF');
});

// Live brightness stream
torch.onLevelChanged().listen((lvl) {
  print('Level ${lvl.level} / ${lvl.maxLevel}');
});
```

---

## API Reference

### Types

#### `TorchState`

```dart
@HybridEnum()
enum TorchState { on, off }
```

Maps to `Int64` at the C boundary (`0 = on`, `1 = off`). Emitted by `onTorchStateChanged`.

---

#### `TorchLevel`

```dart
@HybridStruct()
class TorchLevel {
  final int level;     // current brightness step (1 … maxLevel)
  final int maxLevel;  // hardware maximum
  TorchLevel({required this.level, required this.maxLevel});
}
```

Passed as a packed C struct — zero-copy across the FFI boundary. Emitted by `onLevelChanged`.

---

### Methods

#### `double add(double a, double b)`

Synchronous utility method. Returns `a + b`. Useful for verifying the FFI bridge is wired correctly.

```dart
final sum = NitroTorch.instance.add(1.5, 2.5); // 4.0
```

---

#### `Future<String> getGreeting(String name)` · `@nitroAsync`

Async bridge call dispatched on a background thread. Returns a greeting string from native code. Demonstrates the `@nitroAsync` annotation.

```dart
final greeting = await NitroTorch.instance.getGreeting('World');
// "Hello, World!" (exact string is implementation-defined)
```

---

#### `void turnOn()`

Activates the device torch at its current/default brightness level. Throws if no flash hardware is present.

```dart
NitroTorch.instance.turnOn();
```

---

#### `void turnOff()`

Deactivates the device torch.

```dart
NitroTorch.instance.turnOff();
```

---

#### `bool getStatus()`

Returns `true` if the torch is currently on, `false` otherwise. Reads hardware state — not cached.

```dart
final isOn = NitroTorch.instance.getStatus();
```

---

#### `void toggle()`

Turns the torch on if it is off, or off if it is on.

```dart
NitroTorch.instance.toggle();
```

---

#### `void setLevel(int level)`

Sets brightness to `level` (1 = minimum, `maxLevel()` = maximum).

```dart
final max = NitroTorch.instance.maxLevel();
if (max != null && max > 1) {
  NitroTorch.instance.setLevel(max ~/ 2); // 50 % brightness
}
```

Throws `BrightnessControlNotSupported` on Android < API 33.

---

#### `int? maxLevel()`

Returns the number of discrete brightness levels supported by the hardware, or `null` when the device does not support brightness control.

```dart
final max = NitroTorch.instance.maxLevel();
// null  → brightness control unavailable
// 1     → on/off only
// 10    → iOS (10 steps via AVFoundation)
// N     → Android API 33+ (CameraManager.getMaxTorchStrengthLevel)
```

---

#### `Stream<TorchLevel> onLevelChanged()` · `@NitroStream`

Emits a `TorchLevel` whenever the brightness changes. Backpressure: `dropLatest` — if Dart hasn't consumed the previous event the new one is dropped.

```dart
NitroTorch.instance.onLevelChanged().listen((lvl) {
  print('Brightness: ${lvl.level} / ${lvl.maxLevel}');
});
```

---

#### `Stream<TorchState> onTorchStateChanged()` · `@NitroStream`

Emits `TorchState.on` or `TorchState.off` whenever the torch state changes, including system-level interruptions (app backgrounded, camera captured by another process, etc.). Backpressure: `dropLatest`.

```dart
NitroTorch.instance.onTorchStateChanged().listen((state) {
  print(state == TorchState.on ? 'Torch ON' : 'Torch OFF');
});
```

---

### Spec (source of truth)

```dart
// lib/src/nitro_torch.native.dart
import 'package:nitro/nitro.dart';

part 'nitro_torch.g.dart';

@HybridEnum()
enum TorchState { on, off }

@HybridStruct()
class TorchLevel {
  final int level;
  final int maxLevel;
  TorchLevel({required this.level, required this.maxLevel});
}

@NitroModule(
  ios: NativeImpl.swift,
  android: NativeImpl.kotlin,
  macos: NativeImpl.swift,
  windows: NativeImpl.cpp,
  linux: NativeImpl.cpp,
)
abstract class NitroTorch extends HybridObject {
  static final NitroTorch instance = _NitroTorchImpl();

  double add(double a, double b);

  @nitroAsync
  Future<String> getGreeting(String name);

  void turnOn();
  void turnOff();
  bool getStatus();
  void toggle();
  void setLevel(int level);

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TorchLevel> onLevelChanged();

  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TorchState> onTorchStateChanged();

  int? maxLevel();
}
```

### Native signatures

| Dart | Swift (`HybridNitroTorchProtocol`) | Kotlin (`HybridNitroTorchSpec`) |
|------|------------------------------------|---------------------------------|
| `double add(double, double)` | `func add(a: Double, b: Double) -> Double` | `fun add(a: Double, b: Double): Double` |
| `Future<String> getGreeting(String)` | `func getGreeting(name: String) async throws -> String` | `suspend fun getGreeting(name: String): String` |
| `void turnOn()` | `func turnOn() -> Void` | `fun turnOn()` |
| `void turnOff()` | `func turnOff() -> Void` | `fun turnOff()` |
| `bool getStatus()` | `func getStatus() -> Bool` | `fun getStatus(): Boolean` |
| `void toggle()` | `func toggle() -> Void` | `fun toggle()` |
| `void setLevel(int)` | `func setLevel(level: Int64) -> Void` | `fun setLevel(level: Long)` |
| `int? maxLevel()` | `func maxLevel() -> Int64?` | `fun maxLevel(): Long?` |
| `Stream<TorchLevel>` | `var onLevelChanged: AnyPublisher<TorchLevel, Never>` | `val onLevelChanged: Flow<TorchLevel>` |
| `Stream<TorchState>` | `var onTorchStateChanged: AnyPublisher<TorchState, Never>` | `val onTorchStateChanged: Flow<TorchState>` |

---

### Error handling

All operations surface native failures as Dart `Error`s. Wrap calls in `try/catch`:

```dart
try {
  torch.turnOn();
} catch (e) {
  // e.toString() contains a JSON payload:
  // {"code": "NoFlashAvailable", "message": "..."}
}
```

#### Error codes

| Code | Cause |
|------|-------|
| `NoFlashAvailable` | Device has no torch hardware |
| `CameraServiceUnavailable` | Android camera service unavailable |
| `ApiLevelTooLow` | Android API < 23 |
| `BrightnessControlNotSupported` | `setLevel` called on Android < 13 |
| `AccessFailed` | OS denied access to the camera or torch |

---

## Architecture

`nitro_torch` uses [nitro](https://pub.dev/packages/nitro) for a direct Dart ↔ native bridge with no
method-channel overhead:

```
Dart  (nitro_torch.g.dart)
   │  dart:ffi
   ▼
C++ shim  (nitro_torch.bridge.g.cpp / .mm)
   │  JNI (Android) / @_cdecl symbols (iOS/macOS)
   ▼
Kotlin / Swift implementation
```

### Android

- `NitroTorchPlugin` implements `FlutterPlugin` + `ActivityAware`, so both
  `applicationContext` and the foreground `Activity` are available to the impl.
- `NitroTorchImpl` accesses them via properties on `HybridNitroTorchSpec`
  (no Context constructor injection needed).
- `CameraManager.TorchCallback` drives both streams in real time — including
  system-level interruptions.
- Brightness control (`setLevel`) uses `turnOnTorchWithStrengthLevel` (API 33+).
  On older devices a structured `BrightnessControlNotSupported` error is thrown.

### iOS / macOS

- `NitroTorchImpl` uses `AVCaptureDevice` with `hasTorch` checks.
- 10 discrete brightness steps map onto AVFoundation's 0.0–1.0 Float range via
  `setTorchModeOn(level:)`.
- A Combine KVO observer on `isTorchActive` drives `onTorchStateChanged` in real
  time, including system-level torch interruptions (app backgrounded, camera
  captured by another app, etc.).
- On macOS, `torchDevice` returns `nil` on virtually all hardware; all mutating
  operations raise `NoFlashAvailable`. Streams are inert until hardware is available.

---

## Platform support

| Platform | Min version | Implementation |
|----------|-------------|----------------|
| Android | API 23 (Marshmallow) | Kotlin + CameraManager |
| iOS | 13.0 | Swift + AVFoundation |
| macOS | 10.15 | Swift + AVFoundation |
| Windows | — | Stub |
| Linux | — | Stub |

---

## Example

See [`example/`](example/) for a complete demo app featuring:

- Animated torch icon with amber glow effect
- Live ON/OFF badge driven by `onTorchStateChanged`
- Brightness selector: animated segment bars, `−`/`+` step buttons, drag slider
  (always visible; shows an "API 33+" badge when levels are not supported)
- Turn On / Turn Off / Toggle control buttons
- Error banner for native failures

---

## Contributing

Pull requests are welcome. For major changes please open an issue first to discuss
what you'd like to change.

---

## License

MIT License

Copyright (c) 2026 Shreeman Arjun Sahu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
