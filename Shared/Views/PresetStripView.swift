import SwiftUI

/// The preset buttons on the right (ED-3). Dwell-clicking them with the gesture cursor comes in Phase 5.
struct PresetStripView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Presets")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(Preset.allCases, id: \.self) { preset in
                Button {
                    model.applyPreset(preset)
                } label: {
                    Text(preset.displayName)
                        .frame(width: 96, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(model.editState.preset == preset ? .accentColor : nil)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
