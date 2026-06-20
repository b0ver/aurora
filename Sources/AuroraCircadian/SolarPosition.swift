import Foundation

/// Computes the sun's elevation angle for a moment and location — pure math, no
/// network. Based on the NOAA solar-position algorithm.
public enum SolarPosition {
    /// Sun elevation in degrees above the horizon (negative = below).
    /// Positive ~ daytime; around 0 ~ sunrise/sunset; below ~ -6 ~ past civil dusk.
    public static func elevationDegrees(date: Date, latitude: Double, longitude: Double) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        let dayOfYear = Double(cal.ordinality(of: .day, in: .year, for: date) ?? 1)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        // Fractional year (radians).
        let gamma = 2 * Double.pi / 365.0 * (dayOfYear - 1 + (hour - 12) / 24.0)

        // Equation of time (minutes) and solar declination (radians).
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma))

        let decl = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.001480 * sin(3 * gamma)

        // True solar time (minutes). We work in UTC, so the timezone term is 0
        // and longitude enters directly.
        let timeOffset = eqTime + 4.0 * longitude
        let trueSolarTime = hour * 60 + minute + second / 60 + timeOffset
        let hourAngle = (trueSolarTime / 4.0) - 180.0   // degrees

        let latR = latitude * .pi / 180
        let haR = hourAngle * .pi / 180
        let cosZenith = sin(latR) * sin(decl) + cos(latR) * cos(decl) * cos(haR)
        let zenith = acos(max(-1, min(1, cosZenith)))
        return 90 - zenith * 180 / .pi
    }
}
