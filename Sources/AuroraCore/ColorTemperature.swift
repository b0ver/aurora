import Foundation

/// Converts a correlated color temperature (Kelvin) to an approximate sRGB color.
///
/// Uses Tanner Helland's widely-used approximation, valid ~1000K–40000K. Good
/// enough for ambient lighting and the circadian schedule.
public enum ColorTemperature {
    public static func rgb(kelvin: Double) -> RGB {
        let temp = max(1000, min(40000, kelvin)) / 100

        let r: Double
        if temp <= 66 {
            r = 255
        } else {
            r = 329.698727446 * pow(temp - 60, -0.1332047592)
        }

        let g: Double
        if temp <= 66 {
            g = 99.4708025861 * log(temp) - 161.1195681661
        } else {
            g = 288.1221695283 * pow(temp - 60, -0.0755148492)
        }

        let b: Double
        if temp >= 66 {
            b = 255
        } else if temp <= 19 {
            b = 0
        } else {
            b = 138.5177312231 * log(temp - 10) - 305.0447927307
        }

        func clamp(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v))) }
        return RGB(r: clamp(r), g: clamp(g), b: clamp(b))
    }
}
