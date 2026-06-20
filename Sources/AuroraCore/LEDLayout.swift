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
}
