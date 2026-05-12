import Flutter
import UIKit

public class SwiftNitroTorchPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroTorchRegistry.register(NitroTorchImpl())
    }
}
