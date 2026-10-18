import SwiftUI

/// Placeholder main window for Phase 0.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.raised")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("GestureEdit")
                .font(.largeTitle.bold())
            Text(model.statusMessage)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
