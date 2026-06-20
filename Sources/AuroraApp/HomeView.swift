import SwiftUI
import AuroraCore

/// Main window: live preview, mode switcher, mode-specific settings (circadian
/// today), and device status.
struct HomeView: View {
    @ObservedObject var model: AuroraModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                LEDStripView(frame: model.lastFrame)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                Picker("Mode", selection: $model.mode) {
                    ForEach(Mode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if model.mode == .circadian {
                    CircadianSettingsView(model: model)
                } else {
                    ContentUnavailablePlaceholder(mode: model.mode)
                }

                GroupBox("Master brightness") {
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: $model.brightness, in: 0...1)
                        Image(systemName: "sun.max")
                    }
                    .foregroundStyle(.secondary)
                    .padding(6)
                }

                Label(model.deviceStatus,
                      systemImage: model.engine.controller.isConnected ? "cable.connector" : "eye")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(minWidth: 480, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill").font(.title).foregroundStyle(.yellow)
            Text("Aurora").font(.largeTitle.bold())
            Spacer()
        }
    }
}

/// Placeholder shown for modes that aren't wired up yet.
struct ContentUnavailablePlaceholder: View {
    let mode: Mode

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: mode.symbol).font(.largeTitle).foregroundStyle(.secondary)
            Text("\(mode.title) is coming soon").font(.headline)
            Text("Circadian mode is fully available today.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
