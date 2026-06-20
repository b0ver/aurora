import AuroraCore

/// A small, downscaled RGB image (row-major) captured from the screen.
public struct PixelGrid: Sendable {
    public let width: Int
    public let height: Int
    public let pixels: [RGB]

    public init(width: Int, height: Int, pixels: [RGB]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    @inline(__always)
    public func at(_ x: Int, _ y: Int) -> RGB {
        let cx = min(max(x, 0), width - 1)
        let cy = min(max(y, 0), height - 1)
        return pixels[cy * width + cx]
    }
}
