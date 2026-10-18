import AppKit
import Combine
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
                // CAM-5: tell the model when the app or window goes away so it can pause the camera.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.isAppActive = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                    model.isAppActive = false
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didMiniaturizeNotification)) { _ in
                    model.isWindowMinimized = true
                }
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didDeminiaturizeNotification)) { _ in
                    model.isWindowMinimized = false
                }
        }
    }
}
