import SwiftUI
import AuroraCore

/// Static / Scene mode: a fixed color with quick presets.
struct StaticSettingsView: View {
    @ObservedObject var model: AuroraModel

    private let presets: [(name: String, color: RGB)] = [
        ("Warm", ColorTemperature.rgb(kelvin: 2700)),
        ("Candle", ColorTemperature.rgb(kelvin: 1900)),
        ("Daylight", ColorTemperature.rgb(kelvin: 5600)),
        ("Red", RGB(r: 255, g: 0, b: 0)),
        ("Orange", RGB(r: 255, g: 90, b: 0)),
        ("Amber", RGB(r: 255, g: 150, b: 0)),
        ("Green", RGB(r: 0, g: 255, b: 30)),
        ("Cyan", RGB(r: 0, g: 200, b: 255)),
        ("Blue", RGB(r: 0, g: 60, b: 255)),
        ("Purple", RGB(r: 150, g: 0, b: 255)),
        ("Pink", RGB(r: 255, g: 40, b: 150)),
        ("White", RGB(r: 255, g: 255, b: 255)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ColorPicker("Custom color", selection: colorBinding, supportsOpacity: false)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 8)], spacing: 8) {
                ForEach(presets.indices, id: \.self) { i in
                    let preset = presets[i]
                    Button {
                        model.staticColor = preset.color
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(preset.color.swiftUIColor)
                            .frame(height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(model.staticColor == preset.color ? Color.white : .white.opacity(0.12),
                                                  lineWidth: model.staticColor == preset.color ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }

            Text("A steady color across the whole strip. Pick a preset or your own color; use the master brightness to dim it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { model.staticColor.swiftUIColor },
            set: { model.staticColor = $0.toRGB() }
        )
    }
}
