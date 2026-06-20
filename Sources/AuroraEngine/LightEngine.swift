import Foundation
import Combine
import AuroraCore
import AuroraDevice
import AuroraCircadian

/// Orchestrates the render loop: on each tick it asks the active mode for a
/// frame, applies master brightness, publishes it for the UI preview, and pushes
/// it to the controller.
///
/// M0 runs the loop on the main run loop at a low rate (circadian only needs a
/// few fps). High-rate sources (screen/audio) will move to a dedicated queue with
/// proper actor isolation in M3/M4.
@MainActor
public final class LightEngine: ObservableObject {
    @Published public var activeMode: Mode = .circadian
    @Published public var masterBrightness: Double = 1.0
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var lastFrame: [RGB]

    public let controller: LEDController
    private var sources: [Mode: ModeSource]
    private var timer: Timer?
    private let tickInterval: TimeInterval

    public init(
        controller: LEDController,
        sources: [Mode: ModeSource],
        tickInterval: TimeInterval = 1.0
    ) {
        self.controller = controller
        self.sources = sources
        self.tickInterval = tickInterval
        self.lastFrame = Array(repeating: .black, count: controller.layout.count)
    }

    public func start() {
        guard !isRunning else { return }
        try? controller.connect()
        isRunning = true
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    public func setMode(_ mode: Mode) {
        activeMode = mode
        tick()
    }

    /// Replace or install a mode source (e.g. when settings change).
    public func setSource(_ source: ModeSource, for mode: Mode) {
        sources[mode] = source
        if mode == activeMode { tick() }
    }

    private func tick() {
        guard let source = sources[activeMode] else { return }
        let raw = source.frame(at: Date(), layout: controller.layout)
        let frame = masterBrightness >= 1.0 ? raw : raw.map { $0.scaled(by: masterBrightness) }
        lastFrame = frame
        controller.render(frame)
    }
}
