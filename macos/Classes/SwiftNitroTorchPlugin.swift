import FlutterMacOS
import AppKit

public class SwiftNitroTorchPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NitroTorchRegistry.register(NitroTorchImpl())
    }
}
