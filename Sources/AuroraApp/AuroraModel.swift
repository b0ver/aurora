import Foundation
import Combine
import AuroraCore
import AuroraDevice
import AuroraCircadian
import AuroraEngine
import AuroraCapture
import AuroraAudio

/// App-level view model (the single source of truth the UI binds to). Wraps the
/// engine + modes, forwards user edits as value-captured providers (race-free
/// across the render thread), persists state, and republishes the live frame.
@MainActor
final class AuroraModel: ObservableObject {
    let engine: LightEngine
    /// Main-thread-only circadian instance used for the schedule graph + queries.
    let circadian: CircadianMode
    let screenSync: ScreenSyncController
    let musicSync: MusicSyncController
    let locationProvider = LocationProvider()

    let detectedInfo: ControllerInfo?
    let portPath: String?
    let baseLayout: LEDLayout
    let outputGamma: Double = 2.8

    @Published var mode: Mode {
        didSet {
            engine.setMode(mode)
            updateCaptureState()
            persist()
        }
    }
    @Published var brightness: Double {
        didSet { engine.setBrightness(brightness); persist() }
    }
    @Published var circadianSettings: CircadianSettings {
        didSet {
            circadian.settings = circadianSettings
            engine.setProvider(makeCircadianProvider(), for: .circadian)
            persist()
        }
    }
    @Published var installationMethod: InstallationMethod {
        didSet { screenSync.updateLayout(previewLayout); persist() }
    }
    @Published var screenSyncSubMode: ScreenSyncSubMode {
        didSet { screenSync.subMode = screenSyncSubMode; persist() }
    }
    @Published var screenSyncSaturation: Double {
        didSet { screenSync.saturation = screenSyncSaturation; persist() }
    }
    @Published var musicMode: MusicMode {
        didSet { musicSync.mode = musicMode; persist() }
    }
    @Published var musicSensitivity: Double {
        didSet { musicSync.sensitivity = musicSensitivity; persist() }
    }
    @Published var previewHour: Double? {
        didSet { engine.setPreviewTime(previewHour.map(dateFor(hour:))) }
    }

    @Published private(set) var lastFrame: [RGB] = []
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isConnected: Bool = false

    init() {
        let saved = Persistence.load()

        let detected = DeviceManager.detect()
        let controller: LEDController
        if let d = detected {
            controller = DeviceManager.makeController(for: d)
        } else {
            controller = SimulatedLEDController(layout: .strip(count: 54))
        }
        self.detectedInfo = detected?.info
        self.portPath = detected?.portPath

        let base = LEDLayout.fromLines(detected?.info.lines ?? [14, 26, 14])
        self.baseLayout = base
        let method = saved?.installationMethod ?? .default
        let spatial = base.applying(method)

        let settings = saved?.circadian ?? CircadianSettings(latitude: 55.75, longitude: 37.62)
        self.circadian = CircadianMode(settings: settings)

        let subMode = saved?.screenSyncSubMode ?? .full
        let saturation = saved?.screenSyncSaturation ?? 1.15
        let ss = ScreenSyncController(spatialLayout: spatial, subMode: subMode, saturation: saturation)
        self.screenSync = ss

        let musicModeStart = saved?.musicMode ?? .spectrum
        let musicSens = saved?.musicSensitivity ?? 1.0
        let ms = MusicSyncController(mode: musicModeStart, sensitivity: musicSens)
        self.musicSync = ms

        let startMode = saved?.mode ?? .circadian
        let startBrightness = saved?.brightness ?? 1.0

        let circadianProvider = AuroraModel.circadianProvider(settings: settings, gamma: 2.8)
        let screenProvider: @Sendable (Date, LEDLayout) -> [RGB] = { _, _ in ss.currentFrame() }
        let musicProvider: @Sendable (Date, LEDLayout) -> [RGB] = { _, layout in ms.currentFrame(layout) }
        let eng = LightEngine(
            controller: controller,
            providers: [.circadian: circadianProvider, .screenSync: screenProvider, .musicSync: musicProvider],
            mode: startMode,
            brightness: startBrightness,
            fps: 30
        )
        self.engine = eng

        self.mode = startMode
        self.brightness = startBrightness
        self.circadianSettings = settings
        self.installationMethod = method
        self.screenSyncSubMode = subMode
        self.screenSyncSaturation = saturation
        self.musicMode = musicModeStart
        self.musicSensitivity = musicSens

        eng.$lastFrame.assign(to: &$lastFrame)
        eng.$isRunning.assign(to: &$isRunning)
        eng.$isConnected.assign(to: &$isConnected)

        locationProvider.onUpdate = { [weak self] lat, lon in
            guard let self else { return }
            self.circadianSettings.latitude = lat
            self.circadianSettings.longitude = lon
        }

        eng.start()
        updateCaptureState()
    }

    // MARK: Intents

    func togglePause() { engine.setPaused(isRunning) }
    func requestLocation() { locationProvider.request() }
    func startScreenCapture() { screenSync.start() }

    var deviceStatus: String {
        if let info = detectedInfo {
            let port = portPath.map { ($0 as NSString).lastPathComponent } ?? "?"
            return "\(info.model) · \(info.ledCount) LEDs · \(port)"
        }
        return "Preview only · \(engine.controller.layout.count) LEDs"
    }

    var hasRealDevice: Bool { detectedInfo != nil }
    var previewLayout: LEDLayout { baseLayout.applying(installationMethod) }

    func todaySchedule() -> [SchedulePoint] { circadian.daySchedule(on: Date()) }

    var nowHour: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(comps.hour ?? 0) + Double(comps.minute ?? 0) / 60
    }

    func displayColor(kelvin: Double, brightness: Double = 1) -> RGB {
        ColorTemperature.rgb(kelvin: kelvin).gammaCorrected(outputGamma).scaled(by: brightness)
    }

    // MARK: Private

    private func updateCaptureState() {
        if mode == .screenSync { screenSync.start() } else { screenSync.stop() }
        if mode == .musicSync { musicSync.start() } else { musicSync.stop() }
    }

    func startMusicCapture() { musicSync.start() }

    private func makeCircadianProvider() -> @Sendable (Date, LEDLayout) -> [RGB] {
        AuroraModel.circadianProvider(settings: circadianSettings, gamma: outputGamma)
    }

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

    private func dateFor(hour: Double) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        return start.addingTimeInterval(hour * 3600)
    }

    private func persist() {
        Persistence.save(SavedState(
            mode: mode,
            brightness: brightness,
            circadian: circadianSettings,
            installationMethod: installationMethod,
            screenSyncSubMode: screenSyncSubMode,
            screenSyncSaturation: screenSyncSaturation,
            musicMode: musicMode,
            musicSensitivity: musicSensitivity
        ))
    }
}
