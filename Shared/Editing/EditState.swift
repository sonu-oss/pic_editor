/// Every edit applied to the photo (ED-1). Small and Equatable, so undo can keep whole snapshots.
struct EditState: Sendable, Codable, Equatable {
    var preset: Preset = .original
    /// Only tools moved away from their default are stored, so two unedited states are always equal.
    private var values: [Tool: Double] = [:]

    init() {}

    subscript(tool: Tool) -> Double {
        get { values[tool] ?? tool.defaultValue }
        set {
            let clamped = tool.clamped(newValue)
            values[tool] = clamped == tool.defaultValue ? nil : clamped
        }
    }

    var isUnedited: Bool { preset == .original && values.isEmpty }
}
