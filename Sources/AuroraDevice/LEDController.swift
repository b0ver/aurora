import Foundation
import AuroraCore

/// Backend-agnostic sink for LED frames. Modes/engine depend only on this — they
/// don't care whether output goes to an on-screen preview or real copper.
/// See docs/adr/0003-device-abstraction.md.
public protocol LEDController: AnyObject {
    var layout: LEDLayout { get }
    var isConnected: Bool { get }
    func connect() throws
    func render(_ frame: [RGB])
    func disconnect()
}
