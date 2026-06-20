import Foundation
import Combine
import AuroraCore
import AuroraDevice
import AuroraCircadian
import AuroraEngine

/// App-level view model (the single source of truth the UI binds to). Wraps the
/// engine + circadian mode, forwards user edits, persists state, and republishes
/// the live frame for the preview.
@MainActor
final class AuroraModel: ObservableObject {
    let engine: LightEngine
    let circadian: CircadianMode
    let locationProvider = LocationProvider()

    @Published var mode: Mode {
        didSet { engine.setMode(mode); persist() }
    }
    @Published var brightness: Double {
        didSet { engine.masterBrightness = brightness; engine.refresh(); persist() }
    }
    @Published var circadianSettings: CircadianSettings {
        didSet { circadian.settings = circadianSettings; engine.refresh(); persist() }
    }
    /// Non-nil while the user is scrubbing the schedule preview (local hour 0...24).
    @Published var previewHour: Double? {
        didSet { applyPreview() }
    }

    // Republished from the engine so views observing the model refresh live.
    @Published private(set) var lastFrame: [RGB] = []
    @Published private(set) var isRunning: Bool = false

    init() {
        let saved = Persistence.load()
        let layout = LEDLayout.strip(count: 54)
        let controller = SimulatedLEDController(layout: layout)
        let settings = saved?.circadian ?? CircadianSettings(latitude: 55.75, longitude: 37.62)
        let circ = CircadianMode(settings: settings)
        let eng = LightEngine(controller: controller, sources: [.circadian: circ], tickInterval: 1.0)

        self.engine = eng
        self.circadian = circ
        self.mode = saved?.mode ?? .circadian
        self.brightness = saved?.brightness ?? 1.0
        self.circadianSettings = settings

        eng.masterBrightness = brightness
        eng.activeMode = mode
        eng.$lastFrame.assign(to: &$lastFrame)
        eng.$isRunning.assign(to: &$isRunning)

        locationProvider.onUpdate = { [weak self] lat, lon in
            guard let self else { return }
            self.circadianSettings.latitude = lat
            self.circadianSettings.longitude = lon
        }

        eng.start()
    }

    // MARK: Intents

    func togglePause() {
        isRunning ? engine.stop() : engine.start()
    }

    func requestLocation() {
        locationProvider.request()
    }

    var deviceStatus: String {
        let where_ = engine.controller.isConnected ? "Controller connected" : "Preview only"
        return "\(where_) · \(engine.controller.layout.count) LEDs"
    }

    /// Schedule samples for today's preview graph.
    func todaySchedule() -> [SchedulePoint] {
        circadian.daySchedule(on: Date())
    }

    var nowHour: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    // MARK: Private

    private func applyPreview() {
        engine.previewTime = previewHour.map(dateFor(hour:))
        engine.refresh()
    }

    private func dateFor(hour: Double) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return start.addingTimeInterval(hour * 3600)
    }

    private func persist() {
        Persistence.save(SavedState(mode: mode, brightness: brightness, circadian: circadianSettings))
    }
}
