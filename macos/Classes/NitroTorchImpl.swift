import Foundation

/// Native implementation of HybridNitroTorchProtocol on macOS.
public class NitroTorchImpl: NSObject, HybridNitroTorchProtocol {

    public func add(a: Double, b: Double) -> Double {
        return a + b
    }

    public func getGreeting(name: String) async throws -> String {
        return "Hello, \(name) from macOS!"
    }
}
