import 'package:nitro/nitro.dart';

part 'nitro_torch.g.dart';

@NitroModule(
  ios: NativeImpl.swift,
  android: NativeImpl.kotlin,
  macos: NativeImpl.swift,
  windows: NativeImpl.cpp,
  linux: NativeImpl.cpp,
)
/// A Hybrid Object that provides access to the device's flashlight/torch.
abstract class NitroTorch extends HybridObject {
  /// The singleton instance of [NitroTorch].
  static final NitroTorch instance = _NitroTorchImpl();

  /// Turns the device's torch on.
  void turnOn();

  /// Turns the device's torch off.
  void turnOff();

  /// Returns `true` if the torch is currently on, `false` otherwise.
  bool getStatus();

  /// Toggles the torch state between on and off.
  void toggle();

  /// Sets the torch to a specific brightness [level].
  void setLevel(int level);

  /// A stream that emits the current [TorchLevel] when it changes.
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TorchLevel> onLevelChanged();

  /// A stream that emits the current [TorchState] when it changes.
  @NitroStream(backpressure: Backpressure.dropLatest)
  Stream<TorchState> onTorchStateChanged();

  /// Returns the maximum brightness level supported by the device's torch, or null if not applicable.
  int? maxLevel();
}

/// Represents the state of the torch.
@HybridEnum()
enum TorchState {
  /// The torch is on.
  on,

  /// The torch is off.
  off,
}

/// Represents the brightness level of the torch.
@HybridStruct()
class TorchLevel {
  /// The current brightness level.
  final int level;

  /// The maximum brightness level supported by the device.
  final int maxLevel;

  /// Creates a new [TorchLevel] instance.
  TorchLevel({required this.level, required this.maxLevel});
}
