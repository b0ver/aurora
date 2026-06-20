import SwiftUI
import AuroraCore

/// "Installation method" — how the strip is physically wound around the screen.
/// Mirrors the vendor setup step; lives in Settings. The grid preview updates
/// live so you can match it to your real strip.
struct LayoutSetupView: View {
    @ObservedObject var model: AuroraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Horizontal", selection: hBinding) {
                ForEach(InstallationMethod.Horizontal.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)

            Picker("Vertical", selection: vBinding) {
                ForEach(InstallationMethod.Vertical.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)

            LayoutPreview(layout: model.previewLayout)
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            Label("Big dot = LED 1 (strip start); hue shows winding order. Match it to your strip.",
                  systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var hBinding: Binding<InstallationMethod.Horizontal> {
        Binding(get: { model.installationMethod.horizontal },
                set: { model.installationMethod.horizontal = $0 })
    }

    private var vBinding: Binding<InstallationMethod.Vertical> {
        Binding(get: { model.installationMethod.vertical },
                set: { model.installationMethod.vertical = $0 })
    }
}

/// Plots the LED positions, colored by index (hue), with LED 1 enlarged — a live
/// map of where each LED sits and which way the strip winds.
struct LayoutPreview: View {
    let layout: LEDLayout

    var body: some View {
        Canvas { ctx, size in
            let pts = layout.points
            guard pts.count > 1 else { return }
            let spanX = CGFloat(max(layout.screenWidth - 1, 1))
            let spanY = CGFloat(max(layout.screenHeight - 1, 1))
            let pad: CGFloat = 14

            func at(_ p: LEDLayout.Point) -> CGPoint {
                CGPoint(
                    x: pad + CGFloat(p.x) / spanX * (size.width - 2 * pad),
                    y: pad + CGFloat(p.y) / spanY * (size.height - 2 * pad)
                )
            }

            for (i, p) in pts.enumerated() {
                let hue = Double(i) / Double(max(pts.count - 1, 1))
                let radius: CGFloat = i == 0 ? 7 : 3.2
                let rect = CGRect(x: at(p).x - radius, y: at(p).y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.fill(Path(ellipseIn: rect),
                         with: .color(Color(hue: hue, saturation: 0.75, brightness: 0.95)))
            }
        }
    }
}
