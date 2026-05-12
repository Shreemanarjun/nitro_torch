import 'package:nitro/nitro.dart';

part 'nitro_torch.g.dart';

@NitroModule(ios: NativeImpl.swift, android: NativeImpl.kotlin, macos: NativeImpl.swift, windows: NativeImpl.cpp, linux: NativeImpl.cpp)
abstract class NitroTorch extends HybridObject {
  static final NitroTorch instance = _NitroTorchImpl();

  double add(double a, double b);

  @nitroAsync
  Future<String> getGreeting(String name);
}
