import Foundation
import Combine
import AuroraCore

/// Owns system-audio capture and turns it into LED frames. The render loop pulls
/// `currentFrame(_:)` (computes the FFT + renders the active mode); the capturer
/// pushes samples into a ring buffer. Shared state is lock-protected; per-frame
/// render state is only touched from the render queue (single-threaded).
public final class MusicSyncController: ObservableObject, @unchecked Sendable {
    public enum Status: Equatable, Sendable {
        case idle, starting, capturing, needsPermission, failed(String)
    }

    @Published public private(set) var status: Status = .idle

    private let fftSize = 1024
    private let bandCount = 24
    private let analyzer = SpectrumAnalyzer(size: 1024)
    private let capturer = AudioCapturer()
    private var lifecycleTask: Task<Void, Never>?

    private let lock = NSLock()
    private var ring: [Float]
    private var _mode: MusicMode
    private var _sensitivity: Double
    private var _layout: LEDLayout   // install-corrected spatial layout

    // Render-queue-only state.
    private var smoothed: [Float]
    private var huePhase: Double = 0
    private var slowEnergy: Float = 0
    private var beatEnv: Double = 0

    public init(spatialLayout: LEDLayout, mode: MusicMode = .spectrum, sensitivity: Double = 1.0) {
        ring = [Float](repeating: 0, count: fftSize)
        smoothed = [Float](repeating: 0, count: bandCount)
        _mode = mode
        _sensitivity = sensitivity
        _layout = spatialLayout
        capturer.onSamples = { [weak self] s in self?.ingest(s) }
    }

    public var mode: MusicMode {
        get { lock.lock(); defer { lock.unlock() }; return _mode }
        set { lock.lock(); _mode = newValue; lock.unlock() }
    }

    public var sensitivity: Double {
        get { lock.lock(); defer { lock.unlock() }; return _sensitivity }
        set { lock.lock(); _sensitivity = newValue; lock.unlock() }
    }

    /// Update the spatial layout (e.g. when the installation direction changes).
    public func updateLayout(_ layout: LEDLayout) {
        lock.lock(); _layout = layout; lock.unlock()
    }

    // MARK: Lifecycle

    /// Chained lifecycle (each op awaits the previous) so rapid start/stop can't
    /// reorder and leak the audio stream.
    public func start() {
        setStatus(.starting)
        let prev = lifecycleTask
        lifecycleTask = Task { [weak self] in
            await prev?.value
            guard let self else { return }
            do {
                try await self.capturer.start()
                self.setStatus(.capturing)
            } catch {
                self.setStatus(AudioCapturer.isPermissionError(error) ? .needsPermission
                                                                       : .failed(error.localizedDescription))
            }
        }
    }

    public func stop() {
        let prev = lifecycleTask
        lifecycleTask = Task { [weak self] in
            await prev?.value
            await self?.capturer.stop()
            self?.setStatus(.idle)
        }
    }

    // MARK: Frame (render queue)

    public func currentFrame() -> [RGB] {
        lock.lock()
        let samples = ring
        let mode = _mode
        let gain = Float(_sensitivity)
        let layout = _layout
        lock.unlock()

        let mags = analyzer.magnitudes(samples)
        let raw = analyzer.bands(mags, count: bandCount)

        // Scale to ~0...1, fast attack / slow decay for a lively but stable look.
        for i in 0..<bandCount {
            let v = min(1, raw[i] * gain * 45)
            smoothed[i] = max(v, smoothed[i] * 0.80)
        }

        let energy = smoothed.reduce(0, +) / Float(bandCount)
        slowEnergy = slowEnergy * 0.95 + energy * 0.05
        let isBeat = energy > slowEnergy * 1.35 && energy > 0.06
        beatEnv = max(beatEnv * 0.86, isBeat ? 1 : 0)

        return renderFrame(mode: mode, layout: layout, energy: Double(energy))
    }

    /// Diagnostic: current average band energy (0...1).
    public func currentEnergy() -> Double {
        Double(smoothed.reduce(0, +) / Float(max(bandCount, 1)))
    }

    // MARK: Rendering

    private func renderFrame(mode: MusicMode, layout: LEDLayout, energy: Double) -> [RGB] {
        let pts = layout.points
        let count = pts.count
        guard count > 0 else { return [] }
        let maxX = Double(max(layout.screenWidth - 1, 1))
        let maxY = Double(max(layout.screenHeight - 1, 1))

        switch mode {
        case .spectrum:
            // Map by horizontal position: bass on the left → treble on the right.
            return pts.map { p in
                let nx = Double(p.x) / maxX
                let band = min(bandCount - 1, max(0, Int(nx * Double(bandCount))))
                let mag = Double(smoothed[band])
                return RGB.hsv(nx * 0.8, 1, min(1, mag))
            }

        case .pulse:
            huePhase += 0.0015 + beatEnv * 0.04
            let v = min(1, energy * 1.4 + beatEnv * 0.5)
            return Array(repeating: RGB.hsv(huePhase, 1, v), count: count)

        case .level:
            // VU meter that rises from the bottom of the screen to the top.
            let level = min(1, energy * 1.6)
            return pts.map { p in
                let fromBottom = 1.0 - Double(p.y) / maxY   // 0 at bottom (y=max), 1 at top
                guard fromBottom <= level else { return .black }
                let hue = 0.33 * (1 - fromBottom)           // green low → red near the top
                return RGB.hsv(hue, 1, 1)
            }

        case .mood:
            huePhase += 0.0008 + energy * 0.01
            let sat = 0.55 + 0.45 * min(1, energy * 2)
            let v = 0.35 + 0.65 * min(1, energy * 1.6)
            return Array(repeating: RGB.hsv(huePhase, sat, v), count: count)
        }
    }

    // MARK: Private

    private func ingest(_ s: [Float]) {
        guard !s.isEmpty else { return }
        lock.lock()
        let count = min(s.count, fftSize)
        if count >= fftSize {
            ring = Array(s.suffix(fftSize))
        } else {
            ring.removeFirst(count)
            ring.append(contentsOf: s.suffix(count))
        }
        lock.unlock()
    }

    private func setStatus(_ s: Status) {
        if Thread.isMainThread { status = s }
        else { DispatchQueue.main.async { self.status = s } }
    }
}
