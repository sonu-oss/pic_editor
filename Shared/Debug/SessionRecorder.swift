import SwiftUI
import UniformTypeIdentifiers

/// A recorded run of hand frames. Saved as JSON so tests can replay real hand movement
/// without a camera (PRD Section 10, record/replay).
struct HandSession: Sendable, Codable, Equatable {
    var frames: [HandFrame]
}

/// Lets SwiftUI's save panel write a HandSession to a .json file.
struct HandSessionDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var session: HandSession

    init(session: HandSession) {
        self.session = session
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        session = try JSONDecoder().decode(HandSession.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(session))
    }
}
