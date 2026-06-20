import Foundation

/// The physical arrangement of LEDs on a controller: how many, and where each
/// sits on the screen-edge grid (used by screen sync to map zones → LEDs).
public struct LEDLayout: Sendable, Equatable {
    public struct Point: Sendable, Equatable {
        public let id: Int
        public let x: Int
        public let y: Int
        public init(id: Int, x: Int, y: Int) {
            self.id = id
            self.x = x
            self.y = y
        }
    }

    public let count: Int
    public let points: [Point]
    public let screenWidth: Int
    public let screenHeight: Int

    public init(count: Int, points: [Point], screenWidth: Int, screenHeight: Int) {
        self.count = count
        self.points = points
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
    }

    /// Simple horizontal strip fallback, used until a real controller is detected.
    public static func strip(count: Int) -> LEDLayout {
        let pts = (0..<count).map { Point(id: $0 + 1, x: $0, y: 0) }
        return LEDLayout(count: count, points: pts, screenWidth: max(count, 1), screenHeight: 1)
    }

    /// Build a canonical screen-edge layout from per-side LED counts (vendor
    /// `lines`, e.g. SK0127 = [17, 31, 17]). Winds bottom-left → up the left →
    /// across the top → down the right (→ across the bottom for 4 sides), so
    /// y=0 is the top edge — matching the vendor ledMap convention.
    public static func fromLines(_ lines: [Int]) -> LEDLayout {
        var pts: [Point] = []
        var id = 1
        func add(_ x: Int, _ y: Int) { pts.append(Point(id: id, x: x, y: y)); id += 1 }

        switch lines.count {
        case 3, 4:
            let l = lines[0], t = lines[1], r = lines[2]
            let b = lines.count == 4 ? lines[3] : 0
            let w = max(max(t, b), 1)
            let h = max(max(l, r), 1)
            for i in 0..<l { add(0, h - 1 - i) }                  // left: bottom → top
            for i in 0..<t { add(min(i, w - 1), 0) }             // top: left → right
            for i in 0..<r { add(w - 1, min(i, h - 1)) }         // right: top → bottom
            for i in 0..<b { add(w - 1 - min(i, w - 1), h - 1) } // bottom: right → left
            return LEDLayout(count: l + t + r + b, points: pts, screenWidth: w, screenHeight: h)
        default:
            let n = max(lines.reduce(0, +), 1)
            for i in 0..<n { add(i, 0) }
            return LEDLayout(count: n, points: pts, screenWidth: n, screenHeight: 1)
        }
    }

    /// Remap each LED's screen position for how the strip was physically mounted.
    /// Pure axis mirror; LED `id`/index order is preserved (the serial frame is
    /// unaffected). See `InstallationMethod`.
    public func applying(_ method: InstallationMethod) -> LEDLayout {
        let w = (points.map(\.x).max() ?? 0) + 1
        let h = (points.map(\.y).max() ?? 0) + 1
        let flipX = method.horizontal == .rightToLeft
        let flipY = method.vertical == .topToBottom
        let remapped = points.map { p in
            Point(id: p.id,
                  x: flipX ? (w - 1 - p.x) : p.x,
                  y: flipY ? (h - 1 - p.y) : p.y)
        }
        return LEDLayout(count: count, points: remapped, screenWidth: screenWidth, screenHeight: screenHeight)
    }
}
