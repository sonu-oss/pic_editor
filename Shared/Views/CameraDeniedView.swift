import SwiftUI

/// CAM-1: shown when the user hasn't allowed camera access.
struct CameraDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera access is off")
                .font(.title2.bold())
            Text("GestureEdit needs the camera to see your hand gestures. Video never leaves your Mac. Turn on GestureEdit under Privacy & Security → Camera, then come back.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: 440)
    }
}
