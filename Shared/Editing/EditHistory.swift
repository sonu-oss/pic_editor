/// Undo/redo as snapshots of EditState (HI-1). Holds at most `limit` undo steps.
struct EditHistory: Sendable {
    var limit = 50
    private(set) var undoStack: [EditState] = []
    private(set) var redoStack: [EditState] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Call after a finished edit, passing the state from just before it.
    mutating func record(_ previous: EditState) {
        undoStack.append(previous)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
    }

    /// Returns the state to go back to, or nil if there's nothing to undo.
    mutating func undo(from current: EditState) -> EditState? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }

    mutating func redo(from current: EditState) -> EditState? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}
