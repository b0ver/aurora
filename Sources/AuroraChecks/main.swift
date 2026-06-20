import Foundation
import AuroraCore
import AuroraCircadian
import AuroraDevice

// Minimal check harness (stands in for XCTest/Swift Testing, which need full
// Xcode). Run with: swift run AuroraChecks  — exits non-zero on any failure.

var failures = 0
func check(_ condition: Bool, _ name: String) {
    if condition {
        print("  ✓ \(name)")
    } else {
        print("  ✗ \(name)")
        failures += 1
    }
}

func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

print("ColorTemperature")
check(ColorTemperature.rgb(kelvin: 1900).r > ColorTemperature.rgb(kelvin: 1900).b, "warm is redder than blue")
let cool = ColorTemperature.rgb(kelvin: 6500)
check(Int(cool.b) + 20 >= Int(cool.r), "cool is not red-dominant")
_ = ColorTemperature.rgb(kelvin: -100); _ = ColorTemperature.rgb(kelvin: 100_000)
check(true, "clamps out-of-range without crashing")

print("RGB")
check(RGB.white.scaled(by: 0) == .black, "scaled-by-0 is black")
check(RGB.black.blended(to: .white, t: 0.5) == RGB(r: 128, g: 128, b: 128), "blend midpoint")

print("SolarPosition")
let noon = SolarPosition.elevationDegrees(date: utc(2026, 6, 21, 9), latitude: 55.75, longitude: 37.62)
let midnight = SolarPosition.elevationDegrees(date: utc(2026, 6, 21, 21), latitude: 55.75, longitude: 37.62)
check(noon > midnight, "sun higher at local noon than midnight")
check(noon > 0, "summer local-noon sun is above the horizon")

print("SkydimoProtocol")
let redFrame = [UInt8](SkydimoProtocol.frame([RGB(r: 255, g: 0, b: 0)], order: .rgb))
check(redFrame == [0x41, 0x64, 0x61, 0x00, 0x00, 0x01, 0xFF, 0x00, 0x00], "single-red frame is byte-exact")
let grbTail = [UInt8](SkydimoProtocol.frame([RGB(r: 255, g: 10, b: 0)], order: .grb).suffix(3))
check(grbTail == [10, 255, 0], "GRB order swaps R and G")
let bigHeader = [UInt8](SkydimoProtocol.frame(Array(repeating: RGB.black, count: 300)).prefix(6))
check(bigHeader == [0x41, 0x64, 0x61, 0x00, 0x01, 0x2C], "big-endian count for 300 LEDs (0x012C)")
check(SkydimoProtocol.isValidReply("  sk0124\r\n"), "handshake reply 'sk0124' is valid")
check(!SkydimoProtocol.isValidReply("garbage"), "junk reply rejected")

print("Circadian")
let mode = CircadianMode(settings: CircadianSettings(latitude: 55.75, longitude: 37.62))
check(mode.currentKelvin(at: utc(2026, 6, 21, 9)) > mode.currentKelvin(at: utc(2026, 12, 21, 0)), "daylight cooler than night")
check(mode.frame(at: Date(), layout: .strip(count: 54)).count == 54, "frame length matches layout count")

print("")
if failures == 0 {
    print("✅ All checks passed")
    exit(0)
} else {
    print("❌ \(failures) check(s) FAILED")
    exit(1)
}
