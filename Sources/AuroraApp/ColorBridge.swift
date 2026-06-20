import SwiftUI
import AppKit
import AuroraCore

extension Color {
    /// Convert to Aurora's RGB via the sRGB color space.
    func toRGB() -> RGB {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        func u(_ d: CGFloat) -> UInt8 { UInt8(max(0, min(255, (d * 255).rounded()))) }
        return RGB(r: u(ns.redComponent), g: u(ns.greenComponent), b: u(ns.blueComponent))
    }
}
