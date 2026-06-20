import SwiftUI
import AuroraCore
import AuroraCircadian

/// Full circadian controls: override, color-temperature range, brightness,
/// location, and a live 24-hour schedule preview with a time scrubber.
struct CircadianSettingsView: View {
    @ObservedObject var model: AuroraModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Override", selection: overrideBinding) {
                ForEach(CircadianOverride.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ScheduleGraphView(
                points: model.todaySchedule(),
                nowHour: model.nowHour,
                gamma: model.outputGamma,
                previewHour: $model.previewHour
            )

            GroupBox("Color temperature") {
                VStack(alignment: .leading, spacing: 8) {
                    kelvinSlider("Day", \.dayKelvin, 4000...7000)
                    kelvinSlider("Sunset", \.sunsetKelvin, 2500...4500)
                    kelvinSlider("Night", \.nightKelvin, 1200...3500)
                    Text("Lower Night = warmer / more orange (1200K ≈ amber, 1900K ≈ orange, 2700K ≈ warm yellow). Tap **Night** above to preview it on the strip.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(6)
            }

            GroupBox("Brightness") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Dim toward night", isOn: bind(\.dimAtNight))
                    if model.circadianSettings.dimAtNight {
                        HStack {
                            Text("Night floor").frame(width: 80, alignment: .leading)
                            Slider(value: bind(\.nightBrightness), in: 0.1...1)
                            Text("\(Int(model.circadianSettings.nightBrightness * 100))%")
                                .frame(width: 44, alignment: .trailing).monospacedDigit()
                        }
                    }
                }
                .padding(6)
            }

            GroupBox("Location") {
                HStack {
                    Image(systemName: "location")
                    Text(String(format: "%.2f°, %.2f°",
                                model.circadianSettings.latitude,
                                model.circadianSettings.longitude))
                    .monospacedDigit()
                    Spacer()
                    Button("Use my location") { model.requestLocation() }
                }
                .padding(6)
            }
        }
    }

    // MARK: Bindings & helpers

    private var overrideBinding: Binding<CircadianOverride> {
        Binding(
            get: { model.circadianSettings.override },
            set: { model.circadianSettings.override = $0 }
        )
    }

    private func bind<T>(_ keyPath: WritableKeyPath<CircadianSettings, T>) -> Binding<T> {
        Binding(
            get: { model.circadianSettings[keyPath: keyPath] },
            set: { model.circadianSettings[keyPath: keyPath] = $0 }
        )
    }

    private func kelvinSlider(
        _ label: String,
        _ keyPath: WritableKeyPath<CircadianSettings, Double>,
        _ range: ClosedRange<Double>
    ) -> some View {
        let kelvin = model.circadianSettings[keyPath: keyPath]
        return HStack(spacing: 8) {
            Text(label).frame(width: 52, alignment: .leading)
            RoundedRectangle(cornerRadius: 4)
                .fill(model.displayColor(kelvin: kelvin).swiftUIColor)
                .frame(width: 24, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.15)))
            Slider(value: bind(keyPath), in: range)
            Text("\(Int(kelvin))K")
                .frame(width: 50, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

/// Renders the day's natural color schedule as a horizontal band, with markers
/// for "now" and the scrubbed preview time.
struct ScheduleGraphView: View {
    let points: [SchedulePoint]
    let nowHour: Double
    let gamma: Double
    @Binding var previewHour: Double?

    var body: some View {
        VStack(spacing: 8) {
            Canvas { ctx, size in
                guard points.count > 1 else { return }
                let w = size.width, h = size.height

                for i in points.indices {
                    let p = points[i]
                    let x = CGFloat(p.hour / 24) * w
                    let nextX = i + 1 < points.count ? CGFloat(points[i + 1].hour / 24) * w : w
                    let color = ColorTemperature.rgb(kelvin: p.kelvin).gammaCorrected(gamma).scaled(by: p.brightness).swiftUIColor
                    ctx.fill(Path(CGRect(x: x, y: 0, width: max(nextX - x, 1), height: h)), with: .color(color))
                }

                marker(ctx, hour: nowHour, in: size, color: .white.opacity(0.55), width: 1)
                if let preview = previewHour {
                    marker(ctx, hour: preview, in: size, color: .white, width: 2)
                }
            }
            .frame(height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12)))

            HStack(spacing: 10) {
                Slider(
                    value: Binding(get: { previewHour ?? nowHour }, set: { previewHour = $0 }),
                    in: 0...24
                )
                Button("Live") { previewHour = nil }
                    .disabled(previewHour == nil)
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var label: String {
        let h = previewHour ?? nowHour
        let hh = Int(h), mm = Int((h - floor(h)) * 60)
        let prefix = previewHour == nil ? "Live" : "Preview"
        return String(format: "%@ · %02d:%02d", prefix, hh % 24, mm)
    }

    private func marker(_ ctx: GraphicsContext, hour: Double, in size: CGSize, color: Color, width: CGFloat) {
        let x = CGFloat(hour / 24) * size.width
        var path = Path()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: size.height))
        ctx.stroke(path, with: .color(color), lineWidth: width)
    }
}
