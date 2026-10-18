import SwiftUI

/// The main window: photo area in the middle, camera picture-in-picture bottom-right,
/// debug panel top-left.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            mainArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            CameraPiPView()
                .padding(16)
        }
        .overlay(alignment: .top) {
            StatusPillView()
                .padding(.top, 12)
        }
        .overlay(alignment: .topLeading) {
            DebugHUDView()
                .padding(12)
        }
        .overlay(alignment: .trailing) {
            if model.hasPhoto {
                PresetStripView()
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
            }
        }
        .task {
            await model.runHandTracking()
        }
        .task(id: model.cameraShouldRun) {
            await model.updateCamera()
        }
    }

    @ViewBuilder
    private var mainArea: some View {
        switch model.cameraState {
        case .denied:
            CameraDeniedView()
        case .failed(let message):
            ContentUnavailableView("Camera unavailable", systemImage: "video.slash", description: Text(message))
        case .off, .running:
            PhotoCanvasView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
