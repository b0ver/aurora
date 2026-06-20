import Foundation

/// Which way the physical LED strip was mounted around the screen. Two
/// independent axes, mirroring the vendor firmware's two flip flags
/// (`installDirection` = horizontal, `installDirectionTopDown` = vertical, both
/// implemented as `cv::flip`). Used to remap the canonical ledMap
/// (LED index → screen position) BEFORE screen-sync sampling. The serial frame
/// stays strictly index-ordered and is never touched by this.
public struct InstallationMethod: Sendable, Equatable, Codable, Hashable {

    /// Horizontal winding. `.leftToRight` is firmware-native (no flip);
    /// `.rightToLeft` mirrors x.
    public enum Horizontal: String, CaseIterable, Codable, Sendable {
        case leftToRight
        case rightToLeft

        public var title: String {
            switch self {
            case .leftToRight: return "Left to right"
            case .rightToLeft: return "Right to left"
            }
        }
    }

    /// Vertical winding. `.bottomToTop` is firmware-native (no flip);
    /// `.topToBottom` mirrors y.
    public enum Vertical: String, CaseIterable, Codable, Sendable {
        case bottomToTop
        case topToBottom

        public var title: String {
            switch self {
            case .bottomToTop: return "From bottom to top"
            case .topToBottom: return "From top to bottom"
            }
        }
    }

    public var horizontal: Horizontal
    public var vertical: Vertical

    public init(horizontal: Horizontal = .rightToLeft, vertical: Vertical = .topToBottom) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    /// Project default = the owner's real, hardware-confirmed setting.
    public static let `default` = InstallationMethod(horizontal: .rightToLeft, vertical: .topToBottom)
}
