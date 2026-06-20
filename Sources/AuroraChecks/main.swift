import Foundation
import AuroraCore
import AuroraCircadian
import AuroraDevice
import AuroraCapture
import AuroraAudio

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

print("Gamma (LED color correction)")
check(RGB.white.gammaCorrected(2.8) == .white, "gamma preserves white")
check(RGB.black.gammaCorrected(2.8) == .black, "gamma preserves black")
let warm = ColorTemperature.rgb(kelvin: 1600)
let warmG = warm.gammaCorrected(2.8)
check(warmG.g < warm.g, "gamma lowers the green channel of a warm color")
let ratioBefore = Double(warm.g) / Double(max(warm.r, 1))
let ratioAfter = Double(warmG.g) / Double(max(warmG.r, 1))
check(ratioAfter < ratioBefore, "gamma shifts warm color toward orange (lower green:red ratio)")

print("Screen sync sampler")
var px = [RGB]()
for _ in 0..<4 { for x in 0..<4 { px.append(x < 2 ? RGB(r: 255, g: 0, b: 0) : RGB(r: 0, g: 0, b: 255)) } }
let grid = PixelGrid(width: 4, height: 4, pixels: px)
let sLayout = LEDLayout.fromLines([2, 2, 2])   // 6 LEDs, W=2 H=2
let sampled = EdgeSampler.sample(grid: grid, layout: sLayout, subMode: .full, saturation: 1.0)
check(sampled.count == sLayout.count, "sampler returns one color per LED")
check(sampled.first!.r > sampled.first!.b, "left LED (x=0) samples the red left side")
check(sampled.last!.b > sampled.last!.r, "right LED (x=max) samples the blue right side")
let half = ScreenSyncSubMode.leftHalf.sourceRect
check(half.x1 == 0.5, "leftHalf source rect covers the left screen half")

print("Audio FFT")
let analyzer = SpectrumAnalyzer(size: 1024)
let targetBin = 64
let sr = 48_000.0
let freq = sr * Double(targetBin) / 1024.0
var sine = [Float](repeating: 0, count: 1024)
for i in 0..<1024 { sine[i] = Float(sin(2 * Double.pi * freq * Double(i) / sr)) }
let mags = analyzer.magnitudes(sine)
var peakBin = 0
var peakVal: Float = 0
for (i, m) in mags.enumerated() where m > peakVal { peakVal = m; peakBin = i }
check(abs(peakBin - targetBin) <= 2, "FFT peak at expected bin for a \(Int(freq))Hz tone (got bin \(peakBin))")
check(peakVal > 0, "FFT produces non-zero magnitude for a tone")
check((analyzer.magnitudes([Float](repeating: 0, count: 1024)).max() ?? 1) < 0.001, "FFT of silence is ~zero")
let bands = analyzer.bands(mags, count: 24)
check(bands.count == 24 && bands.contains { $0 > 0 }, "band grouping yields 24 non-empty bands")

print("RGB HSV")
check(RGB.hsv(0, 1, 1) == RGB(r: 255, g: 0, b: 0), "hue 0 = red")
let green = RGB.hsv(1.0 / 3.0, 1, 1)
check(green.g > green.r && green.g > green.b, "hue 1/3 = green")
let rgbRoundTrip = try! JSONDecoder().decode(RGB.self, from: try! JSONEncoder().encode(RGB(r: 12, g: 34, b: 56)))
check(rgbRoundTrip == RGB(r: 12, g: 34, b: 56), "RGB survives a JSON round-trip (static color persistence)")

print("")
if failures == 0 {
    print("✅ All checks passed")
    exit(0)
} else {
    print("❌ \(failures) check(s) FAILED")
    exit(1)
}
