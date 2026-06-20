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

print("Circadian override")
var dayOverride = CircadianSettings(latitude: 55.75, longitude: 37.62)
dayOverride.override = .day
let dayMode = CircadianMode(settings: dayOverride)
check(dayMode.currentKelvin(at: utc(2026, 1, 1, 0)) == dayOverride.dayKelvin, "override=day forces day Kelvin even at midnight")
check(dayMode.brightness(at: utc(2026, 1, 1, 0)) == 1, "override=day forces full brightness")
var nightOverride = CircadianSettings(latitude: 55.75, longitude: 37.62)
nightOverride.override = .night
let nightMode = CircadianMode(settings: nightOverride)
check(nightMode.currentKelvin(at: utc(2026, 6, 21, 12)) == nightOverride.nightKelvin, "override=night forces night Kelvin even at noon")

print("Schedule preview")
let schedule = mode.daySchedule(on: utc(2026, 6, 21, 12), samples: 96)
check(schedule.count == 96, "daySchedule returns the requested sample count")
check(schedule.first!.hour == 0 && schedule.last!.hour < 24, "schedule hours span 0..<24")

print("Persistence")
let saved = CircadianSettings(latitude: 1.5, longitude: 2.5, override: .night)
let roundTrip = try! JSONDecoder().decode(CircadianSettings.self, from: try! JSONEncoder().encode(saved))
check(roundTrip == saved, "CircadianSettings survives a JSON round-trip")
check((try? JSONDecoder().decode(Mode.self, from: try! JSONEncoder().encode(Mode.circadian))) == .circadian, "Mode is Codable")

print("Installation method")
let base = LEDLayout.fromLines([14, 26, 14])  // SK0124-like: W=26, H=14
check(base.count == 54, "fromLines builds 54 LEDs for [14,26,14]")
check(base.screenWidth == 26 && base.screenHeight == 14, "extents derived from per-side counts")
let firstBase = base.points.first!
check(firstBase.x == 0 && firstBase.y == 13, "LED 1 starts bottom-left in canonical layout")

let identity = base.applying(InstallationMethod(horizontal: .leftToRight, vertical: .bottomToTop))
check(identity.points.map { [$0.x, $0.y] } == base.points.map { [$0.x, $0.y] }, "LTR+bottomToTop is identity")

let userMethod = InstallationMethod(horizontal: .rightToLeft, vertical: .topToBottom)
let flipped = base.applying(userMethod)
let firstFlipped = flipped.points.first!
check(firstFlipped.id == firstBase.id, "id/index order preserved under flip")
check(firstFlipped.x == 25 && firstFlipped.y == 0, "RTL+topToBottom moves LED 1 to top-right (25,0)")
check(InstallationMethod.default == userMethod, "default == user's confirmed setting (RTL + topToBottom)")

let involutive = flipped.applying(userMethod)
check(involutive.points.map { [$0.x, $0.y] } == base.points.map { [$0.x, $0.y] }, "double-applying a method is involutive")

check(ControllerCatalog.info(forReply: "SK0127,<config>")?.ledCount == 65, "catalog resolves SK0127 -> 65 LEDs")
check(ControllerCatalog.info(forReply: "garbage") == nil, "catalog rejects junk reply")

print("")
if failures == 0 {
    print("✅ All checks passed")
    exit(0)
} else {
    print("❌ \(failures) check(s) FAILED")
    exit(1)
}
