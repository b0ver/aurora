import SwiftUI
import AppKit
import AuroraCore
import AuroraAudio

/// Music Sync controls: reactive style, sensitivity, capture status + permission.
struct MusicSyncSettingsView: View {
    @ObservedObject var model: AuroraModel
    @ObservedObject var musicSync: MusicSyncController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusRow

            Picker("Style", selection: $model.musicMode) {
                ForEach(MusicMode.allCases, id: \.self) { m in
                    Label(m.title, systemImage: m.symbol).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            GroupBox("Sensitivity") {
                HStack {
                    Image(systemName: "speaker.wave.1")
                    Slider(value: $model.musicSensitivity, in: 0.3...3.0)
                    Image(systemName: "speaker.wave.3")
                    Text(String(format: "%.0f%%", model.musicSensitivity * 100))
                        .frame(width: 48, alignment: .trailing).monospacedDigit()
                }
                .foregroundStyle(.secondary)
                .padding(6)
            }

            Text("Reacts to your system audio (whatever is playing). Pick a style and tune the sensitivity to the music.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch musicSync.status {
        case .capturing:
            Label("Listening to system audio", systemImage: "waveform.badge.mic")
                .font(.caption).foregroundStyle(.green)
        case .starting:
            Label("Starting…", systemImage: "hourglass")
                .font(.caption).foregroundStyle(.secondary)
        case .idle:
            Label("Idle", systemImage: "pause.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .needsPermission:
            VStack(alignment: .leading, spacing: 6) {
                Label("Screen Recording permission needed (for system audio)", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                Button("Open System Settings → Screen Recording") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Text("Grant Aurora access, then quit and reopen the app.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label("Audio capture failed", systemImage: "xmark.octagon")
                    .font(.caption).foregroundStyle(.red)
                Text(message).font(.caption2).foregroundStyle(.secondary)
                Button("Retry") { model.startMusicCapture() }
            }
        }
    }
}
