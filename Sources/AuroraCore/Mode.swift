import Foundation

/// The top-level lighting mode the user selects (from the menu bar).
public enum Mode: String, CaseIterable, Identifiable, Codable, Sendable {
    case circadian
    case screenSync
    case musicSync
    case staticColor

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .circadian: return "Circadian"
        case .screenSync: return "Screen"
        case .musicSync: return "Music"
        case .staticColor: return "Scene"
        }
    }

    /// SF Symbol used in the menu bar / UI.
    public var symbol: String {
        switch self {
        case .circadian: return "sun.max"
        case .screenSync: return "display"
        case .musicSync: return "waveform"
        case .staticColor: return "paintpalette"
        }
    }

    /// Whether this mode is wired up yet (drives "coming soon" UI states).
    public var isImplemented: Bool {
        self != .staticColor
    }
}
