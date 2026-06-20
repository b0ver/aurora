import Foundation

/// Decodes a vendor `controler_config/SK****.json` file into an `LEDLayout`.
///
/// The vendor configs (mirrored under `docs/reference/controller-configs/`) use
/// either `ledMap` or `key_array` for the LED grid positions, plus `key_num`,
/// `screenWidth`/`screenHeight` (or `key_wid`) metadata.
public struct ControllerConfig: Decodable {
    struct LED: Decodable {
        let id: Int
        let x: Int
        let y: Int
    }

    let ledMap: [LED]?
    let key_array: [LED]?
    let key_num: Int?
    let screenWidth: Int?
    let screenHeight: Int?
    let key_wid: Int?

    public func toLayout() -> LEDLayout {
        let leds = ledMap ?? key_array ?? []
        let points = leds.map { LEDLayout.Point(id: $0.id, x: $0.x, y: $0.y) }
        let count = key_num ?? points.count
        // Derive extents from the points when available — the vendor
        // screenWidth/Height fields are unreliable across configs.
        let width = points.map(\.x).max().map { $0 + 1 } ?? screenWidth ?? key_wid ?? max(points.count, 1)
        let height = points.map(\.y).max().map { $0 + 1 } ?? screenHeight ?? 1
        return LEDLayout(count: count, points: points, screenWidth: width, screenHeight: height)
    }

    public static func load(contentsOf url: URL) throws -> LEDLayout {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(ControllerConfig.self, from: data)
        return config.toLayout()
    }
}
