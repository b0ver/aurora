import Foundation
import Combine
import AuroraCore
import AuroraDevice
import AuroraCircadian
import AuroraEngine

/// App-level view model (the single source of truth the UI binds to). Wraps the
/// engine + circadian mode, forwards user edits as value-captured providers
/// (race-free across the render thread), persists state, and republishes the
/// live frame for the preview.
@MainActor
final class AuroraModel: ObservableObject {
    let engine: LightEngine
    /// Main-thread-only circadian instance used for the schedule graph + queries.
    let circadian: CircadianMode
    let locationProvider = LocationProvider()

    /// Identity of the real controller if one was detected at launch (else nil →
    /// running on the on-screen simulator).
    let detectedInfo: ControllerInfo?
    let portPath: String?

    /// Canonical (un-flipped) geometry of the strip, for the layout preview.
    let baseLayout: LEDLayout

    /// Output gamma to compensate the LED response (WS2812 green is bright). Higher
    /// = warmer colors read as deeper orange. Applied to the hue before brightness.
    let outputGamma: Double = 2.8

    @Published var mode: Mode {
        didSet { engine.setMode(mode); persist() }
    }
    @Published var brightness: Double {
        didSet { engine.setBrightness(brightness); persist() }
    }
    @Published var circadianSettings: CircadianSettings {
        didSet {
            circadian.settings = circadianSettings              // main-only, for the graph
            engine.setProvider(makeCircadianProvider(), for: .circadian)
            persist()
        }
    }
    /// How the physical strip is mounted (affects screen-sync mapping; the live
    /// grid preview reflects it). No effect on uniform modes like circadian.
    @Published var installationMethod: InstallationMethod {
        didSet { persist() }
    }
    /// Non-nil while the user is scrubbing the schedule preview (local hour 0...24).
    @Published var previewHour: Double? {
        didSet { engine.setPreviewTime(previewHour.map(dateFor(hour:))) }
    }

    // Republished from the engine so views observing the model refresh live.
    @Published private(set) var lastFrame: [RGB] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isConnected: Bool = false

    init() {
        let saved = Persistence.load()

        // Try the real hardware first; fall back to the on-screen simulator.
        let detected = DeviceManager.detect()
        let controller: LEDController
        if let d = detected {
            controller = DeviceManager.makeController(for: d)
        } else {
            controller = SimulatedLEDController(layout: .strip(count: 54))
        }
        self.detectedInfo = detected?.info
        self.portPath = detected?.portPath
        self.baseLayout = LEDLayout.fromLines(detected?.info.lines ?? [14, 26, 14])

        let settings = saved?.circadian ?? CircadianSettings(latitude: 55.75, longitude: 37.62)
        let circ = CircadianMode(settings: settings)
        self.circadian = circ

        let startMode = saved?.mode ?? .circadian
        let startBrightness = saved?.brightness ?? 1.0

        // Value-captured provider — the render thread never touches shared mutable state.
        let provider = AuroraModel.circadianProvider(settings: settings, gamma: 2.8)
        let eng = LightEngine(
            controller: controller,
            providers: [.circadian: provider],
            mode: startMode,
            brightness: startBrightness,
            fps: 30
        )
        self.engine = eng

        self.mode = startMode
        self.brightness = startBrightness
        self.circadianSettings = settings
        self.installationMethod = saved?.installationMethod ?? .default

        eng.$lastFrame.assign(to: &$lastFrame)
        eng.$isRunning.assign(to: &$isRunning)
        eng.$isConnected.assign(to: &$isConnected)

        locationProvider.onUpdate = { [weak self] lat, lon in
            guard let self else { return }
            self.circadianSettings.latitude = lat
            self.circadianSettings.longitude = lon
        }

        eng.start()
    }

    // MARK: Intents

    func togglePause() {
        engine.setPaused(isRunning)
    }

    func requestLocation() {
        locationProvider.request()
    }

    var deviceStatus: String {
        if let info = detectedInfo {
            let port = portPath.map { ($0 as NSString).lastPathComponent } ?? "?"
            return "\(info.model) · \(info.ledCount) LEDs · \(port)"
        }
        return "Preview only · \(engine.controller.layout.count) LEDs"
    }

    var hasRealDevice: Bool { detectedInfo != nil }

    /// Strip geometry with the installation method applied — drives the preview.
    var previewLayout: LEDLayout { baseLayout.applying(installationMethod) }

    /// Schedule samples for today's preview graph.
    func todaySchedule() -> [SchedulePoint] {
        circadian.daySchedule(on: Date())
    }

    var nowHour: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    // MARK: Private

    private func makeCircadianProvider() -> @Sendable (Date, LEDLayout) -> [RGB] {
        AuroraModel.circadianProvider(settings: circadianSettings, gamma: outputGamma)
    }

    /// Builds a value-captured (race-free) frame provider that applies the LED
    /// gamma to the hue, then the time-of-day brightness.
    private static func circadianProvider(
        settings: CircadianSettings,
        gamma: Double
    ) -> @Sendable (Date, LEDLayout) -> [RGB] {
        return { date, layout in
            let mode = CircadianMode(settings: settings)
            let color = ColorTemperature.rgb(kelvin: mode.currentKelvin(at: date))
                .gammaCorrected(gamma)
                .scaled(by: mode.brightness(at: date))
            return Array(repeating: color, count: layout.count)
        }
    }

    /// The final on-strip color for a given Kelvin (gamma applied) — used by the
    /// settings swatches and schedule graph so they match the strip exactly.
    func displayColor(kelvin: Double, brightness: Double = 1) -> RGB {
        ColorTemperature.rgb(kelvin: kelvin).gammaCorrected(outputGamma).scaled(by: brightness)
    }

    private func dateFor(hour: Double) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return start.addingTimeInterval(hour * 3600)
    }

    private func persist() {
        Persistence.save(SavedState(
            mode: mode,
            brightness: brightness,
            circadian: circadianSettings,
            installationMethod: installationMethod
        ))
    }
}
