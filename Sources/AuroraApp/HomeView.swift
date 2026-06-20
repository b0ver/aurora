import SwiftUI
import AuroraCore
import AuroraEngine

/// Main window: live preview, mode switcher, brightness, device status.
/// A fuller settings surface arrives with each mode milestone.
struct HomeView: View {
    @ObservedObject var engine: LightEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill").font(.title).foregroundStyle(.yellow)
                Text("Aurora").font(.largeTitle.bold())
                Spacer()
            }

            LEDStripView(frame: engine.lastFrame)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            Picker("Mode", selection: modeBinding) {
                ForEach(Mode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            GroupBox("Brightness") {
                HStack {
                    Image(systemName: "sun.min")
                    Slider(value: $engine.masterBrightness, in: 0...1)
                    Image(systemName: "sun.max")
                }
                .foregroundStyle(.secondary)
                .padding(6)
            }

            Label(deviceStatus, systemImage: engine.controller.isConnected ? "cable.connector" : "eye")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 380)
    }

    private var deviceStatus: String {
        let where_ = engine.controller.isConnected ? "Controller connected" : "Preview only"
        return "\(where_) · \(engine.controller.layout.count) LEDs"
    }

    private var modeBinding: Binding<Mode> {
        Binding(get: { engine.activeMode }, set: { engine.setMode($0) })
    }
}
