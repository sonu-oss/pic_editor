import SwiftUI

/// App entry point (macOS only). Shared UI and logic live in Shared/.
@main
struct GestureEditApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 800, minHeight: 500)
        }
    }
}
