import 'package:nitro/nitro.dart';

part 'nitro_torch.g.dart';

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

@HybridEnum()
enum TorchState { on, off }

@HybridStruct()
class TorchLevel {
  final int level;
  final int maxLevel;
  TorchLevel({required this.level, required this.maxLevel});
}
