import AuroraCore

/// Turns a captured screen frame into one color per LED.
///
/// Each LED's normalized position within the (installation-corrected) layout
/// bounding box maps into the sub-mode's source region of the capture; a small
/// block around that point is averaged. LEDs are returned in index order, so the
/// result feeds the serial frame directly.
public enum EdgeSampler {
    public static func sample(
        grid: PixelGrid,
        layout: LEDLayout,
        subMode: ScreenSyncSubMode,
        saturation: Double = 1.0
    ) -> [RGB] {
        guard grid.width > 0, grid.height > 0, !layout.points.isEmpty else {
            return Array(repeating: .black, count: layout.count)
        }

        let rect = subMode.sourceRect
        let spanX = Double(max(layout.screenWidth - 1, 1))
        let spanY = Double(max(layout.screenHeight - 1, 1))
        let radius = max(1, min(grid.width, grid.height) / 24)

        return layout.points.map { p in
            let nx = Double(p.x) / spanX
            let ny = Double(p.y) / spanY
            let sx = rect.x0 + nx * (rect.x1 - rect.x0)
            let sy = rect.y0 + ny * (rect.y1 - rect.y0)
            let px = Int((sx * Double(grid.width - 1)).rounded())
            let py = Int((sy * Double(grid.height - 1)).rounded())
            let avg = averageBlock(grid, cx: px, cy: py, radius: radius)
            return saturation == 1.0 ? avg : saturated(avg, by: saturation)
        }
    }

    private static func averageBlock(_ grid: PixelGrid, cx: Int, cy: Int, radius: Int) -> RGB {
        var r = 0, g = 0, b = 0, n = 0
        for dy in -radius...radius {
            for dx in -radius...radius {
                let c = grid.at(cx + dx, cy + dy)
                r += Int(c.r); g += Int(c.g); b += Int(c.b); n += 1
            }
        }
        guard n > 0 else { return .black }
        return RGB(r: UInt8(r / n), g: UInt8(g / n), b: UInt8(b / n))
    }

    /// Boost saturation around the per-pixel luma (keeps brightness, deepens color).
    private static func saturated(_ c: RGB, by amount: Double) -> RGB {
        let luma = 0.299 * Double(c.r) + 0.587 * Double(c.g) + 0.114 * Double(c.b)
        func adjust(_ v: UInt8) -> UInt8 {
            let nv = luma + (Double(v) - luma) * amount
            return UInt8(max(0, min(255, nv.rounded())))
        }
        return RGB(r: adjust(c.r), g: adjust(c.g), b: adjust(c.b))
    }
}
