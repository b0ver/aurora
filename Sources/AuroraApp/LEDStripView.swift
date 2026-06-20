import SwiftUI
import AuroraCore

/// On-screen mirror of the LED strip — renders exactly the frame the controller
/// (simulated or real) is showing.
struct LEDStripView: View {
    let frame: [RGB]
    var cornerRadius: CGFloat = 3

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(frame.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.swiftUIColor)
            }
        }
        .background(Color.black.opacity(0.85))
    }
}

extension RGB {
    var swiftUIColor: Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
