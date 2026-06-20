// swift-tools-version: 6.0
import PackageDescription

// Aurora — native macOS ambient lighting controller.
// Built with SwiftPM so it can be compiled headlessly with Command Line Tools
// (no full Xcode required). See docs/adr/0002-build-system-spm.md.
//
// We use the Swift 5 language mode for now to keep the early skeleton simple;
// migration to full Swift 6 strict concurrency is tracked for a later milestone.
let package = Package(
    name: "Aurora",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AuroraApp", targets: ["AuroraApp"]),
        .library(name: "AuroraCore", targets: ["AuroraCore"]),
    ],
    targets: [
        .target(name: "AuroraCore"),
        .target(name: "AuroraDevice", dependencies: ["AuroraCore"]),
        .target(name: "AuroraCircadian", dependencies: ["AuroraCore"]),
        .target(
            name: "AuroraEngine",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian"]
        ),
        .executableTarget(
            name: "AuroraApp",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian", "AuroraEngine"]
        ),
        // Lightweight CLI check harness. XCTest / Swift Testing both require full
        // Xcode (absent on this dev machine), so logic checks run as an executable:
        //   swift run AuroraChecks
        // Migrate to Swift Testing once full Xcode is available (see ADR-0002).
        .executableTarget(
            name: "AuroraChecks",
            dependencies: ["AuroraCore", "AuroraCircadian", "AuroraDevice"]
        ),
        // Hardware bring-up CLI (M2): port detection, handshake, color/order test,
        // and live circadian on the real controller. See docs/protocol/.
        .executableTarget(
            name: "AuroraProbe",
            dependencies: ["AuroraCore", "AuroraDevice", "AuroraCircadian"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
