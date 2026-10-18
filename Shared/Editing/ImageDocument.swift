import SwiftUI
import UniformTypeIdentifiers

/// Lets SwiftUI's save panel write exported JPEG bytes to a file the user picks (IO-2, IO-3).
struct ImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jpeg] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
