import Foundation
import AVFoundation
import Combine

/// Native implementation of HybridNitroTorchProtocol for iOS.
/// Torch control via AVCaptureDevice; intensity mapped to 10 discrete steps.
public class NitroTorchImpl: NSObject, HybridNitroTorchProtocol {

    // ── Constants ──────────────────────────────────────────────────────────────

    private static let kSteps: Int64 = 10

    // ── Stream subjects ────────────────────────────────────────────────────────

    private let stateSubject = PassthroughSubject<TorchState, Never>()
    private let levelSubject = PassthroughSubject<TorchLevel, Never>()
    private var torchObserver: AnyCancellable?

    public var onTorchStateChanged: AnyPublisher<TorchState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    public var onLevelChanged: AnyPublisher<TorchLevel, Never> {
        levelSubject.eraseToAnyPublisher()
    }

    // ── State ──────────────────────────────────────────────────────────────────

    private var currentStep: Int64 = NitroTorchImpl.kSteps  // default to max brightness
    // Cached once in init to avoid AVCaptureDevice.default(for:) from isLeaf:true FFI contexts,
    // which can deadlock when mediaserverd IPC dispatches back to the main queue.
    private var _cachedDevice: AVCaptureDevice?

    // ── Init ───────────────────────────────────────────────────────────────────

    override public init() {
        super.init()
        setupObserver()
    }

    deinit { torchObserver?.cancel() }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private var torchDevice: AVCaptureDevice? { _cachedDevice }

    /// KVO-observe isTorchActive so stream fires even when the system
    /// kills the torch (background, camera stolen by another app, etc.).
    private func setupObserver() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        _cachedDevice = device
        torchObserver = device.publisher(for: \.isTorchActive)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.stateSubject.send(active ? .on : .off)
            }
    }

    /// Locks the device, runs [block], then always unlocks.
    /// Raises NSException on lock failure or block error so the ObjC bridge
    /// can catch and forward to Dart's error slot.
    private func withDevice(_ block: (AVCaptureDevice) throws -> Void) {
        guard let device = torchDevice else {
            NSException.raise(.genericException,
                format: "NoFlashAvailable: No torch hardware found on this device",
                arguments: getVaList([]))
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            try block(device)
        } catch {
            NSException.raise(.genericException,
                format: "TorchError: %@",
                arguments: getVaList([error.localizedDescription as CVarArg]))
        }
    }

    // ── Protocol ───────────────────────────────────────────────────────────────

    public func add(a: Double, b: Double) -> Double { a + b }

    public func getGreeting(name: String) async throws -> String { "Hello, \(name)!" }

    public func getStatus() -> Bool { torchDevice?.isTorchActive ?? false }

    public func maxLevel() -> Int64? {
        return torchDevice != nil ? Self.kSteps : nil
    }

    public func turnOn() {
        withDevice { device in
            let level = Float(currentStep) / Float(Self.kSteps)
            try device.setTorchModeOn(level: level)
        }
    }

    public func turnOff() {
        withDevice { device in
            device.torchMode = .off
        }
    }

    public func toggle() {
        getStatus() ? turnOff() : turnOn()
    }

    public func setLevel(level: Int64) {
        let clamped = Swift.max(1, Swift.min(level, Self.kSteps))
        currentStep = clamped
        let floatLevel = Float(clamped) / Float(Self.kSteps)
        withDevice { device in
            if device.isTorchActive {
                try device.setTorchModeOn(level: floatLevel)
            }
        }
        levelSubject.send(TorchLevel(level: clamped, maxLevel: Self.kSteps))
    }
}
