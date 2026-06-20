/// Which region of the screen drives the LEDs (parity with the vendor's
/// Full / Cinema / Top / Bottom / Left / Right sub-modes).
public enum ScreenSyncSubMode: String, CaseIterable, Codable, Sendable {
    case full
    case cinema
    case topHalf
    case bottomHalf
    case leftHalf
    case rightHalf

    public var title: String {
        switch self {
        case .full: return "Full"
        case .cinema: return "Cinema"
        case .topHalf: return "Top"
        case .bottomHalf: return "Bottom"
        case .leftHalf: return "Left"
        case .rightHalf: return "Right"
        }
    }

    public var symbol: String {
        switch self {
        case .full: return "rectangle"
        case .cinema: return "film"
        case .topHalf: return "rectangle.tophalf.filled"
        case .bottomHalf: return "rectangle.bottomhalf.filled"
        case .leftHalf: return "rectangle.lefthalf.filled"
        case .rightHalf: return "rectangle.righthalf.filled"
        }
    }

    /// Source rectangle within the captured frame as fractions (x0, y0, x1, y1).
    public var sourceRect: (x0: Double, y0: Double, x1: Double, y1: Double) {
        switch self {
        case .full:       return (0, 0, 1, 1)
        case .cinema:     return (0, 0.12, 1, 0.88)   // skip letterbox bars
        case .topHalf:    return (0, 0, 1, 0.5)
        case .bottomHalf: return (0, 0.5, 1, 1)
        case .leftHalf:   return (0, 0, 0.5, 1)
        case .rightHalf:  return (0.5, 0, 1, 1)
        }
    }
}
