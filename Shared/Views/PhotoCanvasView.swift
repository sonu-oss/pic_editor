import SwiftUI
import UniformTypeIdentifiers

/// The photo in the middle of the window (UI-1), with open, drag-and-drop and export (IO-1…3).
struct PhotoCanvasView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if let preview = model.previewImage {
                Image(decorative: preview.cgImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(model.zoomScale)
                    .padding(EdgeInsets(top: 64, leading: 24, bottom: 24, trailing: 24))
                    .clipped()
            } else if model.hasPhoto {
                ProgressView()
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { await model.openPhoto(url) }
            return true
        }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: [.jpeg, .png, .heic]) { result in
            if case .success(let url) = result {
                Task { await model.openPhoto(url) }
            }
        }
        .fileExporter(
            isPresented: $model.isExportingPhoto,
            document: model.exportDocument,
            contentType: .jpeg,
            defaultFilename: model.exportFilename
        ) { result in
            switch result {
            case .success(let url): model.lastAction = "Saved \(url.lastPathComponent)"
            case .failure: model.lastAction = "Export cancelled"
            }
            model.exportDocument = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("GestureEdit")
                .font(.largeTitle.bold())
            Text("Open a photo or drop one here. Then hold an open palm to arm, and pinch to edit.")
                .foregroundStyle(.secondary)
            Button("Open Photo…") {
                model.isImporting = true
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("o")
        }
        .padding(40)
    }
}
