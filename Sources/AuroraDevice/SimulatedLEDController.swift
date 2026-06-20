import Foundation
import AuroraCore

/// Drives an on-screen virtual strip instead of hardware. Always available; used
/// for development, demos, UI tests, and as the live preview that mirrors exactly
/// what real LEDs would show.
public final class SimulatedLEDController: LEDController {
    public let layout: LEDLayout
    public private(set) var frame: [RGB]
    public private(set) var isConnected = false

    /// Called on every `render` so the UI can observe the latest frame.
    public var onRender: (([RGB]) -> Void)?

    public init(layout: LEDLayout) {
        self.layout = layout
        self.frame = Array(repeating: .black, count: layout.count)
    }

    public func connect() {
        isConnected = true
    }

    public func render(_ frame: [RGB]) {
        self.frame = frame
        onRender?(frame)
    }

    public func disconnect() {
        isConnected = false
    }
}
