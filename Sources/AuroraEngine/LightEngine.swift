import Foundation
import Combine
import AuroraCore
import AuroraDevice

/// Drives the LED output with a **continuous background render loop**.
///
/// A `DispatchSourceTimer` on a dedicated queue produces frames at a fixed FPS
/// and streams them to the controller — independent of the main run loop, so it
/// never stalls while a menu/popover is open, and the controller is always fed
/// (preventing idle-blanking). UI events only update queue-confined state; they
/// never write to the serial port directly.
///
/// Threading contract:
/// - `q*` properties are touched **only** on `renderQueue`.
/// - `@Published` properties are mutated **only** on the main thread.
/// - `controller` is used **only** on `renderQueue`.
public final class LightEngine: ObservableObject {
    @Published public private(set) var lastFrame: [RGB]
    @Published public private(set) var isRunning = false
    @Published public private(set) var isConnected = false

    public let controller: LEDController

    private let renderQueue = DispatchQueue(label: "com.evgenypopov.aurora.render", qos: .userInitiated)
    private var timer: DispatchSourceTimer?          // touched only on renderQueue
    private let interval: TimeInterval
    private let reconnectEveryTicks: Int
    private var qReconnectTicks = 0

    // Queue-confined state.
    private var providers: [Mode: @Sendable (Date, LEDLayout) -> [RGB]]
    private var qMode: Mode
    private var qBrightness: Double
    private var qPreviewTime: Date?
    private var qPaused = false
    private var qLastComputed: [RGB]
    private var qLastPublished: [RGB]

    public init(
        controller: LEDController,
        providers: [Mode: @Sendable (Date, LEDLayout) -> [RGB]],
        mode: Mode = .circadian,
        brightness: Double = 1.0,
        fps: Double = 30
    ) {
        self.controller = controller
        self.providers = providers
        self.qMode = mode
        self.qBrightness = brightness
        self.interval = 1.0 / max(fps, 1)
        self.reconnectEveryTicks = max(Int(fps), 1)   // retry a dropped connection ~1×/s
        let blank = Array(repeating: RGB.black, count: controller.layout.count)
        self.lastFrame = blank
        self.qLastComputed = blank
        self.qLastPublished = blank
    }

    public func start() {
        setPublished { self.isRunning = true }
        // Everything touching `timer`/`controller` is confined to renderQueue
        // (serial), so the lifecycle is race-free and the guard is atomic.
        renderQueue.async {
            guard self.timer == nil else { return }
            _ = try? self.controller.connect()
            let connected = self.controller.isConnected
            self.setPublished { self.isConnected = connected }

            let t = DispatchSource.makeTimerSource(queue: self.renderQueue)
            t.schedule(deadline: .now(), repeating: self.interval, leeway: .milliseconds(4))
            t.setEventHandler { [weak self] in self?.renderTick() }
            self.timer = t
            t.resume()
        }
    }

    /// Fully stop the loop (app teardown). For user "pause", use `setPaused`.
    public func stop() {
        setPublished { self.isRunning = false }
        renderQueue.async {
            self.timer?.cancel()
            self.timer = nil
            self.controller.disconnect()
        }
    }

    // MARK: Intents (called on main, applied on renderQueue)

    public func setMode(_ mode: Mode) { renderQueue.async { self.qMode = mode } }
    public func setBrightness(_ b: Double) { renderQueue.async { self.qBrightness = b } }
    public func setPreviewTime(_ d: Date?) { renderQueue.async { self.qPreviewTime = d } }

    public func setProvider(_ provider: @escaping @Sendable (Date, LEDLayout) -> [RGB], for mode: Mode) {
        renderQueue.async { self.providers[mode] = provider }
    }

    /// Pause = freeze on the current frame but keep streaming it (so the strip
    /// holds instead of idle-blanking). Resume re-enables live computation.
    public func setPaused(_ paused: Bool) {
        setPublished { self.isRunning = !paused }
        renderQueue.async { self.qPaused = paused }
    }

    // MARK: Render loop (runs on renderQueue)

    private func renderTick() {
        // If the hardware isn't connected (e.g. the port was busy at launch),
        // retry ~once per second so the strip recovers instead of staying dark.
        if !controller.isConnected {
            qReconnectTicks += 1
            if qReconnectTicks >= reconnectEveryTicks {
                qReconnectTicks = 0
                _ = try? controller.connect()
                let connected = controller.isConnected
                setPublished { self.isConnected = connected }
            }
        }

        // Note: qLastComputed starts all-black, so pausing or selecting a
        // provider-less mode before the first live tick holds black until then.
        let frame: [RGB]
        if qPaused {
            frame = qLastComputed
        } else if let provider = providers[qMode] {
            let now = qPreviewTime ?? Date()
            let raw = provider(now, controller.layout)
            let b = qBrightness
            frame = b >= 1.0 ? raw : raw.map { $0.scaled(by: b) }
            qLastComputed = frame
        } else {
            frame = qLastComputed
        }

        controller.render(frame)

        // Only republish to the UI when the frame actually changes — avoids
        // 30 redundant main-thread updates per second for slow modes.
        if frame != qLastPublished {
            qLastPublished = frame
            setPublished { self.lastFrame = frame }
        }
    }

    private func setPublished(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
