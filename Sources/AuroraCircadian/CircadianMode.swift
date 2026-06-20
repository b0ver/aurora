import Foundation
import AuroraCore

/// Manual override of the automatic sun-driven schedule.
public enum CircadianOverride: String, CaseIterable, Codable, Sendable {
    case auto   // follow the sun
    case day    // force full daylight
    case night  // force warm night

    public var title: String {
        switch self {
        case .auto: return "Auto"
        case .day: return "Day"
        case .night: return "Night"
        }
    }
}

/// Tunables for the circadian schedule. Defaults mirror f.lux-style behaviour.
public struct CircadianSettings: Codable, Sendable, Equatable {
    public var dayKelvin: Double      // full daylight
    public var sunsetKelvin: Double   // around the horizon
    public var nightKelvin: Double    // deep night
    public var latitude: Double
    public var longitude: Double
    public var dimAtNight: Bool
    public var nightBrightness: Double  // 0...1, floor brightness at deep night
    public var override: CircadianOverride

    public init(
        latitude: Double,
        longitude: Double,
        dayKelvin: Double = 6500,
        sunsetKelvin: Double = 3400,
        nightKelvin: Double = 1600,
        dimAtNight: Bool = true,
        nightBrightness: Double = 0.45,
        override: CircadianOverride = .auto
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.dayKelvin = dayKelvin
        self.sunsetKelvin = sunsetKelvin
        self.nightKelvin = nightKelvin
        self.dimAtNight = dimAtNight
        self.nightBrightness = nightBrightness
        self.override = override
    }
}

/// One sampled point of the day's schedule (for the UI preview graph).
public struct SchedulePoint: Sendable {
    public let hour: Double       // 0...24 local time
    public let kelvin: Double
    public let brightness: Double
}

/// Circadian mode: sets a single color temperature across the strip based on the
/// sun's position, transitioning smoothly from cool daylight to warm night.
public final class CircadianMode: ModeSource {
    public var settings: CircadianSettings

    public init(settings: CircadianSettings) {
        self.settings = settings
    }

    // MARK: Public schedule queries

    /// Target color temperature (Kelvin), honouring any manual override.
    public func currentKelvin(at date: Date) -> Double {
        switch settings.override {
        case .day: return settings.dayKelvin
        case .night: return settings.nightKelvin
        case .auto: return naturalKelvin(at: date)
        }
    }

    /// Brightness multiplier (0...1), honouring any manual override.
    public func brightness(at date: Date) -> Double {
        guard settings.dimAtNight else { return 1 }
        switch settings.override {
        case .day: return 1
        case .night: return settings.nightBrightness
        case .auto: return naturalBrightness(at: date)
        }
    }

    public func frame(at date: Date, layout: LEDLayout) -> [RGB] {
        let color = ColorTemperature
            .rgb(kelvin: currentKelvin(at: date))
            .scaled(by: brightness(at: date))
        return Array(repeating: color, count: layout.count)
    }

    /// Samples the *natural* (override-free) schedule across the local day of
    /// `date` — used to draw the schedule preview.
    public func daySchedule(on date: Date, samples: Int = 96) -> [SchedulePoint] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let startOfDay = cal.startOfDay(for: date)
        return (0..<samples).map { i in
            let frac = Double(i) / Double(samples)
            let t = startOfDay.addingTimeInterval(frac * 86_400)
            return SchedulePoint(
                hour: frac * 24,
                kelvin: naturalKelvin(at: t),
                brightness: settings.dimAtNight ? naturalBrightness(at: t) : 1
            )
        }
    }

    // MARK: Natural (sun-driven) curves

    private func naturalKelvin(at date: Date) -> Double {
        let elevation = elevation(at: date)
        if elevation >= 10 { return settings.dayKelvin }
        if elevation <= -6 { return settings.nightKelvin }
        if elevation >= 0 {
            return lerp(settings.sunsetKelvin, settings.dayKelvin, elevation / 10)
        }
        return lerp(settings.nightKelvin, settings.sunsetKelvin, (elevation + 6) / 6)
    }

    private func naturalBrightness(at date: Date) -> Double {
        let elevation = elevation(at: date)
        if elevation >= 10 { return 1 }
        if elevation <= -6 { return settings.nightBrightness }
        return lerp(settings.nightBrightness, 1, (elevation + 6) / 16)
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
