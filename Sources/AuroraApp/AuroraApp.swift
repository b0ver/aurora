import SwiftUI
import AuroraCore
import AuroraEngine

@main
struct AuroraApp: App {
    @StateObject private var model = AuroraModel()

    var body: some Scene {
        MenuBarExtra("Aurora", systemImage: "sun.max.fill") {
            MenuBarView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Aurora", id: "main") {
            HomeView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
