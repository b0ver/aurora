import SwiftUI
import AuroraCore
import AuroraDevice
import AuroraCircadian
import AuroraEngine

@main
struct AuroraApp: App {
    @StateObject private var engine: LightEngine

    init() {
        // Default to an SK0124-class strip (54 LEDs) on the simulated controller
        // until a real controller is detected (M2).
        let layout = LEDLayout.strip(count: 54)
        let controller = SimulatedLEDController(layout: layout)

        // TODO(M1): replace the hard-coded location with CoreLocation.
        let settings = CircadianSettings(latitude: 55.75, longitude: 37.62)
        let circadian = CircadianMode(settings: settings)

        let sources: [Mode: ModeSource] = [.circadian: circadian]
        _engine = StateObject(wrappedValue: LightEngine(controller: controller, sources: sources))
    }

    var body: some Scene {
        MenuBarExtra("Aurora", systemImage: "sun.max.fill") {
            MenuBarView(engine: engine)
        }
        .menuBarExtraStyle(.window)

        Window("Aurora", id: "main") {
            HomeView(engine: engine)
        }
        .windowResizability(.contentSize)
    }
}
