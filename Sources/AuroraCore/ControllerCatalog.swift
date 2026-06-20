import Foundation

/// Identity of a detected Skydimo controller.
public struct ControllerInfo: Sendable, Equatable {
    public let model: String
    public let ledCount: Int
    public let lines: [Int]   // per-side LED counts (e.g. SK0127 = [17, 31, 17])

    public init(model: String, ledCount: Int, lines: [Int]) {
        self.model = model
        self.ledCount = ledCount
        self.lines = lines
    }
}

/// Embedded catalog of Skydimo controller models → LED count + per-side layout,
/// mirrored from the vendor `SKController.json` (kept in docs/reference). Embedded
/// as code so detection works in the packaged app with no resource files.
public enum ControllerCatalog {
    public static let models: [String: (leds: Int, lines: [Int])] = [
        "SK0121": (51, [13, 25, 13]),
        "SK0124": (54, [14, 26, 14]),
        "SK0127": (65, [17, 31, 17]),
        "SK0132": (77, [20, 37, 20]),
        "SK0134": (71, [15, 41, 15]),
        "SK0149": (107, [19, 69, 19]),
        "SK0201": (40, [20, 20]),
        "SK0202": (60, [30, 30]),
        "SK0204": (50, [25, 25]),
        "SK0301": (16, [16]),
        "SK0410": (290, [290]),
        "SK0801": (2, [2]),
        "SK0802": (18, [18]),
        "SK0901": (14, [14]),
        "SK0E01": (16, [16]),
        "SK0F01": (58, [58]),
        "SK0H01": (2, [2]),
        "SK0I01": (32, [32]),
        "SK0J01": (120, [120]),
        "SK0J02": (114, [114]),
        "SK0K01": (120, [120]),
        "SK0L21": (76, [13, 25, 13, 25]),
        "SK0L24": (80, [14, 26, 14, 26]),
        "SK0L27": (96, [17, 31, 17, 31]),
        "SK0L32": (114, [20, 37, 20, 37]),
        "SK0L34": (112, [15, 41, 15, 41]),
        "SK0N03": (253, [253]),
        "SKA124": (70, [70]),
        "SKA127": (81, [81]),
        "SKA132": (95, [95]),
        "SKA134": (95, [95]),
    ]

    /// Resolve a handshake reply (e.g. "SK0127,<config…>") to controller info.
    public static func info(forReply reply: String) -> ControllerInfo? {
        let model = String(reply.uppercased().drop(while: { !$0.isLetter }).prefix(6))
        guard model.hasPrefix("SK"), let entry = models[model], entry.leds > 0 else { return nil }
        return ControllerInfo(model: model, ledCount: entry.leds, lines: entry.lines)
    }
}
