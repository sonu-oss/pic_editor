import SwiftUI

/// Small developer panel: tracking speed and on/off switches for testing.
struct DebugHUDView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 6) {
            Text("Tracking: \(Int(model.trackingFPS.rounded())) fps")
                .monospacedDigit()
            Text("Hands: \(model.hands.count)")
            Text("Camera: \(model.cameraState.label)")
            Divider()
            Toggle("Skeleton", isOn: $model.showSkeleton)
            Toggle("Smoothing", isOn: $model.smoothingEnabled)
            Toggle("Camera preview", isOn: $model.showCameraPreview)
        }
        .font(.callout)
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .fixedSize()
    }
}
