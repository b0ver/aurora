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

    /// Build from HSV (each 0...1). Used by audio-reactive modes.
    public static func hsv(_ h: Double, _ s: Double, _ v: Double) -> RGB {
        let h6 = (h.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let c = v * s
        let x = c * (1 - abs(h6.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch Int(h6) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        func u(_ d: Double) -> UInt8 { UInt8(max(0, min(255, ((d + m) * 255).rounded()))) }
        return RGB(r: u(r), g: u(g), b: u(b))
    }

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

    /// Per-channel gamma correction `out = (in/255)^gamma`. Compensates for the
    /// LED's response (WS2812 green is very bright), so warm colors read as true
    /// orange/amber instead of yellow. Apply to the full-intensity hue *before*
    /// brightness scaling.
    public func gammaCorrected(_ gamma: Double) -> RGB {
        guard gamma > 0, gamma != 1 else { return self }
        func f(_ v: UInt8) -> UInt8 {
            UInt8((pow(Double(v) / 255, gamma) * 255).rounded())
        }
        return RGB(r: f(r), g: f(g), b: f(b))
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
