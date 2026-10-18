/// What a gesture (or a key press) asks the editor to do. Gestures and keyboard share these.
enum EditCommand: Sendable, Equatable {
    case arm, disarm
    case beginAdjust, adjust(delta: Double), endAdjust, cancelAdjust
    case nextTool, previousTool
    case cursor(x: Double, y: Double), click
    case undo, redo, export
    case zoom(scale: Double)
}
