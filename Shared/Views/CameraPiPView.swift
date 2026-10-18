import SwiftUI

/// CAM-4: the mirrored camera picture-in-picture, with the hand skeleton drawn on top (UI-5).
/// Drag the top-left handle to resize; the × hides it.
struct CameraPiPView: View {
    @Environment(AppModel.self) private var model
    @State private var width: CGFloat = 360
    @State private var widthAtDragStart: CGFloat?

    var body: some View {
        if model.showCameraPreview {
            ZStack {
                Color.black
                // CameraPreview lives in macOS/ (it wraps an AppKit view); iOS gets its own in v2.
                CameraPreview(session: model.camera.session, isRunning: model.cameraState == .running)
                if model.showSkeleton {
                    HandSkeletonOverlay(hands: model.hands)
                }
            }
            .frame(width: width, height: width * 9 / 16)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) { resizeHandle }
            .overlay(alignment: .topTrailing) { hideButton }
            .shadow(radius: 10)
        } else {
            Button {
                model.showCameraPreview = true
            } label: {
                Label("Show camera", systemImage: "video")
            }
        }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption.bold())
            .padding(6)
            .background(.ultraThinMaterial, in: Circle())
            .padding(6)
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        let start = widthAtDragStart ?? width
                        widthAtDragStart = start
                        width = min(max(start - value.translation.width, 200), 800)
                    }
                    .onEnded { _ in
                        widthAtDragStart = nil
                    }
            )
            .help("Drag to resize")
    }

    private var hideButton: some View {
        Button {
            model.showCameraPreview = false
        } label: {
            Image(systemName: "xmark")
                .font(.caption.bold())
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .help("Hide camera preview")
    }
}
