import SwiftUI
import AppKit
import AuroraCore
import AuroraCircadian
import AuroraCapture
import AuroraAudio

/// The menu-bar panel — the headline UX: switch modes, override the circadian
/// schedule, see the live strip, set brightness, pause — all without a window.
struct MenuBarView: View {
    @ObservedObject var model: AuroraModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Picker("Mode", selection: $model.mode) {
                ForEach(Mode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if model.mode == .circadian {
                Picker("Override", selection: overrideBinding) {
                    ForEach(CircadianOverride.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else if model.mode == .screenSync {
                Picker("Region", selection: $model.screenSyncSubMode) {
                    ForEach(ScreenSyncSubMode.allCases, id: \.self) {
                        Image(systemName: $0.symbol).help($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else if model.mode == .musicSync {
                Picker("Style", selection: $model.musicMode) {
                    ForEach(MusicMode.allCases, id: \.self) {
                        Image(systemName: $0.symbol).help($0.title).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            LEDStripView(frame: model.lastFrame)
                .frame(height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            brightnessRow

            HStack {
                Button(model.isRunning ? "Pause" : "Resume") { model.togglePause() }
                Spacer()
                Button("Open Aurora…") { openWindow(id: "main") }
            }

            Divider()

            Button("Quit Aurora") { NSApplication.shared.terminate(nil) }
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill").foregroundStyle(.yellow)
            Text("Aurora").font(.headline)
            Spacer()
            Circle()
                .fill(model.isConnected ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
        }
    }

    private var brightnessRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.min")
            Slider(value: $model.brightness, in: 0...1)
            Image(systemName: "sun.max")
        }
        .foregroundStyle(.secondary)
    }

    private var overrideBinding: Binding<CircadianOverride> {
        Binding(
            get: { model.circadianSettings.override },
            set: { model.circadianSettings.override = $0 }
        )
    }
}
