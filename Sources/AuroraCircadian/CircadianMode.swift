import Foundation
import AuroraCore

/// Tunables for the circadian schedule. Defaults mirror f.lux-style behaviour.
public struct CircadianSettings: Sendable {
    public var dayKelvin: Double      // full daylight
    public var sunsetKelvin: Double   // around the horizon
    public var nightKelvin: Double    // deep night
    public var latitude: Double
    public var longitude: Double
    public var dimAtNight: Bool
    public var nightBrightness: Double  // 0...1, floor brightness at deep night

    public init(
        latitude: Double,
        longitude: Double,
        dayKelvin: Double = 6500,
        sunsetKelvin: Double = 3400,
        nightKelvin: Double = 1900,
        dimAtNight: Bool = true,
        nightBrightness: Double = 0.45
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.dayKelvin = dayKelvin
        self.sunsetKelvin = sunsetKelvin
        self.nightKelvin = nightKelvin
        self.dimAtNight = dimAtNight
        self.nightBrightness = nightBrightness
    }
}

/// Circadian mode: sets a single color temperature across the strip based on the
/// sun's position, transitioning smoothly from cool daylight to warm night.
public final class CircadianMode: ModeSource {
    public var settings: CircadianSettings

    public init(settings: CircadianSettings) {
        self.settings = settings
    }

    /// Target color temperature (Kelvin) for the given moment.
    public func currentKelvin(at date: Date) -> Double {
        let elevation = elevation(at: date)
        // Above +10°: full day. 0°…+10°: sunset → day. -6°…0°: night → sunset.
        if elevation >= 10 { return settings.dayKelvin }
        if elevation <= -6 { return settings.nightKelvin }
        if elevation >= 0 {
            return lerp(settings.sunsetKelvin, settings.dayKelvin, elevation / 10)
        }
        return lerp(settings.nightKelvin, settings.sunsetKelvin, (elevation + 6) / 6)
    }

    /// Brightness multiplier (0...1) for the given moment.
    public func brightness(at date: Date) -> Double {
        guard settings.dimAtNight else { return 1 }
        let elevation = elevation(at: date)
        if elevation >= 10 { return 1 }
        if elevation <= -6 { return settings.nightBrightness }
        // Ramp the floor brightness → full across the -6°…+10° band.
        return lerp(settings.nightBrightness, 1, (elevation + 6) / 16)
    }

    public func frame(at date: Date, layout: LEDLayout) -> [RGB] {
        let color = ColorTemperature
            .rgb(kelvin: currentKelvin(at: date))
            .scaled(by: brightness(at: date))
        return Array(repeating: color, count: layout.count)
    }

    private func elevation(at date: Date) -> Double {
        SolarPosition.elevationDegrees(
            date: date,
            latitude: settings.latitude,
            longitude: settings.longitude
        )
    }
}

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * max(0, min(1, t))
}
