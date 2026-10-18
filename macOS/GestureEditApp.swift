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
        .commands {
            // US9: every action also works from the keyboard.
            CommandGroup(replacing: .newItem) {
                Button("Open Photo…") { model.isImporting = true }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Export…") { model.apply(.export) }
                    .keyboardShortcut("s")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.apply(.undo) }
                    .keyboardShortcut("z")
                Button("Redo") { model.apply(.redo) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { model.apply(.zoom(scale: 1.25)) }
                    .keyboardShortcut("+")
                Button("Zoom Out") { model.apply(.zoom(scale: 0.8)) }
                    .keyboardShortcut("-")
                Button("Actual Size") { model.zoomScale = 1 }
                    .keyboardShortcut("0")
            }
        }
    }
}
