import SwiftUI
import AppKit
import AuroraCore
import AuroraEngine

/// The menu-bar panel — the headline UX: switch modes, see the live strip,
/// set brightness, pause, all without opening a window.
struct MenuBarView: View {
    @ObservedObject var engine: LightEngine
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Picker("Mode", selection: modeBinding) {
                ForEach(Mode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if !engine.activeMode.isImplemented {
                Label("Coming soon", systemImage: "hammer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LEDStripView(frame: engine.lastFrame)
                .frame(height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            brightnessRow

            HStack {
                Button(engine.isRunning ? "Pause" : "Resume") {
                    engine.isRunning ? engine.stop() : engine.start()
                }
                Spacer()
                Button("Open Aurora…") { openWindow(id: "main") }
            }

            Divider()

            Button("Quit Aurora") { NSApplication.shared.terminate(nil) }
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 300)
        .onAppear { if !engine.isRunning { engine.start() } }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.max.fill").foregroundStyle(.yellow)
            Text("Aurora").font(.headline)
            Spacer()
            Circle()
                .fill(engine.controller.isConnected ? Color.green : Color.secondary)
                .frame(width: 8, height: 8)
        }
    }

    private var brightnessRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.min")
            Slider(value: $engine.masterBrightness, in: 0...1)
            Image(systemName: "sun.max")
        }
        .foregroundStyle(.secondary)
    }

    private var modeBinding: Binding<Mode> {
        Binding(get: { engine.activeMode }, set: { engine.setMode($0) })
    }
}
