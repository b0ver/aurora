import Foundation

/// An 8-bit-per-channel RGB color — the unit of everything Aurora pushes to LEDs.
public struct RGB: Equatable, Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = RGB(r: 0, g: 0, b: 0)
    public static let white = RGB(r: 255, g: 255, b: 255)

    /// Scale brightness by `factor` (0...1). Linear in 8-bit space (gamma handled
    /// separately in the frame pipeline).
    public func scaled(by factor: Double) -> RGB {
        let f = max(0, min(1, factor))
        return RGB(
            r: UInt8((Double(r) * f).rounded()),
            g: UInt8((Double(g) * f).rounded()),
            b: UInt8((Double(b) * f).rounded())
        )
    }

    /// Linear blend toward `other` by `t` (0...1).
    public func blended(to other: RGB, t: Double) -> RGB {
        let t = max(0, min(1, t))
        func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
            UInt8((Double(a) * (1 - t) + Double(b) * t).rounded())
        }
        return RGB(r: mix(r, other.r), g: mix(g, other.g), b: mix(b, other.b))
    }
}
