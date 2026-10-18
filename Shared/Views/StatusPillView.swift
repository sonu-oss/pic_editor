import SwiftUI

/// UI-2: top-center pill showing the gesture state, the detected pose, and the active tool.
struct StatusPillView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if model.gestureState == .idle && model.armProgress > 0 {
                    ProgressRing(progress: model.armProgress)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .fill(stateColor)
                        .frame(width: 10, height: 10)
                }
                Text(model.gestureState.displayName)
                    .fontWeight(.semibold)
            }

            Divider().frame(height: 16)

            Text("\(model.pose.emoji) \(model.pose.displayName)")

            if model.gestureState != .idle {
                Divider().frame(height: 16)
                Text("\(model.activeTool.displayName) \(model.activeTool.formatted(model.value(of: model.activeTool)))")
                    .monospacedDigit()
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .animation(.easeOut(duration: 0.15), value: model.gestureState)
    }

    private var stateColor: Color {
        switch model.gestureState {
        case .idle: .gray
        case .armed: .green
        case .adjusting: .orange
        case .pointing: .blue
        }
    }
}

/// A circle that fills clockwise from the top as `progress` goes 0 → 1.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.3), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
