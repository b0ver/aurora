/// Audio-reactive lighting styles (parity-ish with the vendor's Music Modes 1–4).
public enum MusicMode: String, CaseIterable, Codable, Sendable {
    case spectrum   // frequency bars around the strip
    case pulse      // whole strip pulses with energy + beat, hue drifts
    case level      // VU meter: fills the strip with the loudness
    case mood       // slow color drift modulated by energy

    public var title: String {
        switch self {
        case .spectrum: return "Spectrum"
        case .pulse: return "Pulse"
        case .level: return "Level"
        case .mood: return "Mood"
        }
    }

    public var symbol: String {
        switch self {
        case .spectrum: return "waveform"
        case .pulse: return "dot.radiowaves.left.and.right"
        case .level: return "chart.bar.fill"
        case .mood: return "drop.fill"
        }
    }
}
