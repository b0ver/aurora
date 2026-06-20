import Foundation
import Combine
import AuroraCore

/// Owns the screen capturer and the latest sampled frame. The render loop pulls
/// `currentFrame()`; the capturer pushes new frames in via `ingest`. All shared
/// state is lock-protected; `status` is published on the main thread for the UI.
public final class ScreenSyncController: ObservableObject, @unchecked Sendable {
    public enum Status: Equatable, Sendable {
        case idle
        case starting
        case capturing
        case needsPermission
        case failed(String)
    }

    @Published public private(set) var status: Status = .idle

    private let lock = NSLock()
    private var _layout: LEDLayout
    private var _subMode: ScreenSyncSubMode
    private var _saturation: Double
    private var _latest: [RGB]
    private let capturer = ScreenCapturer()
    private var lifecycleTask: Task<Void, Never>?

    public init(spatialLayout: LEDLayout, subMode: ScreenSyncSubMode = .full, saturation: Double = 1.15) {
        _layout = spatialLayout
        _subMode = subMode
        _saturation = saturation
        _latest = Array(repeating: .black, count: spatialLayout.count)
        capturer.onGrid = { [weak self] grid in self?.ingest(grid) }
    }

    // MARK: Settings (main thread)

    public var subMode: ScreenSyncSubMode {
        get { lock.lock(); defer { lock.unlock() }; return _subMode }
        set { lock.lock(); _subMode = newValue; lock.unlock() }
    }

    public var saturation: Double {
        get { lock.lock(); defer { lock.unlock() }; return _saturation }
        set { lock.lock(); _saturation = newValue; lock.unlock() }
    }

    public func updateLayout(_ layout: LEDLayout) {
        lock.lock()
        _layout = layout
        if _latest.count != layout.count {
            _latest = Array(repeating: .black, count: layout.count)
        }
        lock.unlock()
    }

    // MARK: Lifecycle

    /// Lifecycle ops are chained (each awaits the previous) so a rapid
    /// start→stop→start can't reorder and leak the capture stream.
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
                self.setStatus(ScreenCapturer.isPermissionError(error) ? .needsPermission
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

    // MARK: Frame access (render queue)

    public func currentFrame() -> [RGB] {
        lock.lock(); defer { lock.unlock() }
        return _latest
    }

    // MARK: Private

    private func ingest(_ grid: PixelGrid) {
        lock.lock()
        let layout = _layout
        let mode = _subMode
        let sat = _saturation
        lock.unlock()

        let sampled = EdgeSampler.sample(grid: grid, layout: layout, subMode: mode, saturation: sat)

        lock.lock()
        if sampled.count == _latest.count { _latest = sampled }
        lock.unlock()
    }

    private func setStatus(_ s: Status) {
        if Thread.isMainThread { status = s }
        else { DispatchQueue.main.async { self.status = s } }
    }
}
